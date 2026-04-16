import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { CreateReleaseDto } from './dto/create-release.dto';

@Injectable()
export class ReleasesService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async create(artistId: number, dto: CreateReleaseDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO releases
        (artist_id, title, artist, release_type, cover_url, cover_path,
         release_date, status, genre, language, explicit, upc, label, copyright_year,
         description, lyrics, copyright_holders, platform_links, services, total_price,
         bpm, mood, target_audience, reference_tracks, tiktok_clip, ai_generated, wizard_step)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27)
       RETURNING *`,
      [
        artistId,
        dto.title,
        dto.artist || null,
        dto.release_type || 'single',
        dto.cover_url || null,
        dto.cover_path || null,
        dto.release_date || null,
        dto.status || 'draft',
        dto.genre || null,
        dto.language || null,
        dto.explicit ?? false,
        dto.upc || null,
        dto.label || null,
        dto.copyright_year || null,
        dto.description || null,
        dto.lyrics || null,
        dto.copyright_holders || null,
        dto.platform_links ? JSON.stringify(dto.platform_links) : '{}',
        dto.services ? JSON.stringify(dto.services) : '[]',
        dto.total_price || 0,
        dto.bpm || null,
        dto.mood || null,
        dto.target_audience || null,
        dto.reference_tracks || null,
        dto.tiktok_clip ?? false,
        dto.ai_generated ? JSON.stringify(dto.ai_generated) : '{}',
        dto.wizard_step || 0,
      ],
    );
    return rows[0];
  }

  async update(id: number, fields: Record<string, any>) {
    // SECURITY: 'status' removed — use submit/approve/live/reject endpoints for state transitions
    const allowed = [
      'title', 'artist', 'release_type', 'cover_url', 'cover_path',
      'release_date', 'genre', 'language', 'explicit', 'upc',
      'label', 'copyright_year',
      // Extended fields (v2)
      'description', 'lyrics', 'copyright_holders', 'platform_links',
      'services', 'total_price', 'bpm', 'mood', 'target_audience',
      'reference_tracks', 'tiktok_clip', 'ai_generated', 'wizard_step',
      'needs_revision', 'revision_reason',
    ];
    const jsonFields = ['platform_links', 'services', 'ai_generated'];
    const sets: string[] = [];
    const vals: any[] = [];
    let idx = 1;
    for (const key of allowed) {
      if (key in fields) {
        sets.push(`${key} = $${idx}`);
        const val = fields[key];
        vals.push(jsonFields.includes(key) && typeof val === 'object' ? JSON.stringify(val) : val);
        idx++;
      }
    }
    if (sets.length === 0) return this.findById(id);
    vals.push(id);
    const { rows } = await this.pool.query(
      `UPDATE releases SET ${sets.join(', ')} WHERE id = $${idx} RETURNING *`,
      vals,
    );
    return rows[0] || null;
  }

  async findById(id: number) {
    const { rows } = await this.pool.query(
      `SELECT r.*, a.user_id AS owner_id
       FROM releases r
       LEFT JOIN artists a ON a.id = r.artist_id
       WHERE r.id = $1`,
      [id],
    );
    return rows[0] || null;
  }

  async findByArtistId(artistId: number) {
    const { rows } = await this.pool.query(
      `SELECT r.*, a.user_id AS owner_id
       FROM releases r
       LEFT JOIN artists a ON a.id = r.artist_id
       WHERE r.artist_id = $1
       ORDER BY r.created_at DESC`,
      [artistId],
    );
    return rows;
  }

  async findByStatus(status: string) {
    const { rows } = await this.pool.query(
      `SELECT r.*, a.artist_name, a.user_id AS owner_id
       FROM releases r
       JOIN artists a ON a.id = r.artist_id
       WHERE r.status = $1
       ORDER BY r.submitted_at ASC`,
      [status],
    );
    return rows;
  }

  async findAll() {
    const { rows } = await this.pool.query(
      `SELECT r.*, a.artist_name, a.user_id AS owner_id
       FROM releases r
       JOIN artists a ON a.id = r.artist_id
       ORDER BY r.created_at DESC`,
    );
    return rows;
  }

  async submit(id: number) {
    const { rows } = await this.pool.query(
      `UPDATE releases
       SET status = 'review', submitted_at = NOW()
       WHERE id = $1 AND status = 'draft'
       RETURNING *`,
      [id],
    );
    return rows[0] || null;
  }

  async approve(id: number) {
    const { rows } = await this.pool.query(
      `UPDATE releases
       SET status = 'approved', approved_at = NOW()
       WHERE id = $1 AND status IN ('review', 'submitted', 'in_review')
       RETURNING *`,
      [id],
    );
    return rows[0] || null;
  }

  async markLive(id: number) {
    const { rows } = await this.pool.query(
      `UPDATE releases
       SET status = 'live', live_at = NOW()
       WHERE id = $1 AND status = 'approved'
       RETURNING *`,
      [id],
    );
    return rows[0] || null;
  }

  async reject(id: number, reason?: string) {
    const { rows } = await this.pool.query(
      `UPDATE releases
       SET status = 'rejected', reject_reason = $2
       WHERE id = $1 AND status IN ('review', 'submitted', 'in_review')
       RETURNING *`,
      [id, reason || null],
    );
    return rows[0] || null;
  }

  /** Admin-only: force a status value (used by bulk-status). */
  async updateStatus(id: number, status: string) {
    const allowed = ['draft', 'review', 'approved', 'live', 'rejected', 'takedown'];
    if (!allowed.includes(status)) return null;
    const { rows } = await this.pool.query(
      `UPDATE releases SET status = $2 WHERE id = $1 RETURNING *`,
      [id, status],
    );
    return rows[0] || null;
  }

  async deleteRelease(id: number) {
    const { rowCount } = await this.pool.query(
      `DELETE FROM releases WHERE id = $1`,
      [id],
    );
    return (rowCount ?? 0) > 0;
  }
}
