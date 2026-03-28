import { Controller, Get, Query, Req, Inject, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AaiService } from './aai.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AaiController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: AaiService,
  ) {}

  /** Verify user owns the release (via artist). Admin bypasses. */
  private async assertReleaseOwnership(userId: string, releaseId: number): Promise<void> {
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

  @Get('release-attention-index')
  async getIndex(@Req() req: any, @Query('release_id') releaseId: string) {
    if (!releaseId) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    await this.assertReleaseOwnership(req.user.id, +releaseId);
    return this.svc.getIndex(+releaseId);
  }

  @Get('release-clicks')
  async getClicks(@Req() req: any, @Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    await this.assertReleaseOwnership(req.user.id, +query.release_id);
    return this.svc.getClicks(query);
  }

  @Get('release-page-views')
  async getPageViews(@Req() req: any, @Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    await this.assertReleaseOwnership(req.user.id, +query.release_id);
    return this.svc.getPageViews(query);
  }

  @Get('dnk-test-aai-links')
  async getDnkLinks(@Req() req: any, @Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    await this.assertReleaseOwnership(req.user.id, +query.release_id);
    return this.svc.getDnkAaiLinks(query);
  }
}
