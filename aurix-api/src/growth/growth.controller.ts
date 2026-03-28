import {
  Controller, Get, Post, Put, Body, Query, Req, Param, UseGuards, HttpException, HttpStatus,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { GrowthService } from './growth.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class GrowthController {
  constructor(private readonly growth: GrowthService) {}

  // ── USER: XP & Level ────────────────────────────────────

  @Get('growth/me')
  async myState(@Req() req: any) {
    const [xp, streak, goals, achievements] = await Promise.all([
      this.growth.getXpState(req.user.id),
      this.growth.getStreak(req.user.id),
      this.growth.getUserGoals(req.user.id),
      this.growth.getUserAchievements(req.user.id),
    ]);
    return { xp, streak, goals, achievements };
  }

  @Get('growth/xp')
  async myXp(@Req() req: any) {
    return this.growth.getXpState(req.user.id);
  }

  @Get('growth/xp-log')
  async myXpLog(@Req() req: any) {
    return this.growth.getXpLog(req.user.id);
  }

  @Get('growth/streak')
  async myStreak(@Req() req: any) {
    return this.growth.getStreak(req.user.id);
  }

  @Post('growth/checkin')
  async checkin(@Req() req: any) {
    const streak = await this.growth.updateStreak(req.user.id);
    let xpResult: any = null;
    if (streak.isNew) {
      xpResult = await this.growth.grantActionXp(req.user.id, 'daily_login');
      // Check streak achievements
      await this.growth.checkAchievements(req.user.id, 'login');
    }
    return { streak, xp: xpResult };
  }

  // ── USER: Goals ─────────────────────────────────────────

  @Get('growth/goals')
  async myGoals(@Req() req: any) {
    return this.growth.getUserGoals(req.user.id);
  }

  @Post('growth/goals')
  async createGoal(@Req() req: any, @Body() body: { title: string; description?: string; target?: number }) {
    if (!body.title) throw new HttpException('title required', HttpStatus.BAD_REQUEST);
    return this.growth.createGoal(req.user.id, body);
  }

  @Put('growth/goals/:id/progress')
  async updateGoalProgress(@Req() req: any, @Param('id') id: string, @Body() body: { increment?: number }) {
    return this.growth.updateGoalProgress(+id, req.user.id, body.increment ?? 1);
  }

  // ── USER: Achievements ──────────────────────────────────

  @Get('growth/achievements')
  async myAchievements(@Req() req: any) {
    return this.growth.getUserAchievements(req.user.id);
  }

  @Get('growth/achievements/catalog')
  async achievementsCatalog() {
    return this.growth.getAllAchievements();
  }

  // ── USER: Public Profile ────────────────────────────────

  @Get('growth/public-profile')
  async myPublicProfile(@Req() req: any) {
    const { rows } = await this.growth['pool'].query(
      'SELECT * FROM public_profiles WHERE user_id = $1', [req.user.id],
    );
    return rows[0] || null;
  }

  @Post('growth/public-profile')
  async upsertMyPublicProfile(@Req() req: any, @Body() body: Record<string, any>) {
    const result = await this.growth.upsertPublicProfile(req.user.id, body);
    // Check achievement
    if (body.is_public) {
      await this.growth.unlock(req.user.id, 'public_profile');
    }
    return result;
  }

  // ── USER: Share ─────────────────────────────────────────

  @Post('growth/share')
  async logShare(@Req() req: any, @Body() body: { type?: string; target_id?: string }) {
    await this.growth.grantActionXp(req.user.id, 'share');
    await this.growth.checkAchievements(req.user.id, 'share');
    return { ok: true };
  }

  // ── USER: Levels config ─────────────────────────────────

  @Get('growth/levels')
  async levels() {
    return this.growth.getLevelConfigs();
  }

  // ── ADMIN ───────────────────────────────────────────────

  @Get('admin/growth/user/:userId')
  @UseGuards(AdminGuard)
  async adminUserGrowth(@Param('userId') userId: string) {
    const [xp, streak, goals, achievements] = await Promise.all([
      this.growth.getXpState(+userId),
      this.growth.getStreak(+userId),
      this.growth.getUserGoals(+userId),
      this.growth.getUserAchievements(+userId),
    ]);
    return { xp, streak, goals, achievements };
  }

  @Post('admin/growth/add-xp')
  @UseGuards(AdminGuard)
  async adminAddXp(@Body() body: { user_id: number; amount: number; reason?: string }) {
    if (!body.user_id || !body.amount) throw new HttpException('user_id and amount required', HttpStatus.BAD_REQUEST);
    return this.growth.addXp(body.user_id, body.amount, body.reason || 'Админ бонус', 'admin');
  }

  @Post('admin/growth/unlock')
  @UseGuards(AdminGuard)
  async adminUnlock(@Body() body: { user_id: number; achievement_id: string }) {
    if (!body.user_id || !body.achievement_id) throw new HttpException('user_id and achievement_id required', HttpStatus.BAD_REQUEST);
    return this.growth.unlock(body.user_id, body.achievement_id);
  }
}
