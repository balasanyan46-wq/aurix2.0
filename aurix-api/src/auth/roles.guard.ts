import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Inject,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { ROLES_KEY, hasAnyRole } from './roles.decorator';

/**
 * Старый AdminGuard. Сохранён для обратной совместимости — все
 * существующие endpoint'ы под @UseGuards(AdminGuard) продолжают работать.
 *
 * Допускает: admin, super_admin. (Раньше — только admin.)
 * Никогда не доверяет JWT-клейму, всегда читает роль из БД.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;

    if (!userId) {
      throw new ForbiddenException('authentication required');
    }

    const { rows } = await this.pool.query(
      `SELECT role FROM users WHERE id = $1`,
      [userId],
    );

    const role = rows[0]?.role;
    if (!role || !['admin', 'super_admin'].includes(role)) {
      throw new ForbiddenException('admin access required');
    }

    // Прокидываем роль в request для дальнейшего использования
    // (например, ограничение role-change только super_admin'ом).
    request.user.role = role;
    return true;
  }
}

/**
 * Тонкий guard на основе @Roles(...) метаданных. super_admin неявно
 * имеет доступ ко всему. Если @Roles не указан — пропускает (равно как
 * базовая аутентификация).
 *
 * Использование:
 *   @UseGuards(JwtAuthGuard, RolesGuard)
 *   @Roles('admin', 'finance_admin')
 */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!required || required.length === 0) return true;

    const request = context.switchToHttp().getRequest();
    const userId = request.user?.id;
    if (!userId) throw new ForbiddenException('authentication required');

    const { rows } = await this.pool.query(
      `SELECT role FROM users WHERE id = $1`,
      [userId],
    );
    const role = rows[0]?.role;
    if (!role) throw new ForbiddenException('role not found');

    if (!hasAnyRole(role, required)) {
      throw new ForbiddenException(
        `requires one of: ${required.join(', ')} (you are ${role})`,
      );
    }

    request.user.role = role;
    return true;
  }
}

/**
 * Утилита: проверить наличие конкретного permission у пользователя по
 * таблице role_permissions. super_admin всегда true.
 *
 * Используется внутри сервисов/контроллеров для тонких проверок
 * (например, finance-операция только если есть admin.payments.refund).
 */
export async function userHasPermission(
  pool: Pool,
  userId: number,
  permission: string,
): Promise<boolean> {
  const { rows } = await pool.query(
    `SELECT u.role
       FROM users u
      WHERE u.id = $1`,
    [userId],
  );
  const role = rows[0]?.role;
  if (!role) return false;
  if (role === 'super_admin') return true;

  const { rows: perm } = await pool.query(
    `SELECT 1 FROM role_permissions WHERE role = $1 AND permission = $2 LIMIT 1`,
    [role, permission],
  );
  return perm.length > 0;
}
