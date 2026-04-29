import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export type LeadStatus = 'new' | 'contacted' | 'in_progress' | 'converted' | 'lost';
export type LeadBucket = 'cold' | 'warm' | 'hot';
export type LeadSource = 'ai' | 'system' | 'manual';

export interface LeadRow {
  id: string;
  user_id: number;
  lead_score: number;
  lead_bucket: LeadBucket;
  status: LeadStatus;
  assigned_to: number | null;
  last_contact_at: string | null;
  next_action: string | null;
  source: LeadSource;
  created_at: string;
  updated_at: string;
}

/**
 * LeadService — автоматическая воронка leads.
 *
 * Главный API:
 *   ensureLead(userId, score, bucket, source)
 *     → создаёт lead если его нет (или обновляет существующий)
 *
 *   markConverted(userId)
 *     → вызывается из платёжного flow при confirmed payment
 *
 *   sweepStale()
 *     → cron-friendly: помечает lost для leads без активности 14+ дней
 *
 * Связь с lead-scoring:
 *   - LeadScoringService считает score в profiles
 *   - LeadService слушает: при score > 70 → ensureLead
 *   - PaymentService при success → markConverted
 */
@Injectable()
export class LeadsService {
  private readonly logger = new Logger(LeadsService.name);

  /**
   * Порог попадания в leads автоматически. Score >= этого создаёт lead.
   */
  static readonly AUTO_CREATE_THRESHOLD = 70;

  /**
   * Сколько дней без активности → lost.
   */
  static readonly STALE_DAYS = 14;

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Атомарная upsert-логика: если активный lead есть — обновляет score/bucket,
   * иначе создаёт. Использует partial unique index uniq_leads_user_active.
   *
   * Возвращает текущую запись lead'а.
   */
  async ensureLead(
    userId: number,
    score: number,
    bucket: LeadBucket,
    source: LeadSource = 'system',
  ): Promise<LeadRow | null> {
    if (score < LeadsService.AUTO_CREATE_THRESHOLD && bucket !== 'hot') {
      // Не hot — не создаём, но если уже есть — обновим.
      return this.updateScoreIfExists(userId, score, bucket);
    }

    // Активная запись?
    const { rows } = await this.pool.query<LeadRow>(
      `SELECT * FROM leads
        WHERE user_id = $1 AND status NOT IN ('converted', 'lost')
        LIMIT 1`,
      [userId],
    ).catch(() => ({ rows: [] as LeadRow[] }));

    if (rows[0]) {
      // Обновляем score/bucket. Status и assignment не трогаем.
      const { rows: upd } = await this.pool.query<LeadRow>(
        `UPDATE leads
            SET lead_score = $2, lead_bucket = $3
          WHERE id = $1
        RETURNING *`,
        [rows[0].id, score, bucket],
      );
      return upd[0] ?? rows[0];
    }

    // Создаём новый lead.
    try {
      const { rows: ins } = await this.pool.query<LeadRow>(
        `INSERT INTO leads (user_id, lead_score, lead_bucket, source, status)
         VALUES ($1, $2, $3, $4, 'new')
         RETURNING *`,
        [userId, score, bucket, source],
      );
      return ins[0] ?? null;
    } catch (e: any) {
      // Гонка: кто-то параллельно создал lead. Перечитаем.
      if (e.code === '23505') {
        const { rows: again } = await this.pool.query<LeadRow>(
          `SELECT * FROM leads
            WHERE user_id = $1 AND status NOT IN ('converted', 'lost')
            LIMIT 1`,
          [userId],
        );
        return again[0] ?? null;
      }
      this.logger.error(`ensureLead failed for user ${userId}: ${e.message}`);
      return null;
    }
  }

  /**
   * Обновляет score/bucket у существующего активного lead'а (если есть).
   * Не создаёт новый — используется когда score снизился ниже порога.
   */
  private async updateScoreIfExists(
    userId: number,
    score: number,
    bucket: LeadBucket,
  ): Promise<LeadRow | null> {
    const { rows } = await this.pool.query<LeadRow>(
      `UPDATE leads
          SET lead_score = $2, lead_bucket = $3
        WHERE user_id = $1 AND status NOT IN ('converted', 'lost')
      RETURNING *`,
      [userId, score, bucket],
    ).catch(() => ({ rows: [] as LeadRow[] }));
    return rows[0] ?? null;
  }

  /**
   * Получить активный lead пользователя (если есть).
   */
  async getActiveByUser(userId: number): Promise<LeadRow | null> {
    const { rows } = await this.pool.query<LeadRow>(
      `SELECT * FROM leads
        WHERE user_id = $1 AND status NOT IN ('converted', 'lost')
        ORDER BY created_at DESC LIMIT 1`,
      [userId],
    ).catch(() => ({ rows: [] as LeadRow[] }));
    return rows[0] ?? null;
  }

  /**
   * Конверсия: вызывается при успешной оплате. Обновляет статус активного
   * lead'а на 'converted'. Идемпотентна — если lead'а нет, тихо ничего не делает.
   */
  async markConverted(userId: number): Promise<LeadRow | null> {
    const { rows } = await this.pool.query<LeadRow>(
      `UPDATE leads
          SET status = 'converted'
        WHERE user_id = $1 AND status NOT IN ('converted', 'lost')
      RETURNING *`,
      [userId],
    ).catch(() => ({ rows: [] as LeadRow[] }));
    if (rows[0]) {
      this.logger.log(`Lead ${rows[0].id} (user ${userId}) → converted`);
    }
    return rows[0] ?? null;
  }

