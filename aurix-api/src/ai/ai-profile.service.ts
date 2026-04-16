import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export interface AiProfile {
  user_id: number;
  name: string;
  genre: string;
  mood: string;
  references_list: string[];
  goals: string[];
  style_description: string;
  created_at: string;
  updated_at: string;
}

@Injectable()
export class AiProfileService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async get(userId: number): Promise<AiProfile | null> {
    const { rows } = await this.pool.query(
      'SELECT * FROM user_ai_profiles WHERE user_id = $1',
      [userId],
    );
    return rows[0] || null;
  }

  async upsert(
    userId: number,
    data: {
      name?: string;
      genre?: string;
      mood?: string;
      references_list?: string[];
      goals?: string[];
      style_description?: string;
      goal?: string;
    },
  ): Promise<AiProfile> {
    const { rows } = await this.pool.query(
      `INSERT INTO user_ai_profiles (user_id, name, genre, mood, references_list, goals, style_description, goal)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (user_id) DO UPDATE SET
         name = COALESCE(EXCLUDED.name, user_ai_profiles.name),
         genre = COALESCE(EXCLUDED.genre, user_ai_profiles.genre),
         mood = COALESCE(EXCLUDED.mood, user_ai_profiles.mood),
         references_list = COALESCE(EXCLUDED.references_list, user_ai_profiles.references_list),
         goals = COALESCE(EXCLUDED.goals, user_ai_profiles.goals),
         style_description = COALESCE(EXCLUDED.style_description, user_ai_profiles.style_description),
         goal = COALESCE(EXCLUDED.goal, user_ai_profiles.goal),
         updated_at = now()
       RETURNING *`,
      [
        userId,
        data.name ?? '',
        data.genre ?? '',
        data.mood ?? '',
        data.references_list ?? [],
        data.goals ?? [],
        data.style_description ?? '',
        data.goal ?? '',
      ],
    );
    return rows[0];
  }

  /** Build context block for AI system prompts. */
  toPrompt(profile: AiProfile | null): string {
    if (!profile) return '';
    const parts: string[] = [];
    if (profile.name) parts.push(`Артист: ${profile.name}`);
    if (profile.genre) parts.push(`Жанр: ${profile.genre}`);
    if (profile.mood) parts.push(`Настроение: ${profile.mood}`);
    if (profile.references_list?.length) parts.push(`Референсы: ${profile.references_list.join(', ')}`);
    if (profile.goals?.length) parts.push(`Цели: ${profile.goals.join(', ')}`);
    if (profile.style_description) parts.push(`Стиль: ${profile.style_description}`);
    if (parts.length === 0) return '';
    return `\n\nПрофиль артиста:\n${parts.join('\n')}`;
  }
}
