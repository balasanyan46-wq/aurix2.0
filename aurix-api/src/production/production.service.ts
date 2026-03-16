import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class ProductionService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getOrders(userId?: number) {
    let q = 'SELECT * FROM production_orders';
    const p: any[] = [];
    if (userId) { p.push(userId); q += ' WHERE user_id=$1'; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createOrder(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO production_orders (user_id, release_id, title, status) VALUES ($1,$2,$3,$4) RETURNING *',
      [data.user_id, data.release_id||null, data.title||null, data.status||'active'],
    );
    return rows[0];
  }

  async batchInsertItems(items: any[]) {
    const results: any[] = [];
    for (const item of items) {
      const { rows } = await this.pool.query(
        'INSERT INTO production_order_items (order_id, service_id, status) VALUES ($1,$2,$3) RETURNING *',
        [item.order_id, item.service_id||null, item.status||'not_started'],
      );
      results.push(rows[0]);
    }
    return results;
  }

  async getItems(orderIds: string) {
    const ids = orderIds.split(',').map(Number).filter(n => !isNaN(n));
    if (!ids.length) return [];
    const { rows } = await this.pool.query(
      `SELECT * FROM production_order_items WHERE order_id = ANY($1) ORDER BY created_at ASC`,
      [ids],
    );
    return rows;
  }

  async updateItem(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['status','assignee_id','deadline_at','brief'].includes(k)) {
        sets.push(`${k}=$${i++}`); vals.push(v);
      }
    }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE production_order_items SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  // Service Catalog
  async getCatalog(isActive?: string) {
    let q = 'SELECT * FROM service_catalog';
    const p: any[] = [];
    if (isActive !== undefined) { p.push(isActive === 'true'); q += ' WHERE is_active=$1'; }
    q += ' ORDER BY created_at ASC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async upsertCatalog(data: Record<string, any>) {
    if (data.id) {
      const { rows } = await this.pool.query(
        `UPDATE service_catalog SET title=$1, description=$2, category=$3, default_price=$4, sla_days=$5, required_inputs=$6, deliverables=$7, is_active=$8
         WHERE id=$9 RETURNING *`,
        [data.title, data.description||null, data.category||null, data.default_price||0, data.sla_days||7,
         data.required_inputs?JSON.stringify(data.required_inputs):null, data.deliverables?JSON.stringify(data.deliverables):null, data.is_active??true, data.id],
      );
      return rows[0];
    }
    const { rows } = await this.pool.query(
      `INSERT INTO service_catalog (title, description, category, default_price, sla_days, required_inputs, deliverables, is_active)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [data.title, data.description||null, data.category||null, data.default_price||0, data.sla_days||7,
       data.required_inputs?JSON.stringify(data.required_inputs):null, data.deliverables?JSON.stringify(data.deliverables):null, data.is_active??true],
    );
    return rows[0];
  }

  // Assignees
  async getAssignees(isActive?: string) {
    let q = 'SELECT * FROM production_assignees';
    const p: any[] = [];
    if (isActive !== undefined) { p.push(isActive === 'true'); q += ' WHERE is_active=$1'; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async upsertAssignee(data: Record<string, any>) {
    if (data.id) {
      const { rows } = await this.pool.query(
        `UPDATE production_assignees SET full_name=$1, specialization=$2, contacts=$3, is_active=$4 WHERE id=$5 RETURNING *`,
        [data.full_name, data.specialization||null, data.contacts?JSON.stringify(data.contacts):null, data.is_active??true, data.id],
      );
      return rows[0];
    }
    const { rows } = await this.pool.query(
      `INSERT INTO production_assignees (user_id, full_name, specialization, contacts, is_active) VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [data.user_id||null, data.full_name, data.specialization||null, data.contacts?JSON.stringify(data.contacts):null, data.is_active??true],
    );
    return rows[0];
  }

  // Comments
  async getComments(orderItemId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM production_comments WHERE order_item_id=$1 ORDER BY created_at ASC', [orderItemId],
    );
    return rows;
  }

  async addComment(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO production_comments (order_item_id, author_user_id, author_role, message) VALUES ($1,$2,$3,$4) RETURNING *',
      [data.order_item_id, data.author_user_id||null, data.author_role||'user', data.message],
    );
    return rows[0];
  }

  // Files
  async getFiles(orderItemId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM production_files WHERE order_item_id=$1 ORDER BY created_at ASC', [orderItemId],
    );
    return rows;
  }

  async createFile(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO production_files (order_item_id, uploaded_by, kind, file_name, mime_type, storage_bucket, storage_path, size_bytes)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [data.order_item_id, data.uploaded_by||null, data.kind||null, data.file_name||null,
       data.mime_type||null, data.storage_bucket||null, data.storage_path||null, data.size_bytes||0],
    );
    return rows[0];
  }

  // Events
  async getEvents(orderItemId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM production_events WHERE order_item_id=$1 ORDER BY created_at ASC', [orderItemId],
    );
    return rows;
  }

  async addEvent(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO production_events (order_item_id, event_type, payload) VALUES ($1,$2,$3) RETURNING *',
      [data.order_item_id, data.event_type, data.payload?JSON.stringify(data.payload):null],
    );
    return rows[0];
  }

  async batchEvents(items: any[]) {
    const results: any[] = [];
    for (const item of items) {
      const r = await this.addEvent(item);
      results.push(r);
    }
    return results;
  }
}
