import { Controller, Get, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AaiService } from './aai.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AaiController {
  constructor(private readonly svc: AaiService) {}

  @Get('release-attention-index')
  async getIndex(@Query('release_id') releaseId: string) {
    if (!releaseId) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getIndex(+releaseId);
  }

  @Get('release-clicks')
  async getClicks(@Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getClicks(query);
  }

  @Get('release-page-views')
  async getPageViews(@Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getPageViews(query);
  }

  @Get('dnk-test-aai-links')
  async getDnkLinks(@Query() query: Record<string, any>) {
    if (!query.release_id) throw new HttpException('release_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getDnkAaiLinks(query);
  }
}
