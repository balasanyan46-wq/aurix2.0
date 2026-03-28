import {
  Controller,
  Post,
  Get,
  Body,
  Param,
  Req,
  UseGuards,
  HttpException,
  HttpStatus,
  Inject,
} from '@nestjs/common';
import { Pool } from 'pg';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReleaseMetadataService } from './release-metadata.service';
import { ReleasesService } from '../releases/releases.service';
import { ArtistsService } from '../artists/artists.service';
import { UpsertMetadataDto } from './dto/upsert-metadata.dto';
import { PG_POOL } from '../database/database.module';

@UseGuards(JwtAuthGuard)
@Controller('releases')
export class ReleaseMetadataController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly metadataService: ReleaseMetadataService,
    private readonly releasesService: ReleasesService,
    private readonly artistsService: ArtistsService,
  ) {}

  @Post(':id/metadata')
  async upsert(
    @Req() req: any,
    @Param('id') id: string,
    @Body() dto: UpsertMetadataDto,
  ) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    const { rows: userRows } = await this.pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
    if (userRows[0]?.role !== 'admin') {
      const artist = await this.artistsService.findByUserId(req.user.id);
      if (!artist || release.artist_id !== artist.id) {
        throw new HttpException('not your release', HttpStatus.FORBIDDEN);
      }
    }

    const metadata = await this.metadataService.upsert(releaseId, dto);
    return { success: true, metadata };
  }

  @Get(':id/metadata')
  async get(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    const { rows: userRows } = await this.pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
    if (userRows[0]?.role !== 'admin') {
      const artist = await this.artistsService.findByUserId(req.user.id);
      if (!artist || release.artist_id !== artist.id) {
        throw new HttpException('not your release', HttpStatus.FORBIDDEN);
      }
    }

    const metadata = await this.metadataService.findByReleaseId(releaseId);
    return { success: true, metadata };
  }
}
