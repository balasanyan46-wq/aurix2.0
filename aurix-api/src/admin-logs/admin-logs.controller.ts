import { Controller, Get, Post, Body, Query, Req, Inject, UseGuards } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { AdminLogsService } from './admin-logs.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AdminLogsController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: AdminLogsService,
  ) {}

  @Get('admin-logs')
  @UseGuards(AdminGuard)
  async list(@Query('limit') limit?: string, @Query('offset') offset?: string, @Query('action') action?: string) {
    return this.svc.list(+(limit || 50), +(offset || 0), action);
  }

  @Get('admin-logs/count')
  @UseGuards(AdminGuard)
  async count() {
    const count = await this.svc.count();
    return { count };
  }

  @Post('admin-logs')
  @UseGuards(AdminGuard)
  async create(@Req() req: any, @Body() body: Record<string, any>) {
    body.admin_id = body.admin_id || req.user.id;
    return this.svc.create(body);
  }

  @Post('rpc/admin_log_event')
  @UseGuards(AdminGuard)
  async rpcLogEvent(@Req() req: any, @Body() body: Record<string, any>) {
    return this.svc.create({ admin_id: req.user.id, action: body.p_action, target_type: body.p_target_type, target_id: body.p_target_id, details: body.p_details });
  }

  @Get('admin/ops-snapshot')
  @UseGuards(AdminGuard)
  async opsSnapshot() {
    const [users, releases, tickets, orders] = await Promise.all([
      this.pool.query('SELECT count(*)::int AS c FROM users'),
      this.pool.query('SELECT count(*)::int AS c FROM releases'),
      this.pool.query("SELECT count(*)::int AS c FROM support_tickets WHERE status = 'open'"),
      this.pool.query("SELECT count(*)::int AS c FROM production_orders WHERE status = 'active'"),
    ]);
    return {
      total_users: users.rows[0].c,
      total_releases: releases.rows[0].c,
      open_tickets: tickets.rows[0].c,
      active_orders: orders.rows[0].c,
    };
  }
}
