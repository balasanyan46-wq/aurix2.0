import { Controller, Get, Post, UseGuards, Req } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { BrainService } from './brain.service';

@Controller('brain')
@UseGuards(JwtAuthGuard)
export class BrainController {
  constructor(private brain: BrainService) {}

  @Get('profile')
  async getProfile(@Req() req) {
    return this.brain.getProfile(req.user.id);
  }

  @Post('profile/rebuild')
  async rebuildProfile(@Req() req) {
    return this.brain.buildProfile(req.user.id);
  }

  @Get('strategy')
  async getStrategy(@Req() req) {
    return this.brain.getStrategy(req.user.id);
  }

  @Post('strategy/generate')
  async generateStrategy(@Req() req) {
    return this.brain.generateStrategy(req.user.id);
  }
}
