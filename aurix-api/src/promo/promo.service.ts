import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class PromoService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async list(query: Record<string, any>) {
    let q = 'SELECT * FROM promo_requests WHERE 1=1';
    const p: any[] = [];
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    if (query.release_id) { p.push(query.release_id); q += ` AND release_id=$${p.length}`; }
    if (query.status_in) {
      const statuses = query.status_in.split(',');
      q += ` AND status = ANY($${p.length + 1})`;
      p.push(statuses);
    }
    q += ' ORDER BY created_at DESC';
    if (query.limit) { p.push(+query.limit); q += ` LIMIT $${p.length}`; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async create(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO promo_requests (user_id, release_id, type, status, form_data)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [data.user_id, data.release_id||null, data.type, data.status||'submitted',
       data.form_data?JSON.stringify(data.form_data):null],
    );
    return rows[0];
  }

  async update(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['status','form_data','admin_notes','assigned_manager'].includes(k)) {
        sets.push(`${k}=$${i++}`);
        vals.push(k === 'form_data' ? JSON.stringify(v) : v);
      }
    }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE promo_requests SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  async findById(id: number) {
    const { rows } = await this.pool.query('SELECT * FROM promo_requests WHERE id=$1', [id]);
    return rows[0] ?? null;
  }

  async getEvents(promoRequestId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM promo_events WHERE promo_request_id=$1 ORDER BY created_at DESC', [promoRequestId],
    );
    return rows;
  }

  async addEvent(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO promo_events (promo_request_id, event_type, payload) VALUES ($1,$2,$3) RETURNING *',
      [data.promo_request_id, data.event_type, data.payload?JSON.stringify(data.payload):null],
    );
    return rows[0];
  }
}
