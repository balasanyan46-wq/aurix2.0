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
import { LeadScoringService, LeadBucket } from './lead-scoring.service';

/**
 * Endpoints для lead scoring (админка).
 *
 * GET  /admin/users/:id/score              — score конкретного пользователя (on-the-fly)
 * GET  /admin/leads-by-bucket?bucket=hot   — выборка из profiles.lead_bucket (legacy)
 * POST /admin/leads/recalculate            — массовый пересчёт (cron-friendly)
 *
 * NB: route `GET /admin/leads` принадлежит LeadsController (новая pipeline-таблица).
 * Старый score-bucket листинг переименован в /admin/leads-by-bucket для устранения
 * конфликта роутов. Оба endpoint'а корректно сосуществуют:
 *   - /admin/leads             — реальные leads из таблицы leads (status/assigned_to)
 *   - /admin/leads-by-bucket   — все profiles, отсортированные по score
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class LeadScoringController {
  constructor(private readonly service: LeadScoringService) {}

  @Get('admin/users/:id/score')
  async userScore(@Param('id') id: string) {
    const userId = Number(id);
    if (!Number.isFinite(userId) || userId <= 0) {
      throw new HttpException('Invalid user id', HttpStatus.BAD_REQUEST);
    }
    // Считаем on-the-fly — не из profiles. Всегда свежий результат.
    return this.service.computeScore(userId);
  }

  /**
   * Legacy листинг по `profiles.lead_bucket`. До этапа Sales CRM был
   * единственным источником "hot leads". Сейчас Action Center и Leads tab
   * используют /admin/leads (новый endpoint из LeadsController).
   *
   * Оставлен для обратной совместимости (если где-то старый код всё ещё ходит)
   * и быстрых сводок без сравнения с pipeline статусом.
   */
  @Get('admin/leads-by-bucket')
  async listLeadsByBucket(
    @Query('bucket') bucket?: string,
    @Query('limit') limit?: string,
  ) {
    const allowed: LeadBucket[] = ['cold', 'warm', 'hot'];
    const b = allowed.includes(bucket as LeadBucket) ? (bucket as LeadBucket) : 'hot';
    const lim = Math.min(Math.max(parseInt(limit || '50', 10) || 50, 1), 500);
    const items = await this.service.listByBucket(b, lim);
    return { bucket: b, count: items.length, items };
  }

  @Post('admin/leads/recalculate')
  async recalculate(@Req() req: any) {
    // Не требует confirmed/reason — это идемпотентная операция, ничего не
    // меняет в смысле "опасности". Но лог всё-таки полезен.
    const result = await this.service.recalculateAll(`manual_by:${req.user.id}`);
    return { ok: true, ...result };
  }
}
