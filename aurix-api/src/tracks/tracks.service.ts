import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { CreateTrackDto } from './dto/create-track.dto';

@Injectable()
export class TracksService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async create(dto: CreateTrackDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO tracks (release_id, title, audio_url, duration, isrc, track_number, version, explicit)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        dto.release_id,
        dto.title || null,
        dto.audio_url || null,
        dto.duration || null,
        dto.isrc || null,
        dto.track_number || null,
        dto.version || 'original',
        dto.explicit ?? false,
      ],
    );
    return rows[0];
  }

  async findByUserId(userId: number) {
    const { rows } = await this.pool.query(
      `SELECT t.*, r.title AS release_title, r.cover_url, r.artist
       FROM tracks t
       JOIN releases r ON r.id = t.release_id
       JOIN artists a ON a.id = r.artist_id
       WHERE a.user_id = $1
       ORDER BY t.created_at DESC`,
      [userId],
    );
    return rows;
  }

  async findByReleaseId(releaseId: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM tracks WHERE release_id = $1 ORDER BY track_number ASC, id ASC`,
      [releaseId],
    );
    return rows;
  }

  async findById(id: number) {
    const { rows } = await this.pool.query('SELECT * FROM tracks WHERE id = $1', [id]);
    return rows[0] || null;
  }

  async findByIsrc(isrc: string) {
    const { rows } = await this.pool.query('SELECT * FROM tracks WHERE isrc = $1', [isrc]);
    return rows;
  }

  /** ISRC search scoped to the requesting user's releases. */
  async findByIsrcForUser(isrc: string, userId: number) {
    const { rows } = await this.pool.query(
      `SELECT t.* FROM tracks t
       JOIN releases r ON r.id = t.release_id
       JOIN artists a ON a.id = r.artist_id
       WHERE t.isrc = $1 AND a.user_id = $2`,
      [isrc, userId],
    );
    return rows;
  }

  async update(id: number, data: Record<string, any>) {
    const allowed = ['title', 'isrc', 'track_number', 'version', 'explicit', 'audio_url', 'duration'];
    const sets: string[] = [];
    const vals: any[] = [];
    let i = 1;
    for (const [k, v] of Object.entries(data)) {
      if (allowed.includes(k)) {
        sets.push(`${k} = $${i++}`);
        vals.push(v);
      }
    }
    if (!sets.length) return this.findById(id);
    vals.push(id);
    const { rows } = await this.pool.query(
      `UPDATE tracks SET ${sets.join(', ')} WHERE id = $${i} RETURNING *`,
      vals,
    );
    return rows[0] || null;
  }

  async delete(id: number) {
    await this.pool.query('DELETE FROM tracks WHERE id = $1', [id]);
  }
}
