import { Controller, Get, Post, Body, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { UserEventsService } from './user-events.service';

/**
 * Whitelist событий, которые разрешено логировать с клиента (Flutter).
 *
 * Backend-only события (payment_success, subscription_changed, release_*) —
 * клиент НЕ должен писать, иначе можно подделать lead_score. Их пишет только
 * соответствующий backend-сервис.
 *
 * Если клиент отправит событие не из этого списка — 400 (но НЕ молча игнорим,
 * чтобы было видно в логах попытки).
 */
const CLIENT_ALLOWED_EVENTS = new Set<string>([
  'paywall_viewed',     // открыл страницу с тарифами
  'plan_clicked',       // кликнул по конкретному плану
  'checkout_started',   // нажал "Оплатить"
  'offer_clicked',      // открыл присланный оффер (из push/email)
  'page_view',          // generic page tracking (для аналитики)
  // ai_chat пишется backend'ом из studio-tools — клиент НЕ может
  // track_uploaded пишется backend'ом из upload — клиент НЕ может
]);

@UseGuards(JwtAuthGuard)
@Controller()
export class UserEventsController {
  constructor(private readonly svc: UserEventsService) {}

  /** User logs their own event (e.g. from Flutter client). */
  @Post('user-events')
  async logEvent(@Req() req: any, @Body() body: Record<string, any>) {
    const event = String(body.event ?? '').trim();
    if (!event) {
      throw new HttpException('event required', HttpStatus.BAD_REQUEST);
    }
    if (!CLIENT_ALLOWED_EVENTS.has(event)) {
      // Защита от подделки: backend-only события клиент не может писать.
      // 400 — чтобы клиент мог показать ошибку, и в логах было видно
      // попытку (через access logs).
      throw new HttpException(
        `event '${event}' is not allowed from client`,
        HttpStatus.BAD_REQUEST,
      );
    }
    return this.svc.log({
      user_id: req.user.id,
      event,
      target_type: body.target_type,
      target_id: body.target_id != null ? String(body.target_id) : undefined,
      meta: body.meta,
      ip: req.ip,
      user_agent: req.headers?.['user-agent'],
    });
  }

  /** Admin: search/filter events. */
  @UseGuards(AdminGuard)
  @Get('admin/user-events')
  async search(
    @Query('user_id') userId?: string,
    @Query('event') event?: string,
    @Query('target_type') targetType?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.svc.search({
      userId: userId ? +userId : undefined,
      event,
      targetType,
      from,
      to,
      limit: limit ? +limit : 50,
      offset: offset ? +offset : 0,
    });
  }

  /** Admin: event count with filters. */
  @UseGuards(AdminGuard)
  @Get('admin/user-events/count')
  async count(
    @Query('user_id') userId?: string,
    @Query('event') event?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
  ) {
    const count = await this.svc.count({
      userId: userId ? +userId : undefined,
      event,
      from,
      to,
    });
    return { count };
  }

  /** Admin: timeline for a specific user. */
  @UseGuards(AdminGuard)
  @Get('admin/user-events/timeline')
  async timeline(
    @Query('user_id') userId: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    return this.svc.forUser(+userId, limit ? +limit : 50, offset ? +offset : 0);
  }

  /** Admin: DAU stats. */
  @UseGuards(AdminGuard)
  @Get('admin/stats/dau')
  async dau(@Query('days') days?: string) {
    return this.svc.dau(days ? +days : 30);
  }

  /** Admin: MAU stats. */
  @UseGuards(AdminGuard)
  @Get('admin/stats/mau')
  async mau(@Query('months') months?: string) {
    return this.svc.mau(months ? +months : 12);
  }

  /** Admin: event breakdown. */
  @UseGuards(AdminGuard)
  @Get('admin/stats/events-breakdown')
  async eventBreakdown(@Query('days') days?: string) {
    return this.svc.eventBreakdown(days ? +days : 30);
  }

  /** Admin: distinct event types. */
  @UseGuards(AdminGuard)
  @Get('admin/stats/event-types')
  async eventTypes() {
    return this.svc.eventTypes();
  }
}
