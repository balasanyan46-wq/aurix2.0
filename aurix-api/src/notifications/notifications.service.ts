import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export interface SendNotificationDto {
  user_id: number;
  title: string;
  message: string;
  type?: string;   // system | promo | warning | success | ai
  meta?: Record<string, any>;
}

@Injectable()
export class NotificationsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** Send a notification to a user. */
  async send(dto: SendNotificationDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO notifications (user_id, title, message, type, meta)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [dto.user_id, dto.title, dto.message, dto.type || 'system', dto.meta ? JSON.stringify(dto.meta) : '{}'],
    );
    return rows[0];
  }

  /** Bulk send to multiple users (batched to stay within PG param limit). */
  async sendBulk(userIds: number[], title: string, message: string, type = 'system') {
    if (!userIds.length) return 0;
    const BATCH_SIZE = 500; // 500 * 4 params = 2000, well within PG 65535 limit
    let total = 0;
    for (let offset = 0; offset < userIds.length; offset += BATCH_SIZE) {
      const batch = userIds.slice(offset, offset + BATCH_SIZE);
      const values = batch.map((_, i) => `($${i * 4 + 1},$${i * 4 + 2},$${i * 4 + 3},$${i * 4 + 4})`).join(',');
      const params = batch.flatMap(uid => [uid, title, message, type]);
      const { rowCount } = await this.pool.query(
        `INSERT INTO notifications (user_id, title, message, type) VALUES ${values}`,
        params,
      );
      total += rowCount ?? 0;
    }
    return total;
  }

  /** Get user's notifications (newest first). */
  async forUser(userId: number, limit = 50, unreadOnly = false) {
    let q = 'SELECT * FROM notifications WHERE user_id = $1';
    if (unreadOnly) q += ' AND is_read = false';
    q += ' ORDER BY created_at DESC LIMIT $2';
    const { rows } = await this.pool.query(q, [userId, limit]);
    return rows;
  }

  /** Unread count for user. */
  async unreadCount(userId: number): Promise<number> {
    const { rows } = await this.pool.query(
      'SELECT count(*)::int AS c FROM notifications WHERE user_id = $1 AND is_read = false',
      [userId],
    );
    return rows[0].c;
  }

  /** Mark one or all as read. */
  async markRead(userId: number, notificationId?: number) {
    if (notificationId) {
      await this.pool.query(
        'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2',
        [notificationId, userId],
      );
    } else {
      await this.pool.query(
        'UPDATE notifications SET is_read = true WHERE user_id = $1 AND is_read = false',
        [userId],
      );
    }
  }

  /** Admin: list all notifications (with filters). */
  async listAll(opts: { userId?: number; type?: string; limit?: number; offset?: number }) {
    let q = 'SELECT * FROM notifications WHERE 1=1';
    const p: any[] = [];
    if (opts.userId) { p.push(opts.userId); q += ` AND user_id = $${p.length}`; }
    if (opts.type) { p.push(opts.type); q += ` AND type = $${p.length}`; }
    q += ' ORDER BY created_at DESC';
    p.push(opts.limit || 50); q += ` LIMIT $${p.length}`;
    p.push(opts.offset || 0); q += ` OFFSET $${p.length}`;
    const { rows } = await this.pool.query(q, p);
    return rows;
  }
}
