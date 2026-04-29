import { Controller, Get, Param, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { NextActionService } from './next-action.service';

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class NextActionController {
  constructor(private readonly service: NextActionService) {}

  /**
   * GET /admin/users/:id/next-action
   * Возвращает текущее рекомендуемое действие для пользователя.
   * Также синхронизирует значение в leads.next_action (best-effort).
   */
  @Get('admin/users/:id/next-action')
  async forUser(@Param('id') id: string) {
    const userId = Number(id);
    if (!Number.isFinite(userId) || userId <= 0) {
      throw new HttpException('Invalid user id', HttpStatus.BAD_REQUEST);
    }
    const result = await this.service.getNextAction(userId);
    // Best-effort sync — не блокируем ответ.
    this.service.refreshAndPersist(userId).catch(() => {});
    return result;
  }
}
