import { Controller, Get, Post, Inject, UseGuards, Query } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { SystemService } from './system.service';

@Controller('system')
export class SystemController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly systemService: SystemService,
  ) {}

  /** Public health endpoint (no auth — for uptime monitors). */
  @Get('health')
  async health() {
    return this.systemService.getHealth();
  }

  /** Admin: full diagnostics including issues & recent errors. */
  @Get('diagnostics')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async diagnostics() {
    return this.systemService.getDiagnostics();
  }

  /** Admin: trigger self-healing manually. */
  @Post('auto-fix')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async autoFix() {
    const result = await this.systemService.autoFix();
    const health = await this.systemService.getHealth();
    return { ...result, health };
  }

  /** Admin: query system logs. */
  @Get('logs')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async logs(
    @Query('type') type?: string,
    @Query('limit') limit?: string,
  ) {
    const safeLimit = Math.min(Math.max(+(limit || 50), 1), 200);

    try {
      if (type) {
        const { rows } = await this.pool.query(
          `SELECT id, type, message, data, created_at
           FROM system_logs
           WHERE type = $1
           ORDER BY created_at DESC LIMIT $2`,
          [type, safeLimit],
        );
        return rows;
      }

      const { rows } = await this.pool.query(
        `SELECT id, type, message, data, created_at
         FROM system_logs
         ORDER BY created_at DESC LIMIT $1`,
        [safeLimit],
      );
      return rows;
    } catch {
      return [];
    }
  }
}
