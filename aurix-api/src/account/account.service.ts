import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class AccountService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async requestDeletion(userId: number, reason?: string) {
    const { rows } = await this.pool.query(
      'INSERT INTO account_deletion_requests (user_id, reason, status) VALUES ($1,$2,$3) RETURNING *',
      [userId, reason||null, 'pending'],
    );
    return rows[0];
  }

  async getLatestStatus(userId: number) {
    const { rows } = await this.pool.query(
      'SELECT status FROM account_deletion_requests WHERE user_id=$1 ORDER BY created_at DESC LIMIT 1', [userId],
    );
    return rows[0] || { status: null };
  }

  async getDeleteRequests(requesterId?: number) {
    let q = 'SELECT * FROM release_delete_requests';
    const p: any[] = [];
    if (requesterId) { p.push(requesterId); q += ' WHERE requester_id=$1'; }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createDeleteRequest(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      'INSERT INTO release_delete_requests (release_id, requester_id, status, reason) VALUES ($1,$2,$3,$4) RETURNING *',
      [data.release_id, data.requester_id, data.status||'pending', data.reason||null],
    );
    return rows[0];
  }

  async updateDeleteRequest(id: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['status','admin_comment','processed_by','processed_at'].includes(k)) {
        sets.push(`${k}=$${i++}`); vals.push(v);
      }
    }
    if (!sets.length) return null;
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE release_delete_requests SET ${sets.join(',')} WHERE id=$${i} RETURNING *`, vals);
    return rows[0];
  }

  async processDeleteRequest(requestId: number, decision: string, comment?: string) {
    const status = decision === 'approve' ? 'approved' : 'rejected';
    const { rows } = await this.pool.query(
      `UPDATE release_delete_requests SET status=$1, admin_comment=$2, processed_at=NOW() WHERE id=$3 RETURNING *`,
      [status, comment||null, requestId],
    );
    return rows[0];
  }
}
