import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { PromoService } from './promo.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class PromoController {
  constructor(private readonly svc: PromoService) {}

  @Get('promo-requests')
  async list(@Query() query: Record<string, any>) { return this.svc.list(query); }

  @Post('promo-requests')
  async create(@Body() body: Record<string, any>) {
    if (!body.user_id || !body.type) throw new HttpException('user_id and type required', HttpStatus.BAD_REQUEST);
    return this.svc.create(body);
  }

  @Put('promo-requests/:id')
  async update(@Param('id') id: string, @Body() body: Record<string, any>) {
    const r = await this.svc.update(+id, body);
    if (!r) throw new HttpException('not found', HttpStatus.NOT_FOUND);
    return r;
  }

  @Get('promo-events')
  async getEvents(@Query('promo_request_id') promoRequestId: string) {
    if (!promoRequestId) throw new HttpException('promo_request_id required', HttpStatus.BAD_REQUEST);
    return this.svc.getEvents(+promoRequestId);
  }

  @Post('promo-events')
  async addEvent(@Body() body: Record<string, any>) {
    return this.svc.addEvent(body);
  }
}
