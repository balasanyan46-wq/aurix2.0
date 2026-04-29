import { SetMetadata } from '@nestjs/common';

/**
 * Ключ метаданных для @Roles(...). Читается RolesGuard.
 */
export const ROLES_KEY = 'roles';

/**
 * Декоратор для ограничения доступа к endpoint'у списком ролей.
 *
 * Использование:
 *   @UseGuards(JwtAuthGuard, RolesGuard)
 *   @Roles('admin', 'super_admin')
 *
 * super_admin неявно имеет доступ ко всему, его можно не указывать.
 * RolesGuard проверяет роль из БД (не доверяет JWT-клейму).
 */
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);

/**
 * Список всех валидных ролей в системе. Хранится тут, чтобы DTO
 * валидаторы могли его переиспользовать.
 */
export const ALL_ROLES = [
  'user',
  'artist',
  'support',
  'moderator',
  'analyst',
  'finance_admin',
  'admin',
  'super_admin',
] as const;

export type Role = typeof ALL_ROLES[number];

/**
 * Иерархия: super_admin > admin > все остальные на одном уровне.
 * Возвращает true, если у actor достаточно прав, чтобы выполнить
 * действие, требующее минимум одну из needed ролей.
 */
export function hasAnyRole(actorRole: string, needed: readonly string[]): boolean {
  if (actorRole === 'super_admin') return true;
  return needed.includes(actorRole);
}