  /**
   * Sweep: leads без активности 14+ дней → 'lost'. Считается отсутствие
   * как отсутствия событий в user_events для этого user_id за период.
   * Возвращает количество обновлённых записей.
   */
  async sweepStale(): Promise<{ lost: number }> {
    const days = LeadsService.STALE_DAYS;
    const { rowCount } = await this.pool.query(
      `
      UPDATE leads l
         SET status = 'lost'
       WHERE l.status NOT IN ('converted', 'lost')
         AND NOT EXISTS (
           SELECT 1 FROM user_events ue
            WHERE ue.user_id = l.user_id
              AND ue.created_at >= now() - interval '${days} days'
         )
      `,
    ).catch(() => ({ rowCount: 0 }));
    return { lost: rowCount ?? 0 };
  }

  /**
   * Список leads с фильтрами (status, bucket, assigned_to).
   * JOIN на users/profiles для отображения email и имени в UI.
   */
  async list(filters: {
    status?: LeadStatus;
    bucket?: LeadBucket;
    assigned_to?: number;
    limit?: number;
    offset?: number;
  }): Promise<Array<LeadRow & { email: string; display_name: string | null }>> {
    const where: string[] = ['1=1'];
    const params: any[] = [];
    if (filters.status) { params.push(filters.status); where.push(`l.status = $${params.length}`); }
    if (filters.bucket) { params.push(filters.bucket); where.push(`l.lead_bucket = $${params.length}`); }
    if (filters.assigned_to != null) { params.push(filters.assigned_to); where.push(`l.assigned_to = $${params.length}`); }

    const limit = Math.min(Math.max(filters.limit ?? 100, 1), 500);
    params.push(limit);
    const limitParam = `$${params.length}`;
    params.push(filters.offset ?? 0);
    const offsetParam = `$${params.length}`;

    const { rows } = await this.pool.query(
      `
      SELECT l.*, u.email, p.display_name
        FROM leads l
        LEFT JOIN users u ON u.id = l.user_id
        LEFT JOIN profiles p ON p.user_id = l.user_id
       WHERE ${where.join(' AND ')}
       ORDER BY
         CASE l.lead_bucket WHEN 'hot' THEN 0 WHEN 'warm' THEN 1 ELSE 2 END,
         l.lead_score DESC,
         l.updated_at DESC
       LIMIT ${limitParam} OFFSET ${offsetParam}
      `,
      params,
    ).catch(() => ({ rows: [] }));
    return rows;
  }

  /**
   * Patch lead (status / assigned_to / next_action). Используется из
   * PATCH /admin/leads/:id. Любой вызов пишет в admin_logs c reason.
   */
  async patch(
    id: string,
    patch: {
      status?: LeadStatus;
      assigned_to?: number | null;
      next_action?: string | null;
    },
    adminId: number,
    reason: string,
  ): Promise<LeadRow | null> {
    const sets: string[] = [];
    const params: any[] = [];
    if (patch.status) { params.push(patch.status); sets.push(`status = $${params.length}`); }
    if (patch.assigned_to !== undefined) { params.push(patch.assigned_to); sets.push(`assigned_to = $${params.length}`); }
    if (patch.next_action !== undefined) { params.push(patch.next_action); sets.push(`next_action = $${params.length}`); }
    if (sets.length === 0) return this.getById(id);

    params.push(id);
    const { rows } = await this.pool.query<LeadRow>(
      `UPDATE leads SET ${sets.join(', ')} WHERE id = $${params.length} RETURNING *`,
      params,
    );
    if (!rows[0]) return null;

    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'lead_patched', 'lead', $2, $3)`,
      [adminId, id, JSON.stringify({ patch, reason })],
    ).catch(() => {});
    return rows[0];
  }

  /**
   * "Связались с лидом" — обновляет last_contact_at + audit log.
   * status автоматически продвигается new → contacted, если был new.
   */
  async markContacted(
    id: string,
    adminId: number,
    reason: string,
  ): Promise<LeadRow | null> {
    const { rows } = await this.pool.query<LeadRow>(
      `UPDATE leads
          SET last_contact_at = now(),
              status = CASE WHEN status = 'new' THEN 'contacted' ELSE status END
        WHERE id = $1
      RETURNING *`,
      [id],
    );
    if (!rows[0]) return null;

    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'lead_contacted', 'lead', $2, $3)`,
      [adminId, id, JSON.stringify({ reason, lead_user_id: rows[0].user_id })],
    ).catch(() => {});
    return rows[0];
  }

  async getById(id: string): Promise<LeadRow | null> {
    const { rows } = await this.pool.query<LeadRow>(
      `SELECT * FROM leads WHERE id = $1`,
      [id],
    );
    return rows[0] ?? null;
  }

  /**
   * Запись next_action в активный lead пользователя. Используется
   * NextActionService для синхронизации между движком рекомендаций и leads.
   */
  async setNextAction(userId: number, action: string | null): Promise<void> {
    await this.pool.query(
      `UPDATE leads
          SET next_action = $2
        WHERE user_id = $1 AND status NOT IN ('converted', 'lost')`,
      [userId, action],
    ).catch(() => {});
  }
}
