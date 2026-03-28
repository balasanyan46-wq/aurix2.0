import { Injectable, Inject, Optional } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { AutoActionsService } from '../auto-actions/auto-actions.service';
import { GrowthService } from '../growth/growth.service';

export interface CreateEventDto {
  user_id: number;
  event: string;
  target_type?: string;
  target_id?: string;
  meta?: Record<string, any>;
  ip?: string;
  user_agent?: string;
}

@Injectable()
export class UserEventsService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Optional() private readonly autoActions?: AutoActionsService,
    @Optional() private readonly growth?: GrowthService,
  ) {}

  /** Log a user event + trigger auto-actions. */
  async log(dto: CreateEventDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO user_events (user_id, event, target_type, target_id, meta, ip, user_agent)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [dto.user_id, dto.event, dto.target_type || null, dto.target_id || null, dto.meta ? JSON.stringify(dto.meta) : '{}', dto.ip || null, dto.user_agent || null],
    );

    // Fire-and-forget: run auto-action rules
    if (this.autoActions) {
      this.autoActions.processEvent(dto.user_id, dto.event, dto.meta).catch(() => {});
    }

    // Fire-and-forget: XP + achievements
    if (this.growth) {
      this.growth.grantActionXp(dto.user_id, dto.event).catch(() => {});
      this.growth.checkAchievements(dto.user_id, dto.event).catch(() => {});
      this.growth.updateStreak(dto.user_id).catch(() => {});
    }

    return rows[0];
  }

  /** List events for a specific user (timeline). */
  async forUser(userId: number, limit = 50, offset = 0) {
    const { rows } = await this.pool.query(
      `SELECT * FROM user_events WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );
    return rows;
  }

  /** Search/filter events (admin). */
  async search(opts: { event?: string; userId?: number; targetType?: string; from?: string; to?: string; limit?: number; offset?: number }) {
    let q = 'SELECT * FROM user_events WHERE 1=1';
    const p: any[] = [];

    if (opts.userId) { p.push(opts.userId); q += ` AND user_id = $${p.length}`; }
    if (opts.event) { p.push(opts.event); q += ` AND event = $${p.length}`; }
    if (opts.targetType) { p.push(opts.targetType); q += ` AND target_type = $${p.length}`; }
    if (opts.from) { p.push(opts.from); q += ` AND created_at >= $${p.length}::timestamptz`; }
    if (opts.to) { p.push(opts.to); q += ` AND created_at <= $${p.length}::timestamptz`; }

    q += ' ORDER BY created_at DESC';
    p.push(opts.limit || 50); q += ` LIMIT $${p.length}`;
    p.push(opts.offset || 0); q += ` OFFSET $${p.length}`;

    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  /** Count events with optional filters. */
  async count(opts: { event?: string; userId?: number; from?: string; to?: string } = {}) {
    let q = 'SELECT count(*)::int AS count FROM user_events WHERE 1=1';
    const p: any[] = [];

    if (opts.userId) { p.push(opts.userId); q += ` AND user_id = $${p.length}`; }
    if (opts.event) { p.push(opts.event); q += ` AND event = $${p.length}`; }
    if (opts.from) { p.push(opts.from); q += ` AND created_at >= $${p.length}::timestamptz`; }
    if (opts.to) { p.push(opts.to); q += ` AND created_at <= $${p.length}::timestamptz`; }

    const { rows } = await this.pool.query(q, p);
    return rows[0].count;
  }

  /** DAU for the last N days. */
  async dau(days = 30) {
    const { rows } = await this.pool.query(
      `SELECT day, dau FROM v_dau WHERE day >= (current_date - $1::int) ORDER BY day`,
      [days],
    );
    return rows;
  }

  /** MAU for the last N months. */
  async mau(months = 12) {
    const { rows } = await this.pool.query(
      `SELECT month, mau FROM v_mau WHERE month >= (date_trunc('month', current_date) - ($1::int || ' months')::interval)::date ORDER BY month`,
      [months],
    );
    return rows;
  }

  /** Event breakdown (top events by count). */
  async eventBreakdown(days = 30) {
    const { rows } = await this.pool.query(
      `SELECT event, count(*)::int AS count
       FROM user_events
       WHERE created_at >= (current_date - $1::int)
       GROUP BY event ORDER BY count DESC`,
      [days],
    );
    return rows;
  }

  /** Distinct event types. */
  async eventTypes() {
    const { rows } = await this.pool.query(
      `SELECT DISTINCT event FROM user_events ORDER BY event`,
    );
    return rows.map((r: any) => r.event);
  }
}
