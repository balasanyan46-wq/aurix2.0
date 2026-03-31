import {
  Controller,
  Post,
  Get,
  Put,
  Delete,
  Body,
  Param,
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
import { ReleasesService } from './releases.service';
import { ArtistsService } from '../artists/artists.service';
import { UsersService } from '../users/users.service';
import { MailService } from '../mail/mail.service';
import { CreateReleaseDto } from './dto/create-release.dto';
import { RejectReleaseDto } from './dto/reject-release.dto';
import { UserEventsService } from '../user-events/user-events.service';
import { NotificationsService } from '../notifications/notifications.service';

@UseGuards(JwtAuthGuard)
@Controller('releases')
export class ReleasesController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly releasesService: ReleasesService,
    private readonly artistsService: ArtistsService,
    private readonly usersService: UsersService,
    private readonly mailService: MailService,
    private readonly events: UserEventsService,
    private readonly notifications: NotificationsService,
  ) {}

  /** Verify that the logged-in user owns the release (or is admin). */
  private async assertOwnership(req: any, release: any): Promise<void> {
    // Check admin from DB (JWT role may be stale)
    const { rows } = await this.pool.query('SELECT role FROM users WHERE id = $1', [req.user.id]);
    if (rows[0]?.role === 'admin') return;
    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist || release.artist_id !== artist.id) {
      throw new HttpException('not your release', HttpStatus.FORBIDDEN);
    }
  }

  // ── Create release ─────────────────────────────────────
  @Post()
  async create(@Req() req: any, @Body() dto: CreateReleaseDto) {
    if (!dto.title) {
      throw new HttpException('title is required', HttpStatus.BAD_REQUEST);
    }

    // Auto-create artist profile if missing
    let artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist) {
      artist = await this.artistsService.create(req.user.id, {
        artist_name: dto.artist || req.user.name || 'Artist',
      });
    }

    const release = await this.releasesService.create(artist.id, dto);
    this.events.log({ user_id: req.user.id, event: 'release_created', target_type: 'release', target_id: String(release.id), meta: { title: dto.title } }).catch(() => {});
    return { success: true, release };
  }

  // ── Get my releases ────────────────────────────────────
  @Get('my')
  async getMy(@Req() req: any) {
    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist) {
      return { success: true, releases: [] };
    }

    const releases = await this.releasesService.findByArtistId(artist.id);
    return { success: true, releases };
  }

  // ── Admin: list all releases ───────────────────────────
  @UseGuards(AdminGuard)
  @Get()
  async getAll() {
    const releases = await this.releasesService.findAll();
    return { success: true, releases };
  }

  // ── Admin: list releases pending review ────────────────
  @UseGuards(AdminGuard)
  @Get('review')
  async getReview() {
    const releases = await this.releasesService.findByStatus('review');
    return { success: true, releases };
  }

  // ── Get single release (must be AFTER specific GET routes) ──
  @Get(':id')
  async getOne(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    // Ownership check
    await this.assertOwnership(req, release);

    return { success: true, release };
  }

  // ── Update release ─────────────────────────────────────
  @Put(':id')
  async update(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: Record<string, any>,
  ) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    await this.assertOwnership(req, release);

    const updated = await this.releasesService.update(releaseId, body);
    console.log(`[Releases] PUT ${id} by user ${req.user.id} (role: ${req.user.role}) → fields: ${Object.keys(body).join(', ')}`);
    return { success: true, release: updated };
  }

  // ── Delete release ─────────────────────────────────────
  @Delete(':id')
  async remove(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    await this.assertOwnership(req, release);

    await this.releasesService.deleteRelease(releaseId);
    return { success: true };
  }

  // ── Submit draft for review ────────────────────────────
  @Post(':id/submit')
  async submit(@Req() req: any, @Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const release = await this.releasesService.findById(releaseId);
    if (!release) {
      throw new HttpException('release not found', HttpStatus.NOT_FOUND);
    }

    const artist = await this.artistsService.findByUserId(req.user.id);
    if (!artist || release.artist_id !== artist.id) {
      throw new HttpException('not your release', HttpStatus.FORBIDDEN);
    }

    if (release.status !== 'draft') {
      throw new HttpException(
        'release cannot be submitted in its current state',
        HttpStatus.CONFLICT,
      );
    }

    const updated = await this.releasesService.submit(releaseId);
    this.events.log({ user_id: req.user.id, event: 'release_submitted', target_type: 'release', target_id: String(releaseId) }).catch(() => {});
    return { success: true, status: updated.status };
  }

  // ── Admin: approve release ─────────────────────────────
  @UseGuards(AdminGuard)
  @Post(':id/approve')
  async approve(@Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const updated = await this.releasesService.approve(releaseId);
    if (!updated) {
      throw new HttpException(
        'release not found or not in review status',
        HttpStatus.CONFLICT,
      );
    }

    this.notifyArtist(updated.artist_id, updated.title, 'approved').catch(() => {});
    this.sendReleaseNotification(updated.artist_id, updated.title, 'approved').catch(() => {});
    return { success: true, status: updated.status };
  }

  // ── Admin: mark release as live ────────────────────────
  @UseGuards(AdminGuard)
  @Post(':id/live')
  async markLive(@Param('id') id: string) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const updated = await this.releasesService.markLive(releaseId);
    if (!updated) {
      throw new HttpException(
        'release not found or not in approved status',
        HttpStatus.CONFLICT,
      );
    }

    this.notifyArtist(updated.artist_id, updated.title, 'live').catch(() => {});
    this.sendReleaseNotification(updated.artist_id, updated.title, 'live').catch(() => {});
    return { success: true, status: updated.status };
  }

  // ── Admin: reject release ──────────────────────────────
  @UseGuards(AdminGuard)
  @Post(':id/reject')
  async reject(@Param('id') id: string, @Body() dto: RejectReleaseDto) {
    const releaseId = parseInt(id, 10);
    if (isNaN(releaseId)) {
      throw new HttpException('invalid release id', HttpStatus.BAD_REQUEST);
    }

    const updated = await this.releasesService.reject(releaseId, dto.reason);
    if (!updated) {
      throw new HttpException(
        'release not found or not in review status',
        HttpStatus.CONFLICT,
      );
    }

    this.sendReleaseNotification(updated.artist_id, updated.title, 'rejected', dto.reason).catch(() => {});
    return { success: true, status: updated.status };
  }

  // ── Release notes (admin) ───────────────────────────────
  @UseGuards(AdminGuard)
  @Get(':id/notes')
  async getNotes(@Param('id') id: string) {
    const { rows } = await this.pool.query(
      'SELECT * FROM release_notes WHERE release_id = $1 ORDER BY created_at DESC',
      [+id],
    );
    return rows;
  }

  @UseGuards(AdminGuard)
  @Post(':id/notes')
  async addNote(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { body: string },
  ) {
    const { rows } = await this.pool.query(
      'INSERT INTO release_notes (release_id, admin_id, body) VALUES ($1,$2,$3) RETURNING *',
      [+id, req.user.id, body.body],
    );
    return rows[0];
  }

  // ── Bulk status update (admin) ─────────────────────────
  @UseGuards(AdminGuard)
  @Post('bulk-status')
  async bulkStatus(
    @Body() body: { release_ids: number[]; status: string },
  ) {
    let updated = 0;
    for (const rid of body.release_ids) {
      const r = await this.releasesService.updateStatus(rid, body.status);
      if (r) updated++;
    }
    return { success: true, updated };
  }

  /** Send in-app notification about release status change */
  private async sendReleaseNotification(
    artistId: number,
    releaseTitle: string,
    status: 'approved' | 'live' | 'rejected',
    reason?: string,
  ) {
    const artist = await this.artistsService.findById(artistId);
    if (!artist) return;

    const messages: Record<string, { title: string; message: string; type: string }> = {
      approved: {
        title: 'Релиз одобрен',
        message: `Ваш релиз «${releaseTitle}» прошёл модерацию и одобрен`,
        type: 'success',
      },
      live: {
        title: 'Релиз опубликован!',
        message: `Ваш релиз «${releaseTitle}» успешно отгружен на площадки`,
        type: 'success',
      },
      rejected: {
        title: 'Релиз отклонён',
        message: `Ваш релиз «${releaseTitle}» отклонён${reason ? `: ${reason}` : ''}`,
        type: 'warning',
      },
    };

    const msg = messages[status];
    await this.notifications.send({
      user_id: artist.user_id,
      title: msg.title,
      message: msg.message,
      type: msg.type,
      meta: { release_title: releaseTitle, status },
    });
  }

  /** Look up artist → user → send email */
  private async notifyArtist(
    artistId: number,
    releaseTitle: string,
    type: 'approved' | 'live',
  ) {
    const artist = await this.artistsService.findById(artistId);
    if (!artist) return;
    const user = await this.usersService.findById(artist.user_id);
    if (!user) return;

    if (type === 'approved') {
      await this.mailService.sendReleaseApproved(
        user.email,
        artist.artist_name,
        releaseTitle,
      );
    } else {
      await this.mailService.sendReleaseLive(
        user.email,
        artist.artist_name,
        releaseTitle,
      );
    }
  }
}
