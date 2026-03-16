import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class CrmService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // Leads
  async getLeads(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_leads WHERE 1=1';
    const p: any[] = [];
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    if (query.status_in) { const s = query.status_in.split(','); p.push(s); q += ` AND status=ANY($${p.length})`; }
    q += ' ORDER BY created_at DESC';
    if (query.limit) { p.push(+query.limit); q += ` LIMIT $${p.length}`; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async updateLead(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['pipeline_stage','assigned_to','priority','title','description','due_at','status'].includes(k)) {
        sets.push(`${k}=$${i++}`); vals.push(v);
      }
    }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE crm_leads SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  // Deals
  async getDeals(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_deals WHERE 1=1';
    const p: any[] = [];
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createDeal(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO crm_deals (user_id, release_id, lead_id, status, package_title) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [data.user_id, data.release_id||null, data.lead_id||null, data.status||'draft', data.package_title||null],
    );
    return rows[0];
  }

  async updateDeal(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    if (data.status) { sets.push(`status=$${i++}`); vals.push(data.status); }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE crm_deals SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  // Tasks
  async getTasks(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_tasks WHERE 1=1';
    const p: any[] = [];
    if (query.lead_id_in) { const ids = query.lead_id_in.split(',').map(Number); p.push(ids); q += ` AND lead_id=ANY($${p.length})`; }
    if (query.deal_id_in) { const ids = query.deal_id_in.split(',').map(Number); p.push(ids); q += ` AND deal_id=ANY($${p.length})`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createTask(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO crm_tasks (lead_id, deal_id, title, assigned_to, status, due_at) VALUES ($1,$2,$3,$4,$5,$6) RETURNING *',
      [data.lead_id||null, data.deal_id||null, data.title, data.assigned_to||null, data.status||'open', data.due_at||null],
    );
    return rows[0];
  }

  async updateTask(id: number, data: Record<string, any>) {
    const { rows } = await this.pool.query('UPDATE crm_tasks SET status=$1 WHERE id=$2 RETURNING *', [data.status, id]);
    return rows[0];
  }

  // Notes
  async getNotes(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_notes WHERE 1=1';
    const p: any[] = [];
    if (query.lead_id) { p.push(query.lead_id); q += ` AND lead_id=$${p.length}`; }
    if (query.deal_id) { p.push(query.deal_id); q += ` AND deal_id=$${p.length}`; }
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async addNote(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO crm_notes (user_id, author_id, lead_id, deal_id, message) VALUES ($1,$2,$3,$4,$5) RETURNING *',
      [data.user_id||null, data.author_id||null, data.lead_id||null, data.deal_id||null, data.message],
    );
    return rows[0];
  }

  // Events
  async getEvents(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_events WHERE 1=1';
    const p: any[] = [];
    if (query.lead_id) { p.push(query.lead_id); q += ` AND lead_id=$${p.length}`; }
    if (query.deal_id) { p.push(query.deal_id); q += ` AND deal_id=$${p.length}`; }
    if (query.lead_id_in) { const ids = query.lead_id_in.split(',').map(Number); p.push(ids); q += ` AND lead_id=ANY($${p.length})`; }
    if (query.deal_id_in) { const ids = query.deal_id_in.split(',').map(Number); p.push(ids); q += ` AND deal_id=ANY($${p.length})`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async addEvent(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO crm_events (lead_id, deal_id, event_type, payload) VALUES ($1,$2,$3,$4) RETURNING *',
      [data.lead_id||null, data.deal_id||null, data.event_type, data.payload?JSON.stringify(data.payload):null],
    );
    return rows[0];
  }

  // Invoices
  async getInvoices(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_invoices WHERE 1=1';
    const p: any[] = [];
    if (query.deal_id) { p.push(query.deal_id); q += ` AND deal_id=$${p.length}`; }
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async upsertInvoice(data: Record<string, any>) {
    if (data.id) {
      const { rows } = await this.pool.query(
        `UPDATE crm_invoices SET deal_id=$1, user_id=$2, amount=$3, currency=$4, status=$5, due_at=$6, paid_at=$7, external_ref=$8, meta=$9, updated_at=NOW()
         WHERE id=$10 RETURNING *`,
        [data.deal_id, data.user_id, data.amount||0, data.currency||'RUB', data.status||'draft', data.due_at||null, data.paid_at||null, data.external_ref||null, data.meta?JSON.stringify(data.meta):null, data.id],
      );
      return rows[0];
    }
    const { rows } = await this.pool.query(
      `INSERT INTO crm_invoices (deal_id, user_id, amount, currency, status, due_at, paid_at, external_ref, meta)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING *`,
      [data.deal_id, data.user_id, data.amount||0, data.currency||'RUB', data.status||'draft', data.due_at||null, data.paid_at||null, data.external_ref||null, data.meta?JSON.stringify(data.meta):null],
    );
    return rows[0];
  }

  // Transactions
  async getTransactions(query: Record<string, any>) {
    let q = 'SELECT * FROM crm_transactions WHERE 1=1';
    const p: any[] = [];
    if (query.invoice_id) { p.push(query.invoice_id); q += ` AND invoice_id=$${p.length}`; }
    if (query.user_id) { p.push(query.user_id); q += ` AND user_id=$${p.length}`; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async addTransaction(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO crm_transactions (invoice_id, user_id, amount, provider, status, paid_at, payload)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [data.invoice_id, data.user_id, data.amount||0, data.provider||null, data.status||'pending', data.paid_at||null, data.payload?JSON.stringify(data.payload):null],
    );
    return rows[0];
  }
}
