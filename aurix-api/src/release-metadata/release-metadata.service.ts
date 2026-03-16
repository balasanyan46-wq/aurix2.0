import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { UpsertMetadataDto } from './dto/upsert-metadata.dto';

@Injectable()
export class ReleaseMetadataService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async upsert(releaseId: number, dto: UpsertMetadataDto) {
    const { rows } = await this.pool.query(
      `INSERT INTO release_metadata
         (release_id, genre, language, explicit, copyright, publisher, label, release_type, upc)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
       ON CONFLICT (release_id) DO UPDATE SET
         genre      = COALESCE(EXCLUDED.genre, release_metadata.genre),
         language   = COALESCE(EXCLUDED.language, release_metadata.language),
         explicit   = COALESCE(EXCLUDED.explicit, release_metadata.explicit),
         copyright  = COALESCE(EXCLUDED.copyright, release_metadata.copyright),
         publisher  = COALESCE(EXCLUDED.publisher, release_metadata.publisher),
         label      = COALESCE(EXCLUDED.label, release_metadata.label),
         release_type = COALESCE(EXCLUDED.release_type, release_metadata.release_type),
         upc        = COALESCE(EXCLUDED.upc, release_metadata.upc)
       RETURNING *`,
      [
        releaseId,
        dto.genre ?? null,
        dto.language ?? null,
        dto.explicit ?? false,
        dto.copyright ?? null,
        dto.publisher ?? null,
        dto.label ?? null,
        dto.release_type ?? 'single',
        dto.upc ?? null,
      ],
    );
    return rows[0];
  }

  async findByReleaseId(releaseId: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM release_metadata WHERE release_id = $1`,
      [releaseId],
    );
    return rows[0] || null;
  }
}
