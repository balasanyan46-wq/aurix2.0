import { Controller, Get, Post, Body, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ReferralService } from './referral.service';

@Controller('referral')
@UseGuards(JwtAuthGuard)
export class ReferralController {
  constructor(private readonly referralService: ReferralService) {}

  @Get('stats')
  async getStats(@Req() req: any) {
    const userId = req.user.sub ?? req.user.id;
    const stats = await this.referralService.getStats(userId);
    return { success: true, ...stats };
  }

  @Get('code')
  async getCode(@Req() req: any) {
    const userId = req.user.sub ?? req.user.id;
    const code = await this.referralService.getOrCreateCode(userId);
    return {
      success: true,
      code,
      referral_link: `https://aurixmusic.ru/register?ref=${code}`,
    };
  }

  @Post('apply')
  async applyCode(@Req() req: any, @Body() body: { code: string }) {
    const userId = req.user.sub ?? req.user.id;
    if (!body.code || typeof body.code !== 'string') {
      return { success: false, error: 'Укажите реферальный код' };
    }
    const applied = await this.referralService.applyReferralCode(userId, body.code);
    if (!applied) {
      return { success: false, error: 'Код недействителен или уже использован' };
    }
    return { success: true };
  }
}
