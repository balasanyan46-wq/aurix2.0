import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AaiService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getIndex(releaseId: number) {
    const { rows } = await this.pool.query('SELECT * FROM release_attention_index WHERE release_id=$1', [releaseId]);
    return rows;
  }

  async getClicks(query: Record<string, any>) {
    let q = 'SELECT * FROM release_clicks WHERE release_id=$1';
    const p: any[] = [query.release_id];
    if (query.created_at_gte) { p.push(query.created_at_gte); q += ` AND created_at >= $${p.length}`; }
    q += ' ORDER BY created_at ASC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async getPageViews(query: Record<string, any>) {
    let q = 'SELECT * FROM release_page_views WHERE release_id=$1';
    const p: any[] = [query.release_id];
    if (query.created_at_gte) { p.push(query.created_at_gte); q += ` AND created_at >= $${p.length}`; }
    q += ' ORDER BY created_at ASC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async getDnkAaiLinks(query: Record<string, any>) {
    let q = 'SELECT * FROM dnk_test_aai_links WHERE release_id=$1';
    const p: any[] = [query.release_id];
    q += ' ORDER BY created_at DESC';
    if (query.limit) { p.push(+query.limit); q += ` LIMIT $${p.length}`; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }
}
