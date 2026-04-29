import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Req,
  Body,
  Inject,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { requireConfirmation } from '../auth/dangerous-action.util';
import { LeadsService, LeadStatus, LeadBucket } from './leads.service';
import { LeadScoringService } from '../lead-scoring/lead-scoring.service';
import { NextActionService } from '../next-action/next-action.service';

// Sales pipeline — основные пользователи: support (контакт), admin, super_admin.
// analyst тоже может смотреть для аналитики (read-only через GET, write проверяется
// на per-endpoint уровне).
@UseGuards(JwtAuthGuard, AdminGuard)
@Roles('support', 'analyst', 'admin', 'finance_admin')
@Controller()
export class LeadsController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly service: LeadsService,
    private readonly scoring: LeadScoringService,
    private readonly nextAction: NextActionService,
  ) {}

  /**
   * Список «менеджеров» — для назначения leads.
   *
   * GET /admin/leads/staff
   *
   * Возвращает users с ролью одной из staff-ролей. Используется dropdown'ом
   * "Назначить менеджера" в Leads tab.
   */
  @Get('admin/leads/staff')
  async listStaff() {
    const { rows } = await this.pool.query(
      `
      SELECT u.id, u.email, u.name, u.role
        FROM users u
       WHERE u.role IN ('admin', 'super_admin', 'support', 'moderator', 'finance_admin', 'analyst')
       ORDER BY
         CASE u.role
           WHEN 'super_admin' THEN 0
           WHEN 'admin' THEN 1
           WHEN 'support' THEN 2
           ELSE 3
         END,
         u.name NULLS LAST,
         u.email
      `,
    ).catch(() => ({ rows: [] }));
    return { count: rows.length, items: rows };
  }

  /**
   * Lead Explainer — «Почему этот лид горячий?».
   *
   * GET /admin/leads/:id/explain
   *
   * Возвращает:
   *   - lead: запись из leads
   *   - score_breakdown: разбивка score из LeadScoringService.computeScore
   *   - recent_events: последние 20 событий пользователя
   *   - next_action: рекомендация next-action engine
   *   - ai_signal: последний AI sales signal (если есть)
   */
  @Get('admin/leads/:id/explain')
  async explain(@Param('id') id: string) {
    const lead = await this.service.getById(id);
    if (!lead) {
      throw new HttpException('Lead not found', HttpStatus.NOT_FOUND);
    }

    // Параллельно: scoring breakdown + последние события + next_action + ai_signal.
    const [scoring, events, nextAction, aiSignal, profile] = await Promise.all([
      this.scoring.computeScore(lead.user_id),
      this.pool.query(
        `SELECT event, target_type, target_id, meta, created_at
           FROM user_events WHERE user_id = $1
           ORDER BY created_at DESC LIMIT 20`,
        [lead.user_id],
      ).then(r => r.rows).catch(() => []),
      this.nextAction.getNextAction(lead.user_id).catch(() => null),
      this.pool.query(
        `SELECT * FROM ai_sales_signals
          WHERE user_id = $1
          ORDER BY created_at DESC LIMIT 1`,
        [lead.user_id],
      ).then(r => r.rows[0] ?? null).catch(() => null),
      this.pool.query(
        `SELECT u.id, u.email, p.display_name, p.plan, p.subscription_status
           FROM users u LEFT JOIN profiles p ON p.user_id = u.id
          WHERE u.id = $1`,
        [lead.user_id],
      ).then(r => r.rows[0] ?? null).catch(() => null),
    ]);

    return {
      ok: true,
      lead,
      profile,
      score_breakdown: scoring,
      recent_events: events,
      next_action: nextAction,
      ai_signal: aiSignal,
    };
  }

  /**
   * Sales leaderboard — рейтинг менеджеров по конверсиям и revenue
   * за период (default 7 дней).
   *
   * Возвращает: per-admin counts (new/in_progress/contacted_7d/converted_7d)
   * + revenue от их converted leads. Сортировка по revenue desc.
   */
  @Get('admin/sales/leaderboard')
  async leaderboard(@Query('days') days?: string) {
    const period = Math.min(Math.max(Number(days ?? 7) || 7, 1), 90);
    const { rows } = await this.pool.query(
      `
      WITH
        active AS (
          SELECT assigned_to AS admin_id, COUNT(*)::int AS active_count
            FROM leads
           WHERE assigned_to IS NOT NULL
             AND status NOT IN ('converted', 'lost')
           GROUP BY assigned_to
        ),
        contacted AS (
          SELECT al.admin_id, COUNT(DISTINCT al.target_id)::int AS contacted_count
            FROM admin_logs al
           WHERE al.admin_id IS NOT NULL
             AND al.action = 'lead_contacted'
             AND al.created_at >= now() - ($1 || ' days')::interval
           GROUP BY al.admin_id
        ),
        converted AS (
          SELECT l.assigned_to AS admin_id,
                 COUNT(*)::int AS converted_count,
                 COALESCE(SUM(p.amount), 0)::bigint AS revenue_kopecks
            FROM leads l
            LEFT JOIN payments p
              ON p.user_id = l.user_id
             AND p.status = 'confirmed'
             AND p.confirmed_at >= now() - ($1 || ' days')::interval
           WHERE l.assigned_to IS NOT NULL
             AND l.status = 'converted'
             AND l.updated_at >= now() - ($1 || ' days')::interval
           GROUP BY l.assigned_to
        ),
        lost AS (
          SELECT assigned_to AS admin_id, COUNT(*)::int AS lost_count
            FROM leads
           WHERE assigned_to IS NOT NULL
             AND status = 'lost'
             AND updated_at >= now() - ($1 || ' days')::interval
           GROUP BY assigned_to
        )
      SELECT
        u.id AS admin_id,
        u.email,
        u.name,
        u.role,
        COALESCE(a.active_count, 0)         AS active_count,
        COALESCE(c.contacted_count, 0)      AS contacted_count,
        COALESCE(co.converted_count, 0)     AS converted_count,
        COALESCE(l.lost_count, 0)           AS lost_count,
        COALESCE(co.revenue_kopecks, 0)::bigint AS revenue_kopecks
      FROM users u
      LEFT JOIN active    a  ON a.admin_id = u.id
      LEFT JOIN contacted c  ON c.admin_id = u.id
      LEFT JOIN converted co ON co.admin_id = u.id
      LEFT JOIN lost      l  ON l.admin_id = u.id
      WHERE u.role IN ('admin', 'super_admin', 'support', 'moderator', 'finance_admin')
        AND (
          COALESCE(a.active_count, 0) > 0 OR
          COALESCE(c.contacted_count, 0) > 0 OR
          COALESCE(co.converted_count, 0) > 0 OR
          COALESCE(l.lost_count, 0) > 0
        )
      ORDER BY revenue_kopecks DESC, converted_count DESC, contacted_count DESC
      `,
      [period],
    ).catch(() => ({ rows: [] }));

    return {
      ok: true,
      period_days: period,
      items: (rows as any[]).map((r: any) => ({
        admin_id: r.admin_id,
        email: r.email,
        name: r.name,
        role: r.role,
        active_count: r.active_count,
        contacted_count: r.contacted_count,
        converted_count: r.converted_count,
        lost_count: r.lost_count,
        revenue_rub: Math.round(Number(r.revenue_kopecks ?? 0) / 100),
      })),
      generated_at: new Date().toISOString(),
    };
  }

  /**
   * Manager Dashboard — «мои продажи сегодня».
   *
   * GET /admin/my-sales-dashboard
   *
   * Доступ: only active sales-roles (унаследован от классового @Roles).
   *
   * Возвращает:
   *   - my_new_leads, my_in_progress (текущие)
   *   - contacted_7d, converted_7d, lost_7d
   *   - estimated_possible_revenue (сумма possible_revenue по активным leads)
   *   - real_revenue_7d (фактическая выручка от converted leads за 7 дней)
   */
  @Get('admin/my-sales-dashboard')
  async mySalesDashboard(@Req() req: any) {
    const adminId = req.user.id;

    // 1) Все мои текущие leads (не converted, не lost).
    const { rows: activeRows } = await this.pool.query(
      `SELECT id, user_id, status, lead_score, lead_bucket, next_action, last_contact_at
         FROM leads
        WHERE assigned_to = $1 AND status NOT IN ('converted', 'lost')
        ORDER BY lead_score DESC`,
      [adminId],
    ).catch(() => ({ rows: [] }));

    const myNewLeads = activeRows.filter((r: any) => r.status === 'new');
    const myInProgress = activeRows.filter(
      (r: any) => r.status === 'contacted' || r.status === 'in_progress',
    );

    // 2) За 7 дней: contacted/converted/lost. Считаем по admin_logs
    // (lead_contacted) и по leads (для converted/lost — updated_at).
    const { rows: contactedRows } = await this.pool.query(
      `SELECT count(DISTINCT al.target_id)::int AS c
         FROM admin_logs al
        WHERE al.admin_id = $1
          AND al.action = 'lead_contacted'
          AND al.created_at >= now() - interval '7 days'`,
      [adminId],
    ).catch(() => ({ rows: [{ c: 0 }] }));

    const { rows: convertedRows } = await this.pool.query(
      `SELECT count(*)::int AS c
         FROM leads
        WHERE assigned_to = $1
          AND status = 'converted'
          AND updated_at >= now() - interval '7 days'`,
      [adminId],
    ).catch(() => ({ rows: [{ c: 0 }] }));

    const { rows: lostRows } = await this.pool.query(
      `SELECT count(*)::int AS c
         FROM leads
        WHERE assigned_to = $1
          AND status = 'lost'
          AND updated_at >= now() - interval '7 days'`,
      [adminId],
    ).catch(() => ({ rows: [{ c: 0 }] }));

    // 3) Estimated possible revenue: для каждого активного lead'а тянем
    // possible_revenue из next-action engine. N запросов — но N <= ~50, OK.
    let estimatedRevenue = 0;
    for (const lead of activeRows) {
      try {
        const next = await this.nextAction.getNextAction(lead.user_id);
        estimatedRevenue += next.possible_revenue ?? 0;
      } catch { /* skip */ }
    }

    // 4) Real revenue: суммируем confirmed payments за 7 дней по converted leads.
    const { rows: revenueRows } = await this.pool.query(
      `
      SELECT COALESCE(SUM(p.amount), 0)::bigint AS total_kopecks
        FROM payments p
        JOIN leads l ON l.user_id = p.user_id
       WHERE l.assigned_to = $1
         AND l.status = 'converted'
         AND p.status = 'confirmed'
         AND p.confirmed_at >= now() - interval '7 days'
      `,
      [adminId],
    ).catch(() => ({ rows: [{ total_kopecks: 0 }] }));

    return {
      ok: true,
      admin_id: adminId,
      my_new_leads: myNewLeads,
      my_in_progress: myInProgress,
      contacted_7d: contactedRows[0]?.c ?? 0,
      converted_7d: convertedRows[0]?.c ?? 0,
      lost_7d: lostRows[0]?.c ?? 0,
      estimated_possible_revenue: estimatedRevenue,
      real_revenue_7d_rub: Math.round(Number(revenueRows[0]?.total_kopecks ?? 0) / 100),
      generated_at: new Date().toISOString(),
    };
  }

  /**
   * Список leads с фильтрами.
   * Query: status, bucket, assigned_to, limit, offset
   */
  @Get('admin/leads')
  async list(
    @Query('status') status?: string,
    @Query('bucket') bucket?: string,
    @Query('assigned_to') assignedTo?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const validStatuses: LeadStatus[] = ['new', 'contacted', 'in_progress', 'converted', 'lost'];
    const validBuckets: LeadBucket[] = ['cold', 'warm', 'hot'];
    const items = await this.service.list({
      status: validStatuses.includes(status as LeadStatus) ? (status as LeadStatus) : undefined,
      bucket: validBuckets.includes(bucket as LeadBucket) ? (bucket as LeadBucket) : undefined,
      assigned_to: assignedTo ? Number(assignedTo) : undefined,
      limit: limit ? Number(limit) : 100,
      offset: offset ? Number(offset) : 0,
    });
    return { count: items.length, items };
  }

  /**
   * Patch lead. Меняет status / assigned_to / next_action.
   *
   * SAFETY: смена статуса на 'converted' / 'lost' требует confirmed + reason
   * (это финальные состояния — ошибки трудно откатить). Простые правки
   * next_action и assigned_to не требуют confirm.
   */
  @Patch('admin/leads/:id')
  async patch(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: {
      status?: string;
      assigned_to?: number | null;
      next_action?: string | null;
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    const validStatuses: LeadStatus[] = ['new', 'contacted', 'in_progress', 'converted', 'lost'];
    if (body.status && !validStatuses.includes(body.status as LeadStatus)) {
      throw new HttpException('Invalid status', HttpStatus.BAD_REQUEST);
    }

    let reason = body.reason ?? 'patch';
    // Финальные состояния требуют явного reason.
    if (body.status === 'converted' || body.status === 'lost') {
      reason = requireConfirmation({ confirmed: body.confirmed, reason: body.reason });
    }

    const updated = await this.service.patch(
      id,
      {
        status: body.status as LeadStatus | undefined,
        assigned_to: body.assigned_to,
        next_action: body.next_action,
      },
      req.user.id,
      reason,
    );
    if (!updated) {
      throw new HttpException('Lead not found', HttpStatus.NOT_FOUND);
    }
    return { ok: true, lead: updated };
  }

  /**
   * Отметить lead как «связались». Не destructive, но требуем краткое
   * описание контакта (что пообещали, какое время связи) — это ценная
   * информация для следующего менеджера.
   */
  @Post('admin/leads/:id/contacted')
  async contacted(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { reason?: string },
  ) {
    const reason = (body?.reason ?? '').trim();
    if (reason.length < 5) {
      throw new HttpException(
        { ok: false, error: 'reason_required', message: 'Опишите контакт (минимум 5 символов)' },
        HttpStatus.BAD_REQUEST,
      );
    }
    const updated = await this.service.markContacted(id, req.user.id, reason);
    if (!updated) {
      throw new HttpException('Lead not found', HttpStatus.NOT_FOUND);
    }
    return { ok: true, lead: updated };
  }
}
