import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class ProgressService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // Habits
  async getHabits(userId: number, isActive?: string) {
    let q = 'SELECT * FROM progress_habits WHERE user_id=$1';
    const p: any[] = [userId];
    if (isActive !== undefined) { p.push(isActive === 'true'); q += ` AND is_active=$${p.length}`; }
    q += ' ORDER BY sort_order ASC, created_at ASC';
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async createHabit(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO progress_habits (user_id, title, category, target_type, target_count, is_active, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING *`,
      [userId, data.title, data.category||null, data.target_type||null, data.target_count||1, data.is_active??true, data.sort_order||0],
    );
    return rows[0];
  }

  async updateHabit(id: number, userId: number, data: Record<string, any>) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['title','category','target_type','target_count','is_active','sort_order'].includes(k)) {
        sets.push(`${k}=$${i++}`); vals.push(v);
      }
    }
    if (!sets.length) return null;
    vals.push(id, userId);
    // SECURITY: ownership check — AND user_id=$N
    const { rows } = await this.pool.query(`UPDATE progress_habits SET ${sets.join(',')} WHERE id=$${i} AND user_id=$${i + 1} RETURNING *`, vals);
    return rows[0];
  }

  async deleteHabit(id: number, userId: number) {
    // SECURITY: ownership check
    await this.pool.query('DELETE FROM progress_habits WHERE id=$1 AND user_id=$2', [id, userId]);
  }

  // Checkins
  async getCheckins(userId: number, startDay: string, endDay: string) {
    const { rows } = await this.pool.query(
      'SELECT * FROM progress_checkins WHERE user_id=$1 AND day >= $2 AND day <= $3 ORDER BY day ASC',
      [userId, startDay, endDay],
    );
    return rows;
  }

  async createCheckin(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO progress_checkins (user_id, habit_id, day, done_count, note)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (habit_id, day) DO UPDATE SET done_count=$4, note=$5
       RETURNING *`,
      [userId, data.habit_id, data.day, data.done_count||1, data.note||null],
    );
    return rows[0];
  }

  async deleteCheckin(habitId: number, day: string, userId: number) {
    // SECURITY: ownership check
    await this.pool.query('DELETE FROM progress_checkins WHERE habit_id=$1 AND day=$2 AND user_id=$3', [habitId, day, userId]);
  }

  // Daily Notes
  async getDailyNote(userId: number, day: string) {
    const { rows } = await this.pool.query(
      'SELECT * FROM progress_daily_notes WHERE user_id=$1 AND day=$2', [userId, day],
    );
    return rows[0] || null;
  }

  async upsertDailyNote(userId: number, data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO progress_daily_notes (user_id, day, mood, win, blocker)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (user_id, day) DO UPDATE SET mood=$3, win=$4, blocker=$5
       RETURNING *`,
      [userId, data.day, data.mood||null, data.win||null, data.blocker||null],
    );
    return rows[0];
  }

  async deleteDailyNote(userId: number, day: string) {
    await this.pool.query('DELETE FROM progress_daily_notes WHERE user_id=$1 AND day=$2', [userId, day]);
  }
}
