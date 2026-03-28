import { Controller, Get, Post, Body, Req, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { InsightsService } from './insights.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class InsightsController {
  constructor(private readonly insights: InsightsService) {}

  @Get('analytics/dashboard')
  async dashboard(@Req() req: any) {
    return this.insights.getAnalytics(req.user.id);
  }

  @Post('analytics/release-plan')
  async releasePlan(@Req() req: any, @Body() body: any) {
    return this.insights.generateReleasePlan(req.user.id, body);
  }

  @Post('analytics/promo-ideas')
  async promoIdeas(@Req() req: any, @Body() body: any) {
    if (!body.description) {
      return { error: 'description is required' };
    }
    return this.insights.generatePromoIdeas(req.user.id, body);
  }
}
