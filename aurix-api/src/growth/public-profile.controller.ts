import { Controller, Get, Param, HttpException, HttpStatus } from '@nestjs/common';
import { GrowthService } from './growth.service';

/** Public endpoints — no auth required. */
@Controller()
export class PublicProfileController {
  constructor(private readonly growth: GrowthService) {}

  @Get('p/:slug')
  async publicProfile(@Param('slug') slug: string) {
    const profile = await this.growth.getPublicProfile(slug);
    if (!profile) throw new HttpException('Profile not found', HttpStatus.NOT_FOUND);
    return profile;
  }
}
