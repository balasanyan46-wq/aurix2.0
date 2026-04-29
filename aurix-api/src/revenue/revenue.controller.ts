import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { RevenueService } from './revenue.service';

/**
 * Revenue Dashboard — финансовые метрики для админки.
 *
 * GET /admin/revenue — все метрики одним запросом (~10 параллельных
 * SQL-запросов внутри). Не дешёвый, но и не вызывается часто (раз в
 * минуту/30 секунд через UI refresh).
 *
 * Доступ: finance_admin (профильная роль), admin, analyst (read-only).
 * super_admin — неявно.
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Roles('finance_admin', 'admin', 'analyst')
@Controller()
export class RevenueController {
  constructor(private readonly service: RevenueService) {}

  @Get('admin/revenue')
  async revenue() {
    return this.service.getMetrics();
  }
}
