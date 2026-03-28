import { Controller, Get, Post, Put, Body, Param, Query, Req, Inject, UseGuards } from '@nestjs/common';
// @ts-ignore — Req imported for auth user extraction
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { NavigatorService } from './navigator.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class NavigatorController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: NavigatorService,
  ) {}

  @Get('artist-navigator-materials')
  async getMaterials() { return this.svc.getMaterials(); }

  @Get('artist-navigator-materials/by-slug/:slug')
  async getBySlug(@Param('slug') slug: string) { return this.svc.getMaterialBySlug(slug); }

  @Post('artist-navigator-materials/upsert')
  @UseGuards(AdminGuard)
  async upsertMaterial(@Body() body: Record<string, any>) {
    if (body.id) {
      const { rows } = await this.pool.query(
        `UPDATE artist_navigator_materials SET title=$1, description=$2, category=$3, cluster=$4, body_markdown=$5, is_published=$6, sort_order=$7, slug=$8, updated_at=NOW()
         WHERE id=$9 RETURNING *`,
        [body.title, body.description||null, body.category||null, body.cluster||null, body.body_markdown||null, body.is_published??true, body.sort_order||0, body.slug, body.id],
      );
      return rows[0];
    }
    const { rows } = await this.pool.query(
      `INSERT INTO artist_navigator_materials (slug, title, description, category, cluster, body_markdown, is_published, sort_order)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [body.slug, body.title, body.description||null, body.category||null, body.cluster||null, body.body_markdown||null, body.is_published??true, body.sort_order||0],
    );
    return rows[0];
  }

  @Get('artist-navigator-user-materials')
  async getUserMaterials(@Req() req: any, @Query('is_saved') isSaved?: string, @Query('is_completed') isCompleted?: string) {
    // SECURITY: always use authenticated user's ID, not query param
    return this.svc.getUserMaterials(req.user.id, isSaved, isCompleted);
  }

  @Get('artist-navigator-user-materials/item')
  async getUserMaterialItem(@Req() req: any, @Query('material_id') materialId: string) {
    return this.svc.getUserMaterialItem(req.user.id, +materialId);
  }

  @Post('artist-navigator-user-materials')
  async createUserMaterial(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.createUserMaterial({ ...body, user_id: req.user.id });
  }

  @Put('artist-navigator-user-materials/:id')
  async updateUserMaterial(@Req() req: any, @Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateUserMaterial(+id, body, req.user.id);
  }

  @Post('artist-navigator-profiles')
  async saveProfile(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.saveProfile(req.user.id, body.onboarding_answers);
  }

  @Get('artist-navigator-profiles/me')
  async getMyProfile(@Req() req: any) { return this.svc.getProfile(req.user.id); }

  @Get('artist-navigator-profiles/:userId')
  @UseGuards(AdminGuard)
  async getProfile(@Param('userId') userId: string) { return this.svc.getProfile(+userId); }

}
