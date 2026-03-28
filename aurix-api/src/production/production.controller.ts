import { Controller, Get, Post, Put, Body, Param, Query, Req, Inject, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { ProductionService } from './production.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class ProductionController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: ProductionService,
  ) {}

  /** Check if user is admin by querying DB */
  private async isAdmin(userId: number): Promise<boolean> {
    const { rows } = await this.pool.query('SELECT role FROM users WHERE id = $1', [userId]);
    return rows[0]?.role === 'admin';
  }

  /** Verify authenticated user owns the given order, or is admin */
  private async assertOrderOwnership(userId: number, orderId: number): Promise<void> {
    if (await this.isAdmin(userId)) return;
    const { rows } = await this.pool.query('SELECT id FROM production_orders WHERE id = $1 AND user_id = $2', [orderId, userId]);
    if (!rows.length) throw new HttpException('Forbidden', HttpStatus.FORBIDDEN);
  }

  /** Verify authenticated user owns the order that contains the given order_item */
  private async assertItemOwnership(userId: number, itemId: number): Promise<void> {
    if (await this.isAdmin(userId)) return;
    const { rows } = await this.pool.query(
      `SELECT poi.id FROM production_order_items poi
       JOIN production_orders po ON po.id = poi.order_id
       WHERE poi.id = $1 AND po.user_id = $2`, [itemId, userId],
    );
    if (!rows.length) throw new HttpException('Forbidden', HttpStatus.FORBIDDEN);
  }

  @Get('production-orders')
  async getOrders(@Req() req: any) {
    // SECURITY: regular users see only their own orders; admin sees all
    const { rows } = await (this.svc as any).pool?.query?.('SELECT role FROM users WHERE id = $1', [req.user.id]).catch(() => ({ rows: [] })) || { rows: [] };
    if (rows[0]?.role === 'admin') {
      return this.svc.getOrders();
    }
    return this.svc.getOrders(req.user.id);
  }

  @Post('production-orders')
  async createOrder(@Req() req: any, @Body() body: Record<string, any>) {
    // SECURITY: always use authenticated user's ID
    return this.svc.createOrder({ ...body, user_id: req.user.id });
  }

  @Post('production-order-items/batch')
  async batchItems(@Req() req: any, @Body() body: any[]) {
    const orderIds = [...new Set(body.map(i => i.order_id))];
    for (const oid of orderIds) await this.assertOrderOwnership(req.user.id, oid);
    return this.svc.batchInsertItems(body);
  }

  @Get('production-order-items')
  async getItems(@Req() req: any, @Query('order_ids') orderIds: string) {
    if (!orderIds) throw new HttpException('order_ids required', HttpStatus.BAD_REQUEST);
    const ids = orderIds.split(',').map(Number).filter(n => !isNaN(n));
    for (const oid of ids) await this.assertOrderOwnership(req.user.id, oid);
    return this.svc.getItems(orderIds);
  }

  @Put('production-order-items/:id')
  async updateItem(@Req() req: any, @Param('id') id: string, @Body() body: Record<string, any>) {
    await this.assertItemOwnership(req.user.id, +id);
    return this.svc.updateItem(+id, body);
  }

  @Get('service-catalog')
  async getCatalog(@Query('is_active') isActive?: string) { return this.svc.getCatalog(isActive); }

  @UseGuards(AdminGuard)
  @Put('service-catalog')
  async upsertCatalog(@Body() body: Record<string, any>) { return this.svc.upsertCatalog(body); }

  @Get('production-assignees')
  async getAssignees(@Query('is_active') isActive?: string) { return this.svc.getAssignees(isActive); }

  @UseGuards(AdminGuard)
  @Put('production-assignees')
  async upsertAssignee(@Body() body: Record<string, any>) { return this.svc.upsertAssignee(body); }

  @Get('production-comments')
  async getComments(@Req() req: any, @Query('order_item_id') oid: string) {
    await this.assertItemOwnership(req.user.id, +oid);
    return this.svc.getComments(+oid);
  }

  @Post('production-comments')
  async addComment(@Req() req: any, @Body() body: Record<string, any>) {
    await this.assertItemOwnership(req.user.id, body.order_item_id);
    const admin = await this.isAdmin(req.user.id);
    return this.svc.addComment({
      ...body,
      author_user_id: req.user.id,
      author_role: admin ? 'admin' : 'user',
    });
  }

  @Get('production-files')
  async getFiles(@Req() req: any, @Query('order_item_id') oid: string) {
    await this.assertItemOwnership(req.user.id, +oid);
    return this.svc.getFiles(+oid);
  }

  @Post('production-files')
  async createFile(@Req() req: any, @Body() body: Record<string, any>) {
    await this.assertItemOwnership(req.user.id, body.order_item_id);
    return this.svc.createFile(body);
  }

  @Get('production-files/signed-url')
  async signedUrl(@Req() req: any, @Query('path') path: string, @Query('order_item_id') oid: string) {
    if (oid) await this.assertItemOwnership(req.user.id, +oid);
    const base = process.env.APP_URL || 'http://localhost:3000';
    return { url: `${base}/storage/${path}` };
  }

  @Get('production-events')
  async getEvents(@Req() req: any, @Query('order_item_id') oid: string) {
    await this.assertItemOwnership(req.user.id, +oid);
    return this.svc.getEvents(+oid);
  }

  @Post('production-events')
  async addEvent(@Req() req: any, @Body() body: Record<string, any>) {
    await this.assertItemOwnership(req.user.id, body.order_item_id);
    return this.svc.addEvent(body);
  }

  @Post('production-events/batch')
  async batchEvents(@Req() req: any, @Body() body: any[]) {
    const itemIds = [...new Set(body.map(i => i.order_item_id))];
    for (const iid of itemIds) await this.assertItemOwnership(req.user.id, iid);
    return this.svc.batchEvents(body);
  }
}
