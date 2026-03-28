import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AdminLogsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async list(limit = 50, offset = 0, action?: string) {
    let q = 'SELECT * FROM admin_logs WHERE 1=1';
    const p: any[] = [];
    if (action) { p.push(action); q += ` AND action = $${p.length}`; }
    q += ' ORDER BY created_at DESC';
    p.push(limit); q += ` LIMIT $${p.length}`;
    p.push(offset); q += ` OFFSET $${p.length}`;
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async count() {
    const { rows } = await this.pool.query('SELECT count(*)::int AS count FROM admin_logs');
    return rows[0].count;
  }

  async create(data: Record<string, any>) {
    const raw = data.details || data.p_details || null;
    const details = raw == null ? null : (typeof raw === 'string' ? raw : JSON.stringify(raw));
    const { rows } = await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [data.admin_id || data.p_admin_id || null, data.action || data.p_action, data.target_type || data.p_target_type || null, data.target_id || data.p_target_id || null, details],
    );
    return rows[0];
  }
}
