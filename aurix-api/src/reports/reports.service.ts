import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class ReportsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async list() {
    const { rows } = await this.pool.query('SELECT * FROM reports ORDER BY created_at DESC');
    return rows;
  }

  async findById(id: number) {
    const { rows } = await this.pool.query('SELECT * FROM reports WHERE id = $1', [id]);
    return rows[0] || null;
  }

  async create(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO reports (period_start, period_end, distributor, file_name, file_url, created_by, user_id, release_id, import_hash, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [data.period_start, data.period_end, data.distributor||null, data.file_name||null, data.file_url||null, data.created_by||null, data.user_id||null, data.release_id||null, data.import_hash||null, data.status||'uploaded'],
    );
    return rows[0];
  }

  async update(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['status','file_url','file_name'].includes(k)) { sets.push(`${k}=$${i++}`); vals.push(v); }
    }
    if (!sets.length) return null;
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE reports SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  async delete(id: number) {
    await this.pool.query('DELETE FROM reports WHERE id = $1', [id]);
  }

  // Report rows
  async getRows(query: Record<string, any>) {
    let q = 'SELECT * FROM report_rows WHERE 1=1';
    const p: any[] = [];
    if (query.report_id) { p.push(query.report_id); q += ` AND report_id=$${p.length}`; }
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    if (query.release_id) { p.push(query.release_id); q += ` AND release_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC';
    if (query.limit) { p.push(+query.limit); q += ` LIMIT $${p.length}`; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async batchInsertRows(rows: any[]) {
    if (!rows.length) return [];
    const results: any[] = [];
    for (const r of rows) {
      const { rows: inserted } = await this.pool.query(
        `INSERT INTO report_rows (report_id, report_date, track_title, isrc, platform, country, streams, revenue, currency, raw_row_json, user_id, release_id)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
        [r.report_id, r.report_date||null, r.track_title||null, r.isrc||null, r.platform||null, r.country||null, r.streams||0, r.revenue||0, r.currency||'USD', r.raw_row_json?JSON.stringify(r.raw_row_json):null, r.user_id||null, r.release_id||null],
      );
      results.push(inserted[0]);
    }
    return results;
  }

  async updateRow(id: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'UPDATE report_rows SET track_id=$1 WHERE id=$2 RETURNING *', [data.track_id, id],
    );
    return rows[0];
  }

  async deleteRowsByReport(reportId: number) {
    await this.pool.query('DELETE FROM report_rows WHERE report_id = $1', [reportId]);
  }
}
