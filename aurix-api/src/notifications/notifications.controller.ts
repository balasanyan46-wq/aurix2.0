import { Controller, Get, Post, Body, Query, Param, Req, UseGuards, HttpException, HttpStatus, Inject, Optional } from '@nestjs/common';
import { Pool } from 'pg';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { requireConfirmation } from '../auth/dangerous-action.util';
import { NotificationsService } from './notifications.service';
import { MailService } from '../mail/mail.service';
import { PushService } from '../push/push.service';
import { PG_POOL } from '../database/database.module';

@UseGuards(JwtAuthGuard)
@Controller()
export class NotificationsController {
  constructor(
    private readonly svc: NotificationsService,
    private readonly mail: MailService,
    @Inject(PG_POOL) private readonly pool: Pool,
    // PushService опционален — пока работает в stub-режиме, без него
    // notifications endpoint не падает.
    @Optional() private readonly push?: PushService,
  ) {}

  // ── User endpoints ─────────────────────────────────────

  /** Get my notifications. */
  @Get('notifications/my')
  async getMyNotifications(@Req() req: any, @Query('unread') unread?: string) {
    return this.svc.forUser(req.user.id, 50, unread === 'true');
  }

  /** Unread count. */
  @Get('notifications/unread-count')
  async unreadCount(@Req() req: any) {
    const count = await this.svc.unreadCount(req.user.id);
    return { count };
  }

  /** Mark as read (single or all). */
  @Post('notifications/mark-read')
  async markRead(@Req() req: any, @Body() body: { id?: number }) {
    await this.svc.markRead(req.user.id, body.id);
    return { success: true };
  }

  // ── Admin endpoints ────────────────────────────────────

