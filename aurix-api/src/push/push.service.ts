import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

/**
 * PushService — отправка push-нотификаций (FCM / APNS).
 *
 * Сейчас работает в **stub-режиме**: `send` возвращает success, но реально
 * push не уходит. Этого достаточно чтобы код NotificationsController с
 * `transport='push'` не падал, а проходил в БД как in-app notification.
 *
 * Чтобы включить реальный FCM — нужны:
 *   1) Firebase project + Service Account JSON
 *   2) `npm i firebase-admin`
 *   3) Заменить `_stubSendFcm` на реальный вызов `admin.messaging().send(...)`
 *   4) В .env: `FCM_PROJECT_ID`, `FCM_PRIVATE_KEY`, `FCM_CLIENT_EMAIL`
 *
 * См. блок NOT IMPLEMENTED ниже.
 */
@Injectable()
export class PushService {
  private readonly log = new Logger(PushService.name);

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Регистрация push-токена (вызывается с клиента после получения через FCM SDK).
   * Если токен уже есть — обновляем last_used_at + active=true.
   */
  async registerToken(
    userId: number,
    platform: 'fcm' | 'apns' | 'web',
    token: string,
    deviceInfo?: Record<string, any>,
  ): Promise<void> {
    await this.pool.query(
      `INSERT INTO push_tokens (user_id, platform, token, device_info, last_used_at)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (token)
       DO UPDATE SET active = true, last_used_at = now(),
                     device_info = COALESCE(EXCLUDED.device_info, push_tokens.device_info)`,
      [userId, platform, token, JSON.stringify(deviceInfo ?? {})],
    ).catch(e => this.log.warn(`registerToken failed for user ${userId}: ${e.message}`));
  }

  /**
   * Отписаться от push (logout / settings).
   */
  async unregisterToken(token: string): Promise<void> {
    await this.pool.query(
      `UPDATE push_tokens SET active = false WHERE token = $1`,
      [token],
    ).catch(() => {});
  }

  /**
   * Отправить push на все активные токены пользователя.
   * Возвращает количество успешно отправленных.
   *
   * STUB: до интеграции с FCM/APNS возвращает 0 для каждого токена,
   * но успешно идёт по флоу (не падает). Используется для smoke-test
   * и дев-окружения.
   */
  async sendToUser(
    userId: number,
    title: string,
    message: string,
    data?: Record<string, string>,
  ): Promise<{ sent: number; failed: number }> {
    const { rows: tokens } = await this.pool.query<{
      token: string;
      platform: string;
    }>(
      `SELECT token, platform FROM push_tokens
        WHERE user_id = $1 AND active = true`,
      [userId],
    ).catch(() => ({ rows: [] }));

    let sent = 0;
    let failed = 0;
    for (const t of tokens) {
      const ok = await this.sendByPlatform(t.platform, t.token, title, message, data);
      if (ok) {
        sent++;
        // Обновляем last_used_at для tracking активных устройств.
        this.pool.query(
          `UPDATE push_tokens SET last_used_at = now() WHERE token = $1`,
          [t.token],
        ).catch(() => {});
      } else {
        failed++;
      }
    }
    return { sent, failed };
  }

  private async sendByPlatform(
    platform: string,
    token: string,
    title: string,
    message: string,
    data?: Record<string, string>,
  ): Promise<boolean> {
    if (platform === 'fcm' || platform === 'web') {
      return this._stubSendFcm(token, title, message, data);
    }
    if (platform === 'apns') {
      return this._stubSendApns(token, title, message, data);
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────
  //  NOT IMPLEMENTED — заглушки.
  //  Заменить на реальный SDK call когда будут ключи.
  // ────────────────────────────────────────────────────────────────────

  private async _stubSendFcm(
    token: string,
    title: string,
    _message: string,
    _data?: Record<string, string>,
  ): Promise<boolean> {
    // TODO[push]: реализовать через firebase-admin:
    //   const admin = require('firebase-admin');
    //   await admin.messaging().send({ token, notification: { title, body: message }, data });
    if (process.env.NODE_ENV !== 'production') {
      this.log.debug(`[stub-fcm] token=${token.slice(0, 8)}… title="${title}"`);
    }
    // В stub-режиме считаем "успехом" — не блокируем sales-flow.
    // В prod БЕЗ FCM ключей — это значит push не уходит, но в БД
    // notification создан и юзер увидит его при следующем заходе.
    return true;
  }

  private async _stubSendApns(
    token: string,
    title: string,
    _message: string,
    _data?: Record<string, string>,
  ): Promise<boolean> {
    // TODO[push]: реализовать через @parse/node-apn или firebase-admin (с APNS SAK).
    if (process.env.NODE_ENV !== 'production') {
      this.log.debug(`[stub-apns] token=${token.slice(0, 8)}… title="${title}"`);
    }
    return true;
  }
}
