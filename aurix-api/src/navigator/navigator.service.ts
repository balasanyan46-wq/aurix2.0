import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

@Injectable()
export class NavigatorService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async getMaterials() {
    const { rows } = await this.pool.query('SELECT * FROM artist_navigator_materials WHERE is_published=true ORDER BY sort_order ASC');
    return rows;
  }

  async getMaterialBySlug(slug: string) {
    const { rows } = await this.pool.query('SELECT * FROM artist_navigator_materials WHERE slug=$1', [slug]);
    return rows[0] || null;
  }

  async getUserMaterials(userId: number, isSaved?: string, isCompleted?: string) {
    let q = 'SELECT * FROM artist_navigator_user_materials WHERE user_id=$1';
    const p: any[] = [userId];
    if (isSaved !== undefined) { p.push(isSaved === 'true'); q += ` AND is_saved=$${p.length}`; }
    if (isCompleted !== undefined) { p.push(isCompleted === 'true'); q += ` AND is_completed=$${p.length}`; }
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  async getUserMaterialItem(userId: number, materialId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM artist_navigator_user_materials WHERE user_id=$1 AND material_id=$2', [userId, materialId],
    );
    return rows[0] || null;
  }

  async createUserMaterial(data: Record<string, any>) {
    const { rows } = await this.pool.query(
      `INSERT INTO artist_navigator_user_materials (user_id, material_id, is_saved, is_completed, progress_percent)
       VALUES ($1,$2,$3,$4,$5)
       ON CONFLICT (user_id, material_id) DO UPDATE SET is_saved=$3, is_completed=$4, progress_percent=$5, updated_at=NOW()
       RETURNING *`,
      [data.user_id, data.material_id, data.is_saved??false, data.is_completed??false, data.progress_percent||0],
    );
    return rows[0];
  }

  async updateUserMaterial(id: number, data: Record<string, any>, userId: number) {
    const sets: string[] = []; const vals: any[] = []; let i = 1;
    for (const [k,v] of Object.entries(data)) {
      if (['is_saved','is_completed','progress_percent'].includes(k)) { sets.push(`${k}=$${i++}`); vals.push(v); }
    }
    if (!sets.length) return null;
    sets.push('updated_at=NOW()');
    vals.push(id);
    vals.push(userId);
    const { rows } = await this.pool.query(`UPDATE artist_navigator_user_materials SET ${sets.join(',')} WHERE id=$${i} AND user_id=$${i+1} RETURNING *`, vals);
    return rows[0];
  }

  async saveProfile(userId: number, onboardingAnswers: any) {
    const { rows } = await this.pool.query(
      `INSERT INTO artist_navigator_profiles (user_id, onboarding_answers, updated_at)
       VALUES ($1,$2,NOW())
       ON CONFLICT (user_id) DO UPDATE SET onboarding_answers=$2, updated_at=NOW()
       RETURNING *`,
      [userId, JSON.stringify(onboardingAnswers)],
    );
    return rows[0];
  }

  async getProfile(userId: number) {
    const { rows } = await this.pool.query('SELECT * FROM artist_navigator_profiles WHERE user_id=$1', [userId]);
    return rows[0] || null;
  }
}
