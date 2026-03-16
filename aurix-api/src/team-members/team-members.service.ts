import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class TeamMembersService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async findByOwner(ownerId: number, excludeStatus?: string) {
    let q = 'SELECT * FROM team_members WHERE owner_id = $1';
    const params: any[] = [ownerId];
    if (excludeStatus) { q += ' AND status != $2'; params.push(excludeStatus); }
    q += ' ORDER BY created_at DESC';
    const { rows } = await this.pool.query(q, params);
    return rows;
  }

  async create(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO team_members (owner_id, member_name, member_email, role, split_percent)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [data.owner_id, data.member_name, data.member_email || null, data.role || 'contributor', data.split_percent || 0],
    );
    return rows[0];
  }

  async update(id: number, data: Record<string, any>) {
    const sets: string[] = [];
    const vals: any[] = [];
    let i = 1;
    for (const [k, v] of Object.entries(data)) {
      if (['member_name','member_email','role','split_percent','status'].includes(k)) {
        sets.push(`${k} = $${i++}`);
        vals.push(v);
      }
    }
    if (!sets.length) return null;
    sets.push(`updated_at = NOW()`);
    vals.push(id);
    const { rows } = await this.pool.query(
      `UPDATE team_members SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`, vals,
    );
    return rows[0];
  }
}
