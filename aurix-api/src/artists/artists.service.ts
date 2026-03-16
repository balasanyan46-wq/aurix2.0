import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { CreateArtistDto } from './dto/create-artist.dto';

@Injectable()
export class ArtistsService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async create(userId: number, dto: CreateArtistDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO artists (user_id, artist_name, bio, avatar_url)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [userId, dto.artist_name, dto.bio || null, dto.avatar_url || null],
    );
    return rows[0];
  }

  async findById(id: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM artists WHERE id = $1`,
      [id],
    );
    return rows[0] || null;
  }

  async findByUserId(userId: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM artists WHERE user_id = $1`,
      [userId],
    );
    return rows[0] || null;
  }
}
