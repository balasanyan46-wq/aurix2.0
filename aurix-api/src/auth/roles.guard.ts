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
 * AdminGuard — гибридный guard.
 *
 * Поведение:
 *   1) Если на endpoint'е есть `@Roles(role1, role2, ...)` → пропускает,
 *      когда роль юзера в этом списке (или super_admin).
 *   2) Если `@Roles` НЕ задан → fallback на admin/super_admin
 *      (оригинальное поведение, бэквард-совместимо).
 *
 * Никогда не доверяет JWT — всегда читает роль из БД.
 *
 * Это позволяет постепенно переключать endpoints на тонкие роли (support,
 * moderator, finance_admin, analyst) без массового переписывания: добавил
 * `@Roles('moderator', 'admin')` сверху endpoint'а — и всё.
 */
@Injectable()
export class AdminGuard implements CanActivate {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly reflector: Reflector,
  ) {}

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
    if (!role) {
      throw new ForbiddenException('role not found');
    }

    // Прокидываем роль в request — нужно для проверок типа «только super_admin
    // может менять роли» внутри контроллера.
    request.user.role = role;

    // Если на endpoint указан @Roles — используем его список.
    const required = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (required && required.length > 0) {
      if (!hasAnyRole(role, required)) {
        throw new ForbiddenException(
          `requires one of: ${required.join(', ')} (you are ${role})`,
        );
      }
      return true;
    }

    // Fallback: дефолтное admin-only поведение для старых endpoints.
    if (!['admin', 'super_admin'].includes(role)) {
      throw new ForbiddenException('admin access required');
    }
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
