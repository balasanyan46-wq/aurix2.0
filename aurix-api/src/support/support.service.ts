import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class SupportService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getTickets(userId?: string, status?: string) {
    let q = 'SELECT * FROM support_tickets WHERE 1=1';
    const p: any[] = [];
    if (userId) { p.push(userId); q += ` AND user_id = $${p.length}`; }
    if (status) { p.push(status); q += ` AND status = $${p.length}`; }
    q += ' ORDER BY updated_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createTicket(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO support_tickets (user_id, subject, message, priority) VALUES ($1,$2,$3,$4) RETURNING *`,
      [data.user_id, data.subject, data.message || null, data.priority || 'normal'],
    );
    return rows[0];
  }

  async updateTicket(id: number, data: Record<string, any>) {
    const sets: string[] = [];
    const vals: any[] = [];
    let i = 1;
    for (const [k, v] of Object.entries(data)) {
      if (['status','admin_reply','admin_id','updated_at','first_response_at','resolved_at'].includes(k)) {
        sets.push(`${k} = $${i++}`); vals.push(v);
      }
    }
    if (!sets.length) return null;
    if (!sets.some(s => s.startsWith('updated_at'))) sets.push('updated_at = NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(
      `UPDATE support_tickets SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals,
    );
    return rows[0];
  }

  async getMessages(ticketId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM support_messages WHERE ticket_id = $1 ORDER BY created_at ASC', [ticketId],
    );
    return rows;
  }

  async addMessage(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO support_messages (ticket_id, sender_id, sender_role, body) VALUES ($1,$2,$3,$4) RETURNING *`,
      [data.ticket_id, data.sender_id, data.sender_role || 'user', data.body],
    );
    return rows[0];
  }
}
