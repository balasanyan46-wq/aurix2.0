import { Inject, Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export interface HealthResult {
  users: boolean;
  releases: boolean;
  production_orders: boolean;
  support_tickets: boolean;
  admin_logs: boolean;
  system_logs: boolean;
  status: 'ok' | 'degraded';
  checked_at: string;
}

const MONITORED_TABLES = [
  'users',
  'releases',
  'production_orders',
  'support_tickets',
  'admin_logs',
  'system_logs',
] as const;

/** Minimal schemas for self-healing — only create if table is completely missing. */
const TABLE_SCHEMAS: Record<string, string> = {
  production_orders: `
    CREATE TABLE IF NOT EXISTS production_orders (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid,
      title text,
      status text DEFAULT 'active',
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    )`,
  support_tickets: `
    CREATE TABLE IF NOT EXISTS support_tickets (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id uuid NOT NULL,
      subject text NOT NULL DEFAULT '',
      message text NOT NULL DEFAULT '',
      status text DEFAULT 'open',
      priority text DEFAULT 'medium',
      created_at timestamptz DEFAULT now(),
      updated_at timestamptz DEFAULT now()
    )`,
  admin_logs: `
    CREATE TABLE IF NOT EXISTS admin_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      admin_id integer,
      action text,
      target_type text,
      target_id text,
      details jsonb,
      created_at timestamptz DEFAULT now()
    )`,
  system_logs: `
    CREATE TABLE IF NOT EXISTS system_logs (
      id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
      type text NOT NULL,
      message text NOT NULL,
      data jsonb,
      created_at timestamptz DEFAULT now()
    )`,
};

@Injectable()
export class SystemService {
  private readonly logger = new Logger(SystemService.name);
  private lastHealth: HealthResult | null = null;

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {
    // Ensure system_logs table exists on startup
    this.ensureSystemLogs().catch(() => {});
  }

  // ─── Health Check ──────────────────────────────────────────

  async getHealth(): Promise<HealthResult> {
    const results: Record<string, boolean> = {};

    await Promise.all(
      MONITORED_TABLES.map(async (table) => {
        try {
          await this.pool.query(`SELECT 1 FROM ${table} LIMIT 1`);
          results[table] = true;
        } catch {
          results[table] = false;
        }
      }),
    );

    const allOk = Object.values(results).every(Boolean);
    const health: HealthResult = {
      users: results.users ?? false,
      releases: results.releases ?? false,
      production_orders: results.production_orders ?? false,
      support_tickets: results.support_tickets ?? false,
      admin_logs: results.admin_logs ?? false,
      system_logs: results.system_logs ?? false,
      status: allOk ? 'ok' : 'degraded',
      checked_at: new Date().toISOString(),
    };

    this.lastHealth = health;
    return health;
  }

  getLastHealth(): HealthResult | null {
    return this.lastHealth;
  }

  // ─── System Logging ────────────────────────────────────────

  async logSystemEvent(
    type: string,
    message: string,
    data?: Record<string, unknown>,
  ): Promise<void> {
    try {
      await this.pool.query(
        `INSERT INTO system_logs (type, message, data) VALUES ($1, $2, $3)`,
        [type, message, data ? JSON.stringify(data) : null],
      );
    } catch (e) {
      // Fallback to console if system_logs table doesn't exist
      this.logger.error(`[SystemLog] ${type}: ${message}`, JSON.stringify(data));
    }
  }

  // ─── Self-Healing ──────────────────────────────────────────

  async autoFix(): Promise<{ fixed: string[]; skipped: string[] }> {
    const fixed: string[] = [];
    const skipped: string[] = [];

    for (const [table, ddl] of Object.entries(TABLE_SCHEMAS)) {
      try {
        // Check if table exists
        const { rows } = await this.pool.query(
          `SELECT 1 FROM information_schema.tables
           WHERE table_schema = 'public' AND table_name = $1`,
          [table],
        );

        if (rows.length === 0) {
          // Table missing — create it
          await this.pool.query(ddl);
          fixed.push(table);

          await this.logSystemEvent('auto_fix', `Created missing table: ${table}`, {
            table,
            action: 'create_table',
          });

          this.logger.warn(`Auto-fix: created missing table "${table}"`);
        } else {
          skipped.push(table);
        }
      } catch (e: any) {
        this.logger.error(`Auto-fix failed for "${table}": ${e.message}`);
        await this.logSystemEvent('auto_fix_error', `Failed to fix table: ${table}`, {
          table,
          error: e.message,
        });
      }
    }

    return { fixed, skipped };
  }

  // ─── Diagnostics for AI Insights ───────────────────────────

  async getDiagnostics(): Promise<{
    health: HealthResult;
    issues: Array<{ type: string; message: string; action: string }>;
    recent_errors: Array<Record<string, unknown>>;
  }> {
    const health = await this.getHealth();
    const issues: Array<{ type: string; message: string; action: string }> = [];

    // Flag degraded tables
    for (const table of MONITORED_TABLES) {
      if (!health[table]) {
        issues.push({
          type: 'critical',
          message: `${table} не работает`,
          action: 'Таблица отсутствует или повреждена. Запустите autoFix или миграцию.',
        });
      }
    }

    // Fetch recent system errors
    let recentErrors: Array<Record<string, unknown>> = [];
    try {
      const { rows } = await this.pool.query(
        `SELECT type, message, data, created_at
         FROM system_logs
         WHERE type IN ('critical', 'error', 'auto_fix_error')
         ORDER BY created_at DESC LIMIT 20`,
      );
      recentErrors = rows;
    } catch {
      // system_logs may not exist yet
    }

    return { health, issues, recent_errors: recentErrors };
  }

  // ─── Cron: health check every 60s ─────────────────────────

  @Interval(60_000)
  async scheduledHealthCheck(): Promise<void> {
    try {
      const health = await this.getHealth();

      if (health.status === 'degraded') {
        const degraded = MONITORED_TABLES.filter((t) => !health[t]);

        await this.logSystemEvent('critical', 'System degraded', {
          degraded_tables: degraded,
          checked_at: health.checked_at,
        });

        this.logger.warn(`System degraded — attempting auto-fix for: ${degraded.join(', ')}`);

        const result = await this.autoFix();

        if (result.fixed.length > 0) {
          this.logger.log(`Auto-fix applied: ${result.fixed.join(', ')}`);
          // Re-check after fix
          await this.getHealth();
        }
      }
    } catch (e: any) {
      this.logger.error(`Scheduled health check failed: ${e.message}`);
    }
  }

  // ─── Cron: hourly error digest ─────────────────────────────

  @Interval(3_600_000) // every hour
  async hourlyErrorDigest(): Promise<void> {
    try {
      const { rows } = await this.pool.query(
        `SELECT path, status_code, error_message, COUNT(*) as count
         FROM error_logs
         WHERE created_at > NOW() - INTERVAL '1 hour'
         GROUP BY path, status_code, error_message
         ORDER BY count DESC
         LIMIT 10`,
      );

      if (rows.length === 0) return;

      const total = rows.reduce((s, r) => s + parseInt(r.count), 0);
      const serverErrors = rows.filter(r => r.status_code >= 500);

      // Log digest to system_logs
      await this.logSystemEvent('error_digest', `${total} errors in last hour`, {
        total,
        server_errors: serverErrors.length,
        top_errors: rows.slice(0, 5),
      });

      // Send Telegram if 5xx errors exist
      if (serverErrors.length > 0) {
        await this.sendTelegramDigest(total, serverErrors);
      }

      this.logger.log(`[ErrorDigest] ${total} errors in last hour (${serverErrors.length} server errors)`);
    } catch (e: any) {
      this.logger.error(`Hourly error digest failed: ${e.message}`);
    }
  }

  private async sendTelegramDigest(total: number, serverErrors: any[]) {
    const gwUrl = process.env.AI_GATEWAY_URL;
    const gwSecret = process.env.AI_GATEWAY_SECRET;
    if (!gwUrl) return;

    const lines = serverErrors.slice(0, 5).map(e =>
      `• ${e.count}× \`${e.status_code} ${e.path}\`\n  ${e.error_message?.slice(0, 80)}`
    );

    const text = [
      `⚠️ *AURIX — ${total} ошибок за час*`,
      `Серверных (5xx): ${serverErrors.length}`,
      '',
      ...lines,
    ].join('\n');

    try {
      const axios = require('axios');
      await axios.post(`${gwUrl}/telegram/send`, { text, parse_mode: 'Markdown' }, {
        headers: { 'X-Gateway-Secret': gwSecret || '', 'Content-Type': 'application/json' },
        timeout: 10000,
      });
    } catch {}
  }

  // ─── Internals ─────────────────────────────────────────────

  private async ensureSystemLogs(): Promise<void> {
    try {
      await this.pool.query(TABLE_SCHEMAS.system_logs);
      this.logger.log('system_logs table ensured');
    } catch (e: any) {
      this.logger.error(`Failed to ensure system_logs: ${e.message}`);
    }
  }
}
