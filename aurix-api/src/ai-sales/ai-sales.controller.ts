import {
  Controller,
  Get,
  Post,
  Param,
  Query,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { AiSalesService } from './ai-sales.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class AiSalesController {
  constructor(private readonly service: AiSalesService) {}

  /**
   * GET /admin/ai-sales-signals
   *
   * Список пользователей с актуальным sales_signal = high.
   * Источник — кэш-таблица ai_sales_signals. Свежесть — refresh endpoint.
   */
  @Get('admin/ai-sales-signals')
  async list(@Query('limit') limit?: string) {
    const lim = Math.min(Math.max(Number(limit ?? 20) || 20, 1), 100);
    const items = await this.service.listHighSignalUsers(lim);
    return { count: items.length, items };
  }

  /**
   * POST /admin/ai-sales-signals/refresh
   *
   * Запускает массовый refresh для топ-N активных юзеров. Дорогая
   * операция (вызывает AI на каждого), поэтому вызывается вручную /
   * cron'ом, не на каждый GET.
   */
  @Post('admin/ai-sales-signals/refresh')
  async refresh(@Query('limit') limit?: string) {
    const lim = Math.min(Math.max(Number(limit ?? 50) || 50, 1), 200);
    const result = await this.service.refreshTopActive(lim);
    return { ok: true, ...result };
  }

  /**
   * POST /admin/users/:id/ai-sales-signal/refresh
   *
   * Анализ одного пользователя по запросу (например, при открытии его
   * карточки в админке).
   */
  @Post('admin/users/:id/ai-sales-signal/refresh')
  async refreshOne(@Param('id') id: string, @Req() _req: any) {
    const userId = Number(id);
    if (!Number.isFinite(userId) || userId <= 0) {
      throw new HttpException('Invalid user id', HttpStatus.BAD_REQUEST);
    }
    const result = await this.service.analyzeUser(userId);
    if (!result) {
      return { ok: false, message: 'No AI messages for this user' };
    }
    return { ok: true, signal: result };
  }
}
