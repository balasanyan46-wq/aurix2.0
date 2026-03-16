import { Controller, Get, Post, Put, Body, Param, Query, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ProductionService } from './production.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class ProductionController {
  constructor(private readonly svc: ProductionService) {}

  @Get('production-orders')
  async getOrders(@Query('user_id') userId?: string) {
    return this.svc.getOrders(userId ? +userId : undefined);
  }

  @Post('production-orders')
  async createOrder(@Body() body: Record<string, any>) {
    return this.svc.createOrder(body);
  }

  @Post('production-order-items/batch')
  async batchItems(@Body() body: any[]) { return this.svc.batchInsertItems(body); }

  @Get('production-order-items')
  async getItems(@Query('order_ids') orderIds: string) {
    if (!orderIds) throw new HttpException('order_ids required', HttpStatus.BAD_REQUEST);
    return this.svc.getItems(orderIds);
  }

  @Put('production-order-items/:id')
  async updateItem(@Param('id') id: string, @Body() body: Record<string, any>) {
    return this.svc.updateItem(+id, body);
  }

  @Get('service-catalog')
  async getCatalog(@Query('is_active') isActive?: string) { return this.svc.getCatalog(isActive); }

  @Put('service-catalog')
  async upsertCatalog(@Body() body: Record<string, any>) { return this.svc.upsertCatalog(body); }

  @Get('production-assignees')
  async getAssignees(@Query('is_active') isActive?: string) { return this.svc.getAssignees(isActive); }

  @Put('production-assignees')
  async upsertAssignee(@Body() body: Record<string, any>) { return this.svc.upsertAssignee(body); }

  @Get('production-comments')
  async getComments(@Query('order_item_id') oid: string) { return this.svc.getComments(+oid); }

  @Post('production-comments')
  async addComment(@Body() body: Record<string, any>) { return this.svc.addComment(body); }

  @Get('production-files')
  async getFiles(@Query('order_item_id') oid: string) { return this.svc.getFiles(+oid); }

  @Post('production-files')
  async createFile(@Body() body: Record<string, any>) { return this.svc.createFile(body); }

  @Get('production-files/signed-url')
  async signedUrl(@Query('path') path: string) {
    const base = process.env.APP_URL || 'http://localhost:3000';
    return { url: `${base}/storage/${path}` };
  }

  @Get('production-events')
  async getEvents(@Query('order_item_id') oid: string) { return this.svc.getEvents(+oid); }

  @Post('production-events')
  async addEvent(@Body() body: Record<string, any>) { return this.svc.addEvent(body); }

  @Post('production-events/batch')
  async batchEvents(@Body() body: any[]) { return this.svc.batchEvents(body); }
}
