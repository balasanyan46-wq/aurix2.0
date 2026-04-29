import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  HttpStatus,
  Inject,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from './jwt-auth.guard';
import { AdminGuard } from './roles.guard';
import { Roles } from './roles.decorator';
import { requireConfirmation } from './dangerous-action.util';

/**
 * Permissions matrix endpoints — read-only для всех админов,
 * write только для super_admin.
 *
 * GET    /admin/permissions/matrix  — таблица role × permission
 * GET    /admin/permissions/roles   — список доступных ролей
 * POST   /admin/permissions/grant   — выдать permission роли (super_admin only)
 * DELETE /admin/permissions/revoke  — отозвать (super_admin only)
 */
@UseGuards(JwtAuthGuard, AdminGuard)
@Controller()
export class PermissionsController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Read-only matrix. Доступно всем admin-ролям — это аудит-инструмент,
   * не дающий поднять привилегии.
   */
  @Get('admin/permissions/matrix')
  @Roles('admin', 'super_admin', 'support', 'moderator', 'analyst', 'finance_admin')
  async matrix() {
    const { rows } = await this.pool.query(`
      SELECT role, permission, description
        FROM role_permissions
        ORDER BY role, permission
    `).catch(() => ({ rows: [] }));

    // Группируем по ролям для удобства UI.
    const byRole: Record<string, Array<{ permission: string; description: string | null }>> = {};
    for (const r of rows as any[]) {
      (byRole[r.role] = byRole[r.role] ?? []).push({
        permission: r.permission,
        description: r.description ?? null,
      });
    }

    return {
      ok: true,
      // Все роли (даже пустые в seed'е), чтобы UI знал что они существуют.
      roles: ['user', 'artist', 'support', 'moderator', 'analyst', 'finance_admin', 'admin', 'super_admin'],
      by_role: byRole,
      raw: rows,
      note: 'super_admin неявно имеет все permissions — в matrix не показывается, см. RolesGuard.hasAnyRole.',
    };
  }

  /**
   * Выдать permission роли. Только super_admin.
   * Идемпотентно: повторный grant того же (role, permission) — no-op.
   */
  @Post('admin/permissions/grant')
  @Roles('super_admin')
  async grant(
    @Req() req: any,
    @Body() body: {
      role: string;
      permission: string;
      description?: string;
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    const reason = requireConfirmation(body);
    if (!body.role || !body.permission) {
      throw new HttpException('role and permission required', HttpStatus.BAD_REQUEST);
    }
    await this.pool.query(
      `INSERT INTO role_permissions (role, permission, description)
       VALUES ($1, $2, $3)
       ON CONFLICT (role, permission) DO UPDATE SET description = EXCLUDED.description`,
      [body.role, body.permission, body.description ?? null],
    );
    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'permission_granted', 'role', $2, $3)`,
      [req.user.id, body.role, JSON.stringify({ permission: body.permission, reason })],
    ).catch(() => {});
    return { ok: true };
  }

  @Delete('admin/permissions/revoke')
  @Roles('super_admin')
  async revoke(
    @Req() req: any,
    @Body() body: {
      role: string;
      permission: string;
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    const reason = requireConfirmation(body);
    if (!body.role || !body.permission) {
      throw new HttpException('role and permission required', HttpStatus.BAD_REQUEST);
    }
    const { rowCount } = await this.pool.query(
      `DELETE FROM role_permissions WHERE role = $1 AND permission = $2`,
      [body.role, body.permission],
    );
    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'permission_revoked', 'role', $2, $3)`,
      [req.user.id, body.role, JSON.stringify({ permission: body.permission, reason })],
    ).catch(() => {});
    return { ok: true, removed: rowCount ?? 0 };
  }
}
