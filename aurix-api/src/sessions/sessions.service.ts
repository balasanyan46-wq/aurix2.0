import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class SessionsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /** Start a new session. Returns session ID. */
  async start(userId: number, device?: string, ip?: string, userAgent?: string) {
    const { rows } = await this.pool.query(
      `INSERT INTO user_sessions (user_id, device, ip, user_agent) VALUES ($1,$2,$3,$4) RETURNING *`,
      [userId, device || 'web', ip || null, userAgent || null],
    );
    return rows[0];
  }

  /** End a session (with ownership check). */
  async end(sessionId: number, userId: number) {
    const { rows } = await this.pool.query(
      `UPDATE user_sessions SET ended_at = now(), duration_s = EXTRACT(EPOCH FROM (now() - started_at))::int
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [sessionId, userId],
    );
    return rows[0] || null;
  }

  /** Log a session event (with ownership check). */
  async logEvent(sessionId: number, userId: number, eventType: string, screen?: string, action?: string, meta?: any) {
    // Verify session belongs to user
    const { rows: check } = await this.pool.query(
      'SELECT 1 FROM user_sessions WHERE id = $1 AND user_id = $2',
      [sessionId, userId],
    );
    if (!check.length) return null;

    const { rows } = await this.pool.query(
      `INSERT INTO session_events (session_id, event_type, screen, action, meta)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [sessionId, eventType, screen || null, action || null, meta ? JSON.stringify(meta) : null],
    );
    return rows[0];
  }

  /** Get sessions for a user (admin). */
  async forUser(userId: number, limit = 20) {
    const { rows } = await this.pool.query(
      `SELECT s.*, (SELECT count(*)::int FROM session_events WHERE session_id = s.id) AS event_count
       FROM user_sessions s WHERE s.user_id = $1
       ORDER BY s.started_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows;
  }

  /** Get session detail with all events (admin — session replay). */
  async replay(sessionId: number) {
    const [session, events] = await Promise.all([
      this.pool.query('SELECT * FROM user_sessions WHERE id = $1', [sessionId]),
      this.pool.query('SELECT * FROM session_events WHERE session_id = $1 ORDER BY created_at', [sessionId]),
    ]);
    return {
      session: session.rows[0] || null,
      events: events.rows,
    };
  }

  /** Recent sessions (admin overview). */
  async recent(limit = 30) {
    const { rows } = await this.pool.query(
      `SELECT s.*, u.email,
              (SELECT count(*)::int FROM session_events WHERE session_id = s.id) AS event_count
       FROM user_sessions s
       JOIN users u ON u.id = s.user_id
       ORDER BY s.started_at DESC LIMIT $1`,
      [limit],
    );
    return rows;
  }

  /** Stats: avg session duration, sessions per day. */
  async stats(days = 7) {
    const { rows } = await this.pool.query(`
      SELECT
        count(*)::int AS total_sessions,
        round(avg(duration_s))::int AS avg_duration_s,
        count(DISTINCT user_id)::int AS unique_users
      FROM user_sessions
      WHERE started_at >= current_date - $1::int
        AND duration_s IS NOT NULL
    `, [days]);
    return rows[0];
  }
}
