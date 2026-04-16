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
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');
      const results: any[] = [];
      for (const r of rows) {
        const { rows: inserted } = await client.query(
          `INSERT INTO report_rows (report_id, report_date, track_title, isrc, platform, country, streams, revenue, currency, raw_row_json, user_id, release_id)
           VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12) RETURNING *`,
          [r.report_id, r.report_date||null, r.track_title||null, r.isrc||null, r.platform||null, r.country||null, r.streams||0, r.revenue||0, r.currency||'USD', r.raw_row_json?JSON.stringify(r.raw_row_json):null, r.user_id||null, r.release_id||null],
        );
        results.push(inserted[0]);
      }
      await client.query('COMMIT');
      return results;
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
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

  /**
   * Быстрый массовый матч строк отчёта к трекам по ISRC.
   * Возвращает сколько строк подматчилось + сводку по релизам.
   */
  async matchRowsByIsrcBulk(reportId: number): Promise<{
    matched: number;
    unmatched: number;
    by_release: Array<{ release_id: string | null; title: string | null; rows: number; revenue: number; streams: number }>;
  }> {
    // Матчим одним апдейтом: проставляем track_id + release_id + user_id.
    // ISRC нормализуем по регистру и пробелам.
    await this.pool.query(
      `UPDATE report_rows rr
         SET track_id = t.id,
             release_id = t.release_id,
             user_id = a.user_id
       FROM tracks t
       JOIN releases r ON r.id = t.release_id
       JOIN artists a ON a.id = r.artist_id
       WHERE rr.report_id = $1
         AND rr.track_id IS NULL
         AND rr.isrc IS NOT NULL
         AND length(trim(rr.isrc)) > 0
         AND upper(trim(rr.isrc)) = upper(trim(t.isrc))`,
      [reportId],
    );

    // Сводка
    const { rows: counts } = await this.pool.query(
      `SELECT
         count(*) FILTER (WHERE track_id IS NOT NULL)::int AS matched,
         count(*) FILTER (WHERE track_id IS NULL)::int AS unmatched
       FROM report_rows WHERE report_id = $1`,
      [reportId],
    );
    const matched = counts[0]?.matched ?? 0;
    const unmatched = counts[0]?.unmatched ?? 0;

    // Разбивка по релизам
    const { rows: byRel } = await this.pool.query(
      `SELECT
         rr.release_id,
         r.title,
         count(*)::int AS rows,
         COALESCE(sum(rr.revenue), 0)::float AS revenue,
         COALESCE(sum(rr.streams), 0)::bigint AS streams
       FROM report_rows rr
       LEFT JOIN releases r ON r.id = rr.release_id
       WHERE rr.report_id = $1
       GROUP BY rr.release_id, r.title
       ORDER BY revenue DESC NULLS LAST`,
      [reportId],
    );

    return {
      matched,
      unmatched,
      by_release: byRel.map((r) => ({
        release_id: r.release_id,
        title: r.title,
        rows: Number(r.rows),
        revenue: Number(r.revenue),
        streams: Number(r.streams),
      })),
    };
  }

  /** Все треки пользователя (для preview матча в админке). */
  async getTracksByUser(userId: string): Promise<any[]> {
    const { rows } = await this.pool.query(
      `SELECT t.*, r.title AS release_title, a.user_id AS owner_id
         FROM tracks t
         JOIN releases r ON r.id = t.release_id
         JOIN artists a ON a.id = r.artist_id
        WHERE a.user_id = $1
        ORDER BY r.created_at DESC, t.track_number ASC`,
      [userId],
    );
    return rows;
  }
}
