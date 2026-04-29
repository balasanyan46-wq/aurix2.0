import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { MessageTemplatesService } from './message-templates.service';

/**
 * Admin endpoints для шаблонов sales-сообщений + A/B-статистика.
 *
 * GET /admin/message-templates       — список всех шаблонов
 * GET /admin/message-templates/stats — A/B статистика по (code, variant_key)
 *
 * CRUD (create/update/delete) пока не реализован — для MVP достаточно
 * INSERT через SQL миграцию или DBeaver. Когда понадобится UI — добавим
 * POST/PATCH/DELETE с confirmed+reason.
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class MessageTemplatesController {
  constructor(private readonly service: MessageTemplatesService) {}

  @Get('admin/message-templates')
  async list() {
    const items = await this.service.listAll();
    return { count: items.length, items };
  }

  @Get('admin/message-templates/stats')
  async stats() {
    const items = await this.service.getStats();
    return { count: items.length, items };
  }
}
