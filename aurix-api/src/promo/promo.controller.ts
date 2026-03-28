import { Controller, Get, Post, Put, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { PromoService } from './promo.service';
import { PromoVideoService } from './promo-video.service';
import { GenerateVideoDto } from './dto/generate-video.dto';

@UseGuards(JwtAuthGuard)
@Controller()
export class PromoController {
  constructor(
    private readonly svc: PromoService,
    private readonly videoSvc: PromoVideoService,
  ) {}

  /** Check admin role from DB (not JWT). */
  private async isAdmin(userId: number): Promise<boolean> {
    const r = await this.svc['pool']?.query?.('SELECT role FROM users WHERE id = $1', [userId]).catch(() => ({ rows: [] }));
    return r?.rows?.[0]?.role === 'admin';
  }

  // User: list own promo requests. Admin: list all.
  @Get('promo-requests')
  async list(@Req() req: any) {
    // SECURITY: check admin from DB, not JWT (JWT role can be stale)
    if (await this.isAdmin(req.user.id)) {
      return this.svc.list({});
    }
    return this.svc.list({ user_id: req.user.id });
  }

  // Admin: list with filters
  @UseGuards(AdminGuard)
  @Get('promo-requests/all')
  async listAll(@Query() query: Record<string, any>) { return this.svc.list(query); }

  // User creates promo request — user_id always from JWT
  @Post('promo-requests')
  async create(@Req() req: any, @Body() body: Record<string, any>) {
    if (!body.type) throw new HttpException('type required', HttpStatus.BAD_REQUEST);
    return this.svc.create({ ...body, user_id: req.user.id });
  }

  // Admin only: update promo request status
  @UseGuards(AdminGuard)
  @Put('promo-requests/:id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const r = await this.svc.update(+id, body);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Get('promo-events')
  async getEvents(@Req() req: any, @Query('promo_request_id') promoRequestId: string) {
    if (!promoRequestId) throw new HttpException('promo_request_id required', HttpStatus.BAD_REQUEST);
    const promoRequest = await this.svc.findById(+promoRequestId);
    if (!promoRequest) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    const isAdminUser = await this.isAdmin(req.user.id);
    if (!isAdminUser && promoRequest.user_id !== req.user.id) {
      throw new HttpException('forbidden', HttpStatus.FORBIDDEN);
    }
    return this.svc.getEvents(+promoRequestId);
  }

  @UseGuards(AdminGuard)
  @Post('promo-events')
  async addEvent(@Body() body: Record<string, any>) {
    return this.svc.addEvent(body);
  }

  // ── Promo Video Generator ─────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 3 } })
  @Post('promo/generate-video')
  async generateVideo(@Req() req: any, @Body() body: GenerateVideoDto) {
    return this.videoSvc.generateVideo({
      trackId: body.trackId,
      startTime: body.startTime,
      duration: body.duration,
      style: body.style,
      userId: req.user.id,
    });
  }
}
