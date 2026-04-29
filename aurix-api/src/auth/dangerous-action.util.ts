import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Контракт body для опасных admin-действий. Применяется к: block, unblock,
 * refund, kill-sessions, role-change, ai-actions/apply, mass-notify,
 * reset-limits.
 */
export interface DangerousActionBody {
  confirmed?: boolean;
  reason?: string;
  // Любые другие поля (action payload, target и т.д.) пропускаются как есть.
  [key: string]: any;
}

/**
 * Минимальная длина reason для опасного действия. 5 символов — компромисс:
 * заставляет хотя бы кратко описать причину, но не блокирует "OK".
 */
export const MIN_REASON_LENGTH = 5;

/**
 * Жёсткая валидация для опасных действий: confirmed === true и reason >=
 * MIN_REASON_LENGTH символов. Бросает 400, если контракт нарушен.
 *
 * Возвращает trim'нутый reason для сохранения в admin_logs.
 *
 * Дизайн-решение: валидация делается одной утилитой, а не class-validator
 * DTO, чтобы не ломать существующие endpoint'ы и оставить контроль внутри
 * каждого метода контроллера (см. блок-комментарий в admin-logs.controller).
 */
export function requireConfirmation(body: DangerousActionBody | undefined): string {
  if (!body || body.confirmed !== true) {
    throw new HttpException(
      {
        ok: false,
        error: 'confirmation_required',
        message:
          'Опасное действие требует явного подтверждения. ' +
          'Передайте confirmed: true и reason (минимум 5 символов).',
      },
      HttpStatus.BAD_REQUEST,
    );
  }
  const reason = (body.reason ?? '').trim();
  if (reason.length < MIN_REASON_LENGTH) {
    throw new HttpException(
      {
        ok: false,
        error: 'reason_required',
        message: `Поле reason обязательно (минимум ${MIN_REASON_LENGTH} символов).`,
      },
      HttpStatus.BAD_REQUEST,
    );
  }
  return reason;
}
