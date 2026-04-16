import { Controller, Get, Post, Put, Delete, Body, Param, Inject, UseGuards, Query } from '@nestjs/common';
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

  // ── Error Logs (admin) ─────────────────────────────────

  /** Admin: get recent errors with stats. */
  @Get('errors')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async getErrors(
    @Query('limit') limit?: string,
    @Query('hours') hours?: string,
  ) {
    const safeLimit = Math.min(Math.max(+(limit || 50), 1), 200);
    const safeHours = Math.min(Math.max(+(hours || 24), 1), 168); // max 7 days

    const { rows: errors } = await this.pool.query(
      `SELECT id, path, method, status_code, error_message, user_id, ip, duration_ms, service, created_at
       FROM error_logs
       WHERE created_at > NOW() - INTERVAL '1 hour' * $1
       ORDER BY created_at DESC
       LIMIT $2`,
      [safeHours, safeLimit],
    );

    // Stats
    const { rows: stats } = await this.pool.query(
      `SELECT
         COUNT(*) as total,
         COUNT(*) FILTER (WHERE status_code >= 500) as server_errors,
         COUNT(*) FILTER (WHERE status_code >= 400 AND status_code < 500) as client_errors,
         COUNT(DISTINCT path) as unique_paths,
         COUNT(DISTINCT user_id) FILTER (WHERE user_id IS NOT NULL) as affected_users,
         MODE() WITHIN GROUP (ORDER BY path) as most_common_path,
         MODE() WITHIN GROUP (ORDER BY error_message) as most_common_error
       FROM error_logs
       WHERE created_at > NOW() - INTERVAL '1 hour' * $1`,
      [safeHours],
    );

    // Top error paths
    const { rows: topPaths } = await this.pool.query(
      `SELECT path, COUNT(*) as count, MAX(status_code) as max_status
       FROM error_logs
       WHERE created_at > NOW() - INTERVAL '1 hour' * $1
       GROUP BY path
       ORDER BY count DESC
       LIMIT 10`,
      [safeHours],
    );

    return {
      success: true,
      errors,
      stats: stats[0] || {},
      top_paths: topPaths,
      period_hours: safeHours,
    };
  }

  /** Admin: AI summary of recent errors. */
  @Get('errors/ai-summary')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async getErrorAiSummary() {
    const { rows } = await this.pool.query(
      `SELECT path, status_code, error_message, COUNT(*) as count
       FROM error_logs
       WHERE created_at > NOW() - INTERVAL '24 hours'
       GROUP BY path, status_code, error_message
       ORDER BY count DESC
       LIMIT 20`,
    );

    if (rows.length === 0) {
      return { success: true, summary: 'За последние 24 часа ошибок не было.' };
    }

    const errorList = rows.map(r => `${r.count}× ${r.status_code} ${r.path}: ${r.error_message}`).join('\n');

    return {
      success: true,
      errors_grouped: rows,
      total_groups: rows.length,
      prompt_for_ai: `Проанализируй ошибки за 24 часа и дай рекомендации:\n${errorList}`,
    };
  }

  /** Admin: check AI providers health. */
  @Get('ai-status')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async getAiStatus() {
    const checks: Array<{ name: string; status: string; latency?: number; error?: string }> = [];

    // Check gateway
    const gwUrl = process.env.AI_GATEWAY_URL;
    if (gwUrl) {
      const start = Date.now();
      try {
        const axios = require('axios');
        const { data } = await axios.get(`${gwUrl}/health`, { timeout: 5000 });
        checks.push({ name: 'AI Gateway', status: 'ok', latency: Date.now() - start, ...data });
      } catch (e: any) {
        checks.push({ name: 'AI Gateway', status: 'down', latency: Date.now() - start, error: e.message });
      }
    }

    // Check audio service
    try {
      const axios = require('axios');
      const audioUrl = process.env.AUDIO_ANALYSIS_URL || 'http://localhost:8001';
      const start = Date.now();
      const { data } = await axios.get(`${audioUrl}/health`, { timeout: 5000 });
      checks.push({ name: 'Audio Analysis', status: 'ok', latency: Date.now() - start, ...data });
    } catch (e: any) {
      checks.push({ name: 'Audio Analysis', status: 'down', error: e.message });
    }

    // Check AI Chat (via Gateway)
    if (gwUrl) {
      try {
        const axios = require('axios');
        const gwSecret = process.env.AI_GATEWAY_SECRET;
        const start = Date.now();
        const { data: chatData } = await axios.post(`${gwUrl}/ai/chat`, {
          messages: [{ role: 'user', content: 'ping' }],
          max_tokens: 1,
        }, {
          headers: { 'X-Gateway-Secret': gwSecret || '', 'Content-Type': 'application/json' },
          timeout: 10000,
        });
        checks.push({ name: 'AI Chat', status: chatData.success ? 'ok' : 'down', latency: Date.now() - start });
      } catch (e: any) {
        checks.push({ name: 'AI Chat', status: 'down', error: e.message?.slice(0, 100) });
      }
    }

    return { success: true, services: checks, checked_at: new Date().toISOString() };
  }

  // ── Service Prices (public read, admin write) ──────────

  /** Public: get all enabled service prices (for wizard). */
  @Get('service-prices')
  async getServicePrices() {
    try {
      const { rows } = await this.pool.query(
        `SELECT id, name, description, price, step, enabled, sort_order
         FROM service_prices
         ORDER BY sort_order ASC`,
      );
      return { success: true, services: rows };
    } catch {
      return { success: true, services: [] };
    }
  }

  /** Admin: update a service price. */
  @Put('service-prices/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async updateServicePrice(
    @Param('id') id: string,
    @Body() body: { name?: string; description?: string; price?: number; step?: number; enabled?: boolean; sort_order?: number },
  ) {
    const sets: string[] = [];
    const vals: any[] = [];
    let idx = 1;

    const allowed = ['name', 'description', 'price', 'step', 'enabled', 'sort_order'];
    for (const key of allowed) {
      if (key in body) {
        sets.push(`${key} = $${idx}`);
        vals.push((body as any)[key]);
        idx++;
      }
    }

    if (sets.length === 0) {
      return { success: false, message: 'no fields to update' };
    }

    sets.push(`updated_at = NOW()`);
    vals.push(id);

    const { rows } = await this.pool.query(
      `UPDATE service_prices SET ${sets.join(', ')} WHERE id = $${idx} RETURNING *`,
      vals,
    );

    return { success: true, service: rows[0] || null };
  }

  /** Admin: create a new service. */
  @Post('service-prices')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async createServicePrice(
    @Body() body: { id: string; name: string; description?: string; price: number; step?: number; sort_order?: number },
  ) {
    const { rows } = await this.pool.query(
      `INSERT INTO service_prices (id, name, description, price, step, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6)
       ON CONFLICT (id) DO UPDATE SET name=$2, description=$3, price=$4, step=$5, sort_order=$6, updated_at=NOW()
       RETURNING *`,
      [body.id, body.name, body.description || '', body.price, body.step || 0, body.sort_order || 0],
    );
    return { success: true, service: rows[0] };
  }

  /** Admin: delete a service. */
  @Delete('service-prices/:id')
  @UseGuards(JwtAuthGuard, AdminGuard)
  async deleteServicePrice(@Param('id') id: string) {
    await this.pool.query('DELETE FROM service_prices WHERE id = $1', [id]);
    return { success: true };
  }
}
