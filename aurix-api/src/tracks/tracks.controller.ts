import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Body,
  Param,
  Query,
  Req,
  Inject,
  UseGuards,
  HttpException,
  HttpStatus,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { TracksService } from './tracks.service';
import { ReportsService } from '../reports/reports.service';
import { CreateTrackDto } from './dto/create-track.dto';

@UseGuards(JwtAuthGuard)
@Controller('tracks')
export class TracksController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly tracksService: TracksService,
    private readonly reportsService: ReportsService,
  ) {}

  /** Verify user owns the release that contains this track (admin bypasses). */
  private async assertReleaseOwnership(userId: string, releaseId: number): Promise<void> {
    // Admin bypass
    const { rows: userRows } = await this.pool.query('SELECT role FROM users WHERE id = $1', [userId]);
    if (userRows[0]?.role === 'admin') return;

    const { rows } = await this.pool.query(
      `SELECT r.id FROM releases r
       JOIN artists a ON a.id = r.artist_id
       WHERE r.id = $1 AND a.user_id = $2`,
      [releaseId, userId],
    );
    if (rows.length === 0) {
      throw new HttpException('not your release', HttpStatus.FORBIDDEN);
    }
  }

  @Post()
  async create(@Req() req: any, @Body() dto: CreateTrackDto) {
    if (!dto.release_id) {
      throw new HttpException(
        'release_id is required',
        HttpStatus.BAD_REQUEST,
      );
    }

    await this.assertReleaseOwnership(req.user.id, dto.release_id);

    const track = await this.tracksService.create(dto);
    return { success: true, track };
  }

  @Get('release/:id')
  async getByRelease(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    await this.assertReleaseOwnership(req.user.id, releaseId);

    const tracks = await this.tracksService.findByReleaseId(releaseId);
    return { success: true, tracks };
  }

  @Get('my')
  async getMyTracks(@Req() req: any) {
    const tracks = await this.tracksService.findByUserId(req.user.id);
    return { success: true, tracks };
  }

  @Get()
  async search(@Req() req: any, @Query('isrc') isrc?: string) {
    if (isrc) {
      // SECURITY: scope ISRC search to the requesting user's tracks only
      const tracks = await this.tracksService.findByIsrcForUser(isrc, req.user.id);
      return tracks;
    }
    return [];
  }

  // ВАЖНО: эта точка должна быть ДО @Get(':id'), иначе NestJS интерпретирует
  // "by-user" как параметр id и улетает в getOne() с NaN → 404.
  @Get('by-user/:userId')
  @UseGuards(AdminGuard)
  async tracksByUser(@Param('userId') userId: string) {
    return this.reportsService.getTracksByUser(userId);
  }

  @Get(':id')
  async getOne(@Req() req: any, @Param('id') id: string) {
    const track = await this.tracksService.findById(+id);
    if (!track) throw new HttpException('track not found', HttpStatus.NOT_FOUND);

    await this.assertReleaseOwnership(req.user.id, track.release_id);

    return { success: true, track };
  }

  @Put(':id')
  async update(@Req() req: any, @Param('id') id: string, @Body() body: Record<string, any>) {
    const track = await this.tracksService.findById(+id);
    if (!track) throw new HttpException('track not found', HttpStatus.NOT_FOUND);

    await this.assertReleaseOwnership(req.user.id, track.release_id);

    const updated = await this.tracksService.update(+id, body);
    return { success: true, track: updated };
  }

  @Delete(':id')
  async remove(@Req() req: any, @Param('id') id: string) {
    const track = await this.tracksService.findById(+id);
    if (!track) throw new HttpException('track not found', HttpStatus.NOT_FOUND);

    await this.assertReleaseOwnership(req.user.id, track.release_id);

    await this.tracksService.delete(+id);
    return { success: true };
  }
}
