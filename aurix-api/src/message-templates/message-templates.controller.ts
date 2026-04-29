import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  HttpStatus,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { requireConfirmation } from '../auth/dangerous-action.util';
import { MessageTemplatesService } from './message-templates.service';

/**
 * Admin endpoints для шаблонов sales-сообщений + A/B-статистика + CRUD.
 *
 * GET    /admin/message-templates          — список всех шаблонов
 * GET    /admin/message-templates/stats    — A/B статистика
 * POST   /admin/message-templates          — создать вариант (upsert)
 * PATCH  /admin/message-templates/:id      — изменить (active/weight/message)
 * DELETE /admin/message-templates/:id      — удалить (защита: нельзя удалить
 *                                            последний активный вариант)
 *
 * Все мутации требуют confirmed=true + reason >=5 символов
 * (защита от случайной правки прод-текстов).
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Roles('admin', 'super_admin')
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

  /**
   * Multi-channel conversion: какой transport (push/email/internal) лучше.
   * Полезно для решения «куда кидать оффер если есть выбор».
   */
  @Get('admin/message-templates/channels')
  async channels() {
    const items = await this.service.getStatsByChannel();
    return { count: items.length, items };
  }

  /**
   * Upsert — создать новый вариант или обновить существующий по (code, variant_key).
   *
   * SAFETY: confirmed + reason обязательны.
   */
  @Post('admin/message-templates')
  async upsert(
    @Req() req: any,
    @Body()
    body: {
      code: string;
      variant_key: string;
      message: string;
      weight?: number;
      active?: boolean;
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    requireConfirmation(body);
    if (!body.code || !body.variant_key || !body.message) {
      throw new HttpException(
        'code, variant_key, message required',
        HttpStatus.BAD_REQUEST,
      );
    }
    if (body.message.length > 2000) {
      throw new HttpException('message too long (max 2000)', HttpStatus.BAD_REQUEST);
    }
    if (body.weight !== undefined && (body.weight < 0 || body.weight > 100)) {
      throw new HttpException('weight must be 0..100', HttpStatus.BAD_REQUEST);
    }
    const row = await this.service.upsert({
      code: body.code.trim(),
      variant_key: body.variant_key.trim().toUpperCase(),
      message: body.message,
      weight: body.weight,
      active: body.active,
      created_by: req.user.id,
    });
    return { ok: true, template: row };
  }

  /**
   * Patch — частичное обновление. На текущий момент поддерживает active toggle.
   * Изменение message — через POST upsert (тот же endpoint).
   */
  @Patch('admin/message-templates/:id')
  async patch(
    @Param('id') id: string,
    @Body() body: { active?: boolean; confirmed?: boolean; reason?: string },
  ) {
    requireConfirmation(body);
    const numId = Number(id);
    if (!Number.isFinite(numId) || numId <= 0) {
      throw new HttpException('Invalid id', HttpStatus.BAD_REQUEST);
    }
    if (body.active === undefined) {
      throw new HttpException('only "active" toggle supported', HttpStatus.BAD_REQUEST);
    }
    const row = await this.service.setActive(numId, body.active);
    if (!row) {
      throw new HttpException('Template not found', HttpStatus.NOT_FOUND);
    }
    return { ok: true, template: row };
  }

  @Delete('admin/message-templates/:id')
  async delete(
    @Param('id') id: string,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    requireConfirmation(body);
    const numId = Number(id);
    if (!Number.isFinite(numId) || numId <= 0) {
      throw new HttpException('Invalid id', HttpStatus.BAD_REQUEST);
    }
    const deleted = await this.service.deleteVariant(numId);
    if (!deleted) {
      throw new HttpException(
        { ok: false, error: 'cannot_delete_last_variant', message: 'Это последний активный вариант — удалять нельзя. Создайте альтернативный вариант сначала.' },
        HttpStatus.CONFLICT,
      );
    }
    return { ok: true, deleted };
  }
}