  /**
   * Admin: универсальный endpoint для sales-уведомлений.
   *
   * POST /admin/notifications
   * body:
   *   user_id, type ('push' | 'email' | 'internal'), title, message,
   *   source ('action_center' | 'leads_pipeline' | 'manual' | ...),
   *   confirmed (true), reason (>= 5),
   *   meta (опционально — например, product_offer для оффера)
   *
   * Логика:
   *   1) валидация confirmed + reason (массовая рассылка возможна)
   *   2) запись в notifications (in-app)
   *   3) если type='email' — попытка реальной отправки через MailService
   *   4) запись в user_events: 'offer_sent' если source/meta содержит offer,
   *      иначе 'notification_sent'
   *   5) запись в admin_logs
   *
   * mock-send: если SMTP не настроен — возвращаем success=true, но
   * email не отправляется (только в логах помечается).
   */
  @UseGuards(AdminGuard)
  @Post('admin/notifications')
  async adminCreateNotification(
    @Req() req: any,
    @Body()
    body: {
      user_id: number;
      type?: 'push' | 'email' | 'internal';
      title: string;
      message: string;
      source?: string;
      meta?: Record<string, any>;
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    // SAFETY: универсальное уведомление — потенциально опасно (можно
    // отправить что угодно). Требуем confirmed + reason.
    const reason = requireConfirmation({
      confirmed: body.confirmed,
      reason: body.reason,
    });

    if (!body.user_id || !body.title || !body.message) {
      throw new HttpException('user_id, title, message required', HttpStatus.BAD_REQUEST);
    }
    const validTypes = ['push', 'email', 'internal'];
    const transport = body.type ?? 'internal';
    if (!validTypes.includes(transport)) {
      throw new HttpException('type must be push|email|internal', HttpStatus.BAD_REQUEST);
    }

    // SAFETY: Маппим transport (push|email|internal) на DB-валидный type
    // для notifications.type CHECK constraint. Sales-flow (наличие
    // product_offer / source) → 'offer' или 'sales'. Иначе — 'internal'.
    const isOffer = !!(body.meta?.product_offer) ||
                    body.source === 'offer' ||
                    body.source === 'action_center_offer';
    const isSales = body.source === 'action_center' || body.source === 'leads_pipeline' || body.source === 'sales';
    const dbType = isOffer ? 'offer' : (isSales ? 'sales' : 'internal');

    // 1) In-app notification — пишется всегда (для истории).
    const notif = await this.svc.send({
      user_id: body.user_id,
      title: body.title,
      message: body.message,
      type: dbType,
      meta: { transport, source: body.source ?? null, ...(body.meta ?? {}) },
    });

    // 2) Email send — best-effort. Только если transport='email'.
    // Если SMTP не настроен, тихо помечаем как attempted=true,ok=false.
    let emailResult: { attempted: boolean; ok: boolean; error?: string } = {
      attempted: false,
      ok: false,
    };
    if (transport === 'email') {
      try {
        const { rows } = await this.pool.query(
          'SELECT email FROM users WHERE id = $1 LIMIT 1',
          [body.user_id],
        );
        const to = rows[0]?.email;
        if (to) {
          emailResult.attempted = true;
          const r = await this.mail.sendAdminMessage(to, body.title, body.message);
          emailResult.ok = r.success;
          if (!r.success) emailResult.error = r.error;
        }
      } catch (e: any) {
        emailResult = { attempted: true, ok: false, error: e?.message ?? String(e) };
      }
    }

    // Push transport — пытаемся отправить через PushService (stub до интеграции
    // с FCM). Если миграция 098_push_tokens не накатана или у юзера нет
    // зарегистрированных токенов — sent=0, и это норма.
    let pushResult: { attempted: boolean; sent: number; failed: number } = {
      attempted: false, sent: 0, failed: 0,
    };
    if (transport === 'push' && this.push) {
      try {
        const r = await this.push.sendToUser(body.user_id, body.title, body.message);
        pushResult = { attempted: true, sent: r.sent, failed: r.failed };
      } catch (e: any) {
        pushResult = { attempted: true, sent: 0, failed: 0 };
      }
    }

    // 3) user_events: offer_sent если есть product_offer / source = offer;
    // иначе notification_sent.
    const eventName = isOffer ? 'offer_sent' : 'notification_sent';
    await this.pool.query(
      `INSERT INTO user_events (user_id, event, target_type, target_id, meta)
       VALUES ($1, $2, 'notification', $3, $4)`,
      [
        body.user_id,
        eventName,
        String(notif.id ?? ''),
        JSON.stringify({
          transport,
          db_type: dbType,
          title: body.title,
          source: body.source ?? null,
          product_offer: body.meta?.product_offer ?? null,
          plan: body.meta?.plan ?? null,
          amount: body.meta?.amount ?? null,
          // A/B template attribution: если фронт прислал template_code +
          // template_variant (из next-action engine), пишем в offer_sent.meta.
          // Используется MessageTemplatesService.getStats для conversion %.
          template_code: body.meta?.template_code ?? null,
          template_variant: body.meta?.template_variant ?? null,
        }),
      ],
    ).catch(() => {});

    // 4) admin_logs — для аудита, кто и зачем отправил.
    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, $2, 'user', $3, $4)`,
      [
        req.user.id,
        isOffer ? 'offer_sent' : 'notification_sent',
        String(body.user_id),
        JSON.stringify({
          reason,
          transport,
          db_type: dbType,
          title: body.title,
          source: body.source ?? null,
          meta: body.meta ?? null,
          email_attempted: emailResult.attempted,
          email_ok: emailResult.ok,
        }),
      ],
    ).catch(() => {});

    return {
      success: true,
      notification: notif,
      email: emailResult,
      push: pushResult,
      event_logged: eventName,
    };
  }

  /**
   * Admin: send notification to a user.
   *
   * - Always writes an in-app notification row.
   * - If `send_email !== false` (default true) AND we can resolve the user's
   *   email, also fires an admin-authored email via MailService. Email send
   *   failures are logged but never fail the request — the in-app record
   *   still persists so the admin gets a consistent "sent" response.
   */
  @UseGuards(AdminGuard)
  @Post('admin/notifications/send')
  async adminSend(
    @Body()
    body: {
      user_id: number;
      title: string;
      message: string;
      type?: string;
      send_email?: boolean;
    },
  ) {
    if (!body.user_id || !body.title || !body.message) {
      throw new HttpException('user_id, title, message required', HttpStatus.BAD_REQUEST);
    }

    const row = await this.svc.send(body);

    let emailResult: { attempted: boolean; ok: boolean; to?: string; error?: string } = {
      attempted: false,
      ok: false,
    };
    if (body.send_email !== false) {
      try {
        const { rows } = await this.pool.query(
          'SELECT email FROM users WHERE id = $1 LIMIT 1',
          [body.user_id],
        );
        const to = rows[0]?.email;
        if (to) {
          emailResult.attempted = true;
          emailResult.to = to;
          const res = await this.mail.sendAdminMessage(to, body.title, body.message);
          emailResult.ok = res.success;
          if (!res.success) emailResult.error = res.error;
        }
      } catch (e: any) {
        emailResult = { attempted: true, ok: false, error: e?.message ?? String(e) };
      }
    }

    return { ...row, email: emailResult };
  }

  /** Admin: broadcast to multiple users. */
  @UseGuards(AdminGuard)
  @Post('admin/notifications/broadcast')
  async adminBroadcast(@Body() body: { user_ids: number[]; title: string; message: string; type?: string }) {
    if (!body.user_ids?.length || !body.title || !body.message) {
      throw new HttpException('user_ids, title, message required', HttpStatus.BAD_REQUEST);
    }
    const count = await this.svc.sendBulk(body.user_ids, body.title, body.message, body.type);
    return { success: true, sent: count };
  }

  /** Admin: list all notifications. */
  @UseGuards(AdminGuard)
  @Get('admin/notifications')
  async adminList(
    @Query('user_id') userId?: string,
    @Query('type') type?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.svc.listAll({
      userId: userId ? +userId : undefined,
      type,
      limit: limit ? +limit : 50,
      offset: offset ? +offset : 0,
    });
  }
}
