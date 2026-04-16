import { Controller, Get, Post, Put, Delete, Body, Param, Query, Req, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { BeatsService } from './beats.service';

@Controller('beats')
export class BeatsController {
  constructor(private readonly beats: BeatsService) {}

  // ── Public: browse beats ──────────────────────────────
  @Get()
  async list(
    @Query('genre') genre?: string,
    @Query('mood') mood?: string,
    @Query('bpm_min') bpmMin?: string,
    @Query('bpm_max') bpmMax?: string,
    @Query('search') search?: string,
    @Query('limit') limit?: string,
    @Query('offset') offset?: string,
  ) {
    const beats = await this.beats.findAll({
      genre, mood,
      bpmMin: bpmMin ? +bpmMin : undefined,
      bpmMax: bpmMax ? +bpmMax : undefined,
      search, limit: limit ? +limit : 20, offset: offset ? +offset : 0,
    });
    return { success: true, beats };
  }

  @Get(':id')
  async getOne(@Param('id') id: string) {
    const beat = await this.beats.findById(+id);
    if (!beat) throw new HttpException('Beat not found', HttpStatus.NOT_FOUND);
    return { success: true, beat };
  }

  // ── Auth: manage my beats ─────────────────────────────
  @UseGuards(JwtAuthGuard)
  @Get('my/list')
  async myBeats(@Req() req: any) {
    const beats = await this.beats.findBySeller(req.user.id);
    return { success: true, beats };
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  async create(@Req() req: any, @Body() dto: any) {
    if (!dto.title || !dto.audio_url) {
      throw new HttpException('title and audio_url are required', HttpStatus.BAD_REQUEST);
    }
    const beat = await this.beats.create(req.user.id, dto);
    return { success: true, beat };
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  async update(@Req() req: any, @Param('id') id: string, @Body() body: any) {
    const beat = await this.beats.findById(+id);
    if (!beat) throw new HttpException('Beat not found', HttpStatus.NOT_FOUND);
    if (beat.seller_id !== req.user.id) throw new HttpException('Not your beat', HttpStatus.FORBIDDEN);
    const updated = await this.beats.update(+id, body);
    return { success: true, beat: updated };
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  async remove(@Req() req: any, @Param('id') id: string) {
    const beat = await this.beats.findById(+id);
    if (!beat) throw new HttpException('Beat not found', HttpStatus.NOT_FOUND);
    if (beat.seller_id !== req.user.id) throw new HttpException('Not your beat', HttpStatus.FORBIDDEN);
    await this.beats.delete(+id);
    return { success: true };
  }

  // ── Interactions ───────────────────────────────────────
  @UseGuards(JwtAuthGuard)
  @Post(':id/play')
  async play(@Param('id') id: string) {
    await this.beats.incrementPlays(+id);
    return { success: true };
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/like')
  async like(@Req() req: any, @Param('id') id: string) {
    const liked = await this.beats.toggleLike(+id, req.user.id);
    return { success: true, liked };
  }

  @UseGuards(JwtAuthGuard)
  @Post(':id/purchase')
  async purchase(@Req() req: any, @Param('id') id: string, @Body() body: { license_type: string }) {
    if (!body.license_type || !['lease', 'unlimited', 'exclusive'].includes(body.license_type)) {
      throw new HttpException('Invalid license type', HttpStatus.BAD_REQUEST);
    }
    try {
      const purchase = await this.beats.purchase(+id, req.user.id, body.license_type);
      return { success: true, purchase };
    } catch (e: any) {
      throw new HttpException(e.message, HttpStatus.BAD_REQUEST);
    }
  }

  // ── Admin: list all beats (including pending) ──────────
  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin/all')
  async adminList() {
    return { success: true, beats: await this.beats.adminFindAll() };
  }

  // ── Admin: approve beat ────────────────────────────────
  @UseGuards(JwtAuthGuard, AdminGuard)
  @Post(':id/approve')
  async adminApprove(@Param('id') id: string) {
    await this.beats.adminSetStatus(+id, 'active');
    return { success: true };
  }

  // ── Admin: reject beat ─────────────────────────────────
  @UseGuards(JwtAuthGuard, AdminGuard)
  @Post(':id/reject-beat')
  async adminReject(@Param('id') id: string, @Body() body: { reason?: string }) {
    await this.beats.adminSetStatus(+id, 'rejected', body.reason);
    return { success: true };
  }
}
