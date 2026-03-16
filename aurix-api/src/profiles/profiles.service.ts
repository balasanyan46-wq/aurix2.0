import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class ProfilesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async findByUserId(userId: string) {
    const { rows } = await this.pool.query(
      `SELECT * FROM profiles WHERE user_id = $1`,
      [userId],
    );
    return rows[0] || null;
  }

  async create(userId: string, data: Record<string, any>) {
    const fields = [
      'email',
      'name',
      'display_name',
      'artist_name',
      'phone',
      'city',
      'gender',
      'bio',
      'avatar_url',
      'role',
      'account_status',
      'plan',
      'plan_id',
      'billing_period',
      'subscription_status',
      'subscription_end',
    ];

    const provided = fields.filter((f) => data[f] !== undefined);
    const columns = ['user_id', ...provided];
    const values = [userId, ...provided.map((f) => data[f])];
    const placeholders = columns.map((_, i) => `$${i + 1}`);

    const updateSet = provided
      .map((f, i) => `${f} = $${i + 2}`)
      .join(', ');

    const query = updateSet
      ? `INSERT INTO profiles (${columns.join(', ')})
         VALUES (${placeholders.join(', ')})
         ON CONFLICT (user_id) DO UPDATE SET ${updateSet}, updated_at = now()
         RETURNING *`
      : `INSERT INTO profiles (user_id)
         VALUES ($1)
         ON CONFLICT (user_id) DO NOTHING
         RETURNING *`;

    const { rows } = await this.pool.query(query, values);

    // If DO NOTHING matched, return the existing row
    if (rows.length === 0) {
      return this.findByUserId(userId);
    }
    return rows[0];
  }

  async update(userId: string, data: Record<string, any>) {
    const fields = [
      'email',
      'name',
      'display_name',
      'artist_name',
      'phone',
      'city',
      'gender',
      'bio',
      'avatar_url',
      'plan',
      'plan_id',
      'billing_period',
      'subscription_status',
      'subscription_end',
    ];

    const provided = fields.filter((f) => data[f] !== undefined);
    if (provided.length === 0) {
      return this.findByUserId(userId);
    }

    const setClause = provided
      .map((f, i) => `${f} = $${i + 1}`)
      .join(', ');
    const values = [...provided.map((f) => data[f]), userId];

    const { rows } = await this.pool.query(
      `UPDATE profiles SET ${setClause}, updated_at = now()
       WHERE user_id = $${values.length}
       RETURNING *`,
      values,
    );
    return rows[0] || null;
  }

  async getAll() {
    const { rows } = await this.pool.query(
      `SELECT * FROM profiles ORDER BY created_at DESC`,
    );
    return rows;
  }

  async updateRole(userId: string, role: string) {
    const { rows } = await this.pool.query(
      `UPDATE profiles SET role = $1, updated_at = now()
       WHERE user_id = $2
       RETURNING *`,
      [role, userId],
    );
    return rows[0] || null;
  }

  async updateAccountStatus(userId: string, status: string) {
    const { rows } = await this.pool.query(
      `UPDATE profiles SET account_status = $1, updated_at = now()
       WHERE user_id = $2
       RETURNING *`,
      [status, userId],
    );
    return rows[0] || null;
  }
}
