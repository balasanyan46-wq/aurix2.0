import {
  Controller,
  Post,
  Get,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  HttpException,
  HttpStatus,
  ParseIntPipe,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { CastingService } from './casting.service';

@Controller('casting')
export class CastingController {
  constructor(private readonly castingService: CastingService) {}

  @Get('plans')
  getPlans() {
    return { success: true, plans: this.castingService.getPlans() };
  }

  @Get('slots')
  async getSlots(@Query('city') city: string) {
    if (!city) throw new HttpException('city is required', HttpStatus.BAD_REQUEST);
    const slots = await this.castingService.getSlots(city);
    return { success: true, slots };
  }

  @Post('purchase')
  async purchase(@Body() body: { name: string; phone: string; city: string; plan: string; quantity?: number }) {
    if (!body.name || !body.phone || !body.city || !body.plan) {
      throw new HttpException('name, phone, city, plan are required', HttpStatus.BAD_REQUEST);
    }
    const result = await this.castingService.createParticipation({
      ...body,
      quantity: body.plan === 'audience' ? Math.max(1, Math.min(body.quantity || 1, 10)) : 1,
    });
    if (!result.success) {
      throw new HttpException(result.error || 'Payment failed', HttpStatus.BAD_REQUEST);
    }
    return { success: true, data: { paymentUrl: result.paymentUrl, orderId: result.orderId } };
  }

  @Get('order/:orderId')
  async getOrder(@Param('orderId') orderId: string) {
    const app = await this.castingService.findByOrderId(orderId);
    if (!app) throw new HttpException('Order not found', HttpStatus.NOT_FOUND);
    return { success: true, application: app };
  }

  @Post('webhook')
  async webhook(@Body() body: any) {
    const result = await this.castingService.handleWebhook(body);
    return result.ok ? 'OK' : 'FAIL';
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin/all')
  async getAll(
    @Query('city') city?: string,
    @Query('status') status?: string,
    @Query('search') search?: string,
  ) {
    const applications = await this.castingService.findAll({ city, status, search });
    return { success: true, applications };
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin/stats')
  async getStats() {
    const stats = await this.castingService.getStats();
    return { success: true, stats };
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Get('admin/:id')
  async getById(@Param('id', ParseIntPipe) id: number) {
    const application = await this.castingService.findById(id);
    if (!application) throw new HttpException('Not found', HttpStatus.NOT_FOUND);
    return { success: true, application };
  }

  @UseGuards(JwtAuthGuard, AdminGuard)
  @Patch('admin/:id/status')
  async updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body('status') status: string,
  ) {
    if (!status) throw new HttpException('status is required', HttpStatus.BAD_REQUEST);
    const application = await this.castingService.updateStatus(id, status);
    if (!application) throw new HttpException('Not found', HttpStatus.NOT_FOUND);
    return { success: true, application };
  }
}
