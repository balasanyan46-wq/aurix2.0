import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class LegalService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getTemplates(category?: string) {
    let q = 'SELECT * FROM legal_templates WHERE is_active=true';
    const p: any[] = [];
    if (category) { p.push(category); q += ` AND category=$${p.length}`; }
    q += ' ORDER BY sort_order ASC, created_at DESC';
    // sort_order doesn't exist, use created_at
    q = q.replace('ORDER BY sort_order ASC, created_at DESC', 'ORDER BY created_at DESC');
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async getTemplateById(id: number) {
    const { rows } = await this.pool.query('SELECT * FROM legal_templates WHERE id=$1', [id]);
    return rows[0] || null;
  }

  async getMyDocuments(userId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM legal_documents WHERE user_id=$1 ORDER BY created_at DESC', [userId],
    );
    return rows;
  }

  async createDocument(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO legal_documents (user_id, template_id, template_version, title, payload, status)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [userId, data.template_id||null, data.template_version||1, data.title||null,
       data.payload?JSON.stringify(data.payload):null, data.status||'generated'],
    );
    return rows[0];
  }

  async updateDocument(id: number, userId: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['file_pdf_path','status'].includes(k)) { sets.push(`${k}=$${i++}`); vals.push(v); }
    }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id, userId);
    // SECURITY: ownership check — AND user_id
    const { rows } = await this.pool.query(`UPDATE legal_documents SET ${sets.join(',')} WHERE id=$${i} AND user_id=$${i + 1} RETURNING *`, vals);
    return rows[0];
  }

  async batchAcceptances(userId: number, items: any[]) {
    for (const item of items) {
      await this.pool.query(
        `INSERT INTO legal_acceptances (user_id, doc_slug, version, accepted_at, acceptance_source)
         VALUES ($1,$2,$3,$4,$5)`,
        [userId, item.doc_slug, item.version||1, item.accepted_at||new Date().toISOString(), item.acceptance_source||'app'],
      );
    }
    return { success: true };
  }

  async getCookieConsent(userId: number) {
    const { rows } = await this.pool.query('SELECT * FROM cookie_consents WHERE user_id=$1', [userId]);
    return rows[0] || { analytics_allowed: false, marketing_allowed: false };
  }

  async upsertCookieConsent(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO cookie_consents (user_id, analytics_allowed, marketing_allowed, source, updated_at)
       VALUES ($1,$2,$3,$4,NOW())
       ON CONFLICT (user_id) DO UPDATE SET analytics_allowed=$2, marketing_allowed=$3, source=$4, updated_at=NOW()
       RETURNING *`,
      [userId, data.analytics_allowed??false, data.marketing_allowed??false, data.source||'app'],
    );
    return rows[0];
  }
}
