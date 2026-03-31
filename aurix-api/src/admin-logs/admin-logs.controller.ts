import { Controller, Get, Post, Body, Query, Req, Param, Inject, UseGuards } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { AdminLogsService } from './admin-logs.service';
import { SystemService } from '../system/system.service';
import { EdenAiService } from '../ai/eden-ai.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AdminLogsController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: AdminLogsService,
    private readonly systemService: SystemService,
    private readonly ai: EdenAiService,
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
    body.admin_id = req.user.id;
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
      this.pool.query('SELECT count(*)::int AS c FROM users').catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query('SELECT count(*)::int AS c FROM releases').catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query("SELECT count(*)::int AS c FROM support_tickets WHERE status = 'open'").catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query("SELECT count(*)::int AS c FROM production_orders WHERE status = 'active'").catch(() => ({ rows: [{ c: 0 }] })),
    ]);
    return {
      snapshot: {
        delete_requests_pending: 0,
        production_overdue: orders.rows[0].c,
        support_overdue: tickets.rows[0].c,
        reports_not_ready: 0,
      },
      total_users: users.rows[0].c,
      total_releases: releases.rows[0].c,
      open_tickets: tickets.rows[0].c,
      active_orders: orders.rows[0].c,
    };
  }

  /** Enhanced dashboard with DAU/MAU, errors, funnel, recent users, release stats. */
  @Get('admin/dashboard')
  @UseGuards(AdminGuard)
  async dashboard() {
    const queries = await Promise.all([
      // Basic counts
      this.pool.query('SELECT count(*)::int AS c FROM users').catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query('SELECT count(*)::int AS c FROM releases').catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query("SELECT count(*)::int AS c FROM support_tickets WHERE status = 'open'").catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query("SELECT count(*)::int AS c FROM production_orders WHERE status = 'active'").catch(() => ({ rows: [{ c: 0 }] })),
      // New users last 30 days
      this.pool.query("SELECT count(*)::int AS c FROM users WHERE created_at >= current_date - 30").catch(() => ({ rows: [{ c: 0 }] })),
      // Releases by status
      this.pool.query("SELECT status, count(*)::int AS count FROM releases GROUP BY status ORDER BY count DESC").catch(() => ({ rows: [] })),
      // Recent users (last 10)
      this.pool.query("SELECT id, email, created_at FROM users ORDER BY created_at DESC LIMIT 10").catch(() => ({ rows: [] })),
      // Recent admin actions (last 10)
      this.pool.query("SELECT * FROM admin_logs ORDER BY created_at DESC LIMIT 10").catch(() => ({ rows: [] })),
      // Users by plan
      this.pool.query(`
        SELECT COALESCE(p.plan, 'none') AS plan, count(*)::int AS count
        FROM users u LEFT JOIN profiles p ON p.user_id = u.id
        GROUP BY p.plan ORDER BY count DESC
      `).catch(() => ({ rows: [] })),
      // DAU (last 7 days, from user_events if table exists)
      this.pool.query(`
        SELECT date_trunc('day', created_at)::date AS day, count(DISTINCT user_id)::int AS dau
        FROM user_events
        WHERE created_at >= current_date - 7
        GROUP BY 1 ORDER BY 1
      `).catch(() => ({ rows: [] })),
      // Events last 24h
      this.pool.query(`
        SELECT count(*)::int AS c FROM user_events WHERE created_at >= now() - interval '24 hours'
      `).catch(() => ({ rows: [{ c: 0 }] })),
    ]);

    return {
      total_users: queries[0].rows[0]?.c ?? 0,
      total_releases: queries[1].rows[0]?.c ?? 0,
      open_tickets: queries[2].rows[0]?.c ?? 0,
      active_orders: queries[3].rows[0]?.c ?? 0,
      new_users_30d: queries[4].rows[0]?.c ?? 0,
      releases_by_status: queries[5].rows,
      recent_users: queries[6].rows,
      recent_admin_actions: queries[7].rows,
      users_by_plan: queries[8].rows,
      dau_7d: queries[9].rows,
      events_24h: queries[10].rows[0]?.c ?? 0,
    };
  }

  /** Admin: user detail with profile + stats. */
  @Get('admin/users/:id')
  @UseGuards(AdminGuard)
  async userDetail(@Req() req: any) {
    const userId = req.params.id;
    const [user, profile, releases, tickets] = await Promise.all([
      this.pool.query('SELECT id, email, created_at, verified FROM users WHERE id = $1', [userId]).catch(() => ({ rows: [] })),
      this.pool.query('SELECT * FROM profiles WHERE user_id = $1', [userId]).catch(() => ({ rows: [] })),
      this.pool.query(`SELECT r.id, r.title, r.status, r.created_at
         FROM releases r JOIN artists a ON a.id = r.artist_id
         WHERE a.user_id = $1::int ORDER BY r.created_at DESC`, [userId]).catch(() => ({ rows: [] })),
      this.pool.query('SELECT id, subject, status, created_at FROM support_tickets WHERE user_id::text = $1::text ORDER BY created_at DESC', [userId]).catch(() => ({ rows: [] })),
    ]);
    return {
      user: user.rows[0] || null,
      profile: profile.rows[0] || null,
      releases: releases.rows,
      tickets: tickets.rows,
    };
  }

  /** AI-powered platform analysis using Eden AI. */
  @Get('admin/ai-insights')
  @UseGuards(AdminGuard)
  async aiInsights() {
    // Gather key stats for AI analysis
    const [users, releases, tickets, events, plans, dau] = await Promise.all([
      this.pool.query('SELECT count(*)::int AS c FROM users').catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query("SELECT status, count(*)::int AS count FROM releases GROUP BY status").catch(() => ({ rows: [] })),
      this.pool.query("SELECT status, count(*)::int AS count FROM support_tickets GROUP BY status").catch(() => ({ rows: [] })),
      this.pool.query(`
        SELECT event, count(*)::int AS count
        FROM user_events
        WHERE created_at >= current_date - 7
        GROUP BY event ORDER BY count DESC LIMIT 10
      `).catch(() => ({ rows: [] })),
      this.pool.query(`
        SELECT COALESCE(p.plan, 'none') AS plan, count(*)::int AS count
        FROM users u LEFT JOIN profiles p ON p.user_id = u.id
        GROUP BY p.plan
      `).catch(() => ({ rows: [] })),
      this.pool.query(`
        SELECT date_trunc('day', created_at)::date AS day, count(DISTINCT user_id)::int AS dau
        FROM user_events
        WHERE created_at >= current_date - 7
        GROUP BY 1 ORDER BY 1
      `).catch(() => ({ rows: [] })),
    ]);

    const statsText = [
      `Всего пользователей: ${users.rows[0].c}`,
      `Релизы: ${releases.rows.map((r: any) => `${r.status}=${r.count}`).join(', ')}`,
      `Тикеты: ${tickets.rows.map((r: any) => `${r.status}=${r.count}`).join(', ')}`,
      `Планы: ${plans.rows.map((r: any) => `${r.plan}=${r.count}`).join(', ')}`,
      `События (7 дней): ${events.rows.map((r: any) => `${r.event}=${r.count}`).join(', ')}`,
      `DAU (7 дней): ${dau.rows.map((r: any) => `${r.day}=${r.dau}`).join(', ')}`,
    ].join('\n');

    try {
      const content = await this.ai.simpleChat(
        'Ты — аналитик платформы для музыкантов AURIX. Дай краткий анализ (3-5 пунктов) по метрикам. Что идёт хорошо, что нужно улучшить, какие тренды видишь. Пиши по-русски, коротко и по делу. Не используй markdown.',
        statsText,
        { maxTokens: 600, temperature: 0.7, timeout: 30_000 },
      );

      // Append system health issues
      const diagnostics = await this.systemService.getDiagnostics();
      return {
        insights: content,
        stats: statsText,
        system_issues: diagnostics.issues,
        system_status: diagnostics.health.status,
      };
    } catch (e: any) {
      // Still include system diagnostics even if AI fails
      let systemIssues: any[] = [];
      let systemStatus = 'unknown';
      try {
        const diag = await this.systemService.getDiagnostics();
        systemIssues = diag.issues;
        systemStatus = diag.health.status;
      } catch {}
      return {
        insights: `AI error: ${e.message || 'unknown'}`,
        stats: statsText,
        system_issues: systemIssues,
        system_status: systemStatus,
      };
    }
  }

  /** AI operator — suggests specific actions based on data patterns. */
  @Get('admin/ai-actions')
  @UseGuards(AdminGuard)
  async aiActions() {
    // Gather deeper analytics
    const [errors, dropOffs, sessions, notifications] = await Promise.all([
      // Top error events
      this.pool.query(`
        SELECT event, count(*)::int AS count, count(DISTINCT user_id)::int AS users
        FROM user_events
        WHERE event LIKE '%error%' AND created_at >= current_date - 7
        GROUP BY event ORDER BY count DESC LIMIT 5
      `).catch(() => ({ rows: [] })),
      // Users who started but didn't complete releases
      this.pool.query(`
        SELECT count(*)::int AS c FROM releases WHERE status = 'draft' AND created_at >= current_date - 14
      `).catch(() => ({ rows: [{ c: 0 }] })),
      // Session stats
      this.pool.query(`
        SELECT round(avg(duration_s))::int AS avg_dur, count(*)::int AS total
        FROM user_sessions
        WHERE started_at >= current_date - 7 AND duration_s IS NOT NULL
      `).catch(() => ({ rows: [{ avg_dur: 0, total: 0 }] })),
      // Recent auto-action fires
      this.pool.query(`
        SELECT aa.name, count(*)::int AS fires
        FROM auto_action_log al JOIN auto_actions aa ON aa.id = al.action_id
        WHERE al.created_at >= current_date - 7
        GROUP BY aa.name ORDER BY fires DESC LIMIT 5
      `).catch(() => ({ rows: [] })),
    ]);

    const context = [
      `Ошибки (7 дн): ${errors.rows.map((r: any) => `${r.event}=${r.count} (${r.users} users)`).join(', ') || 'нет'}`,
      `Незаконченные релизы (14 дн): ${dropOffs.rows[0].c}`,
      `Сессии (7 дн): ${sessions.rows[0].total}, сред. длительность ${sessions.rows[0].avg_dur}с`,
      `Автодействия (7 дн): ${notifications.rows.map((r: any) => `${r.name}=${r.fires}`).join(', ') || 'нет'}`,
    ].join('\n');

    try {
      const systemPrompt = `Ты — AI-оператор платформы AURIX для музыкантов. Проанализируй данные и предложи 3-5 конкретных действий.

Каждое действие — строго JSON объект:
{
  "problem": "Описание проблемы",
  "suggestion": "Что делать",
  "severity": "high" | "medium" | "low",
  "action": {
    "type": "notify" | "create_ticket" | "bonus" | "email",
    "title": "Заголовок",
    "message": "Текст сообщения",
    "target": "all_inactive" | "error_users" | "drop_off_users" | "all"
  }
}

Верни массив JSON. Без текста, без markdown. Только JSON массив.`;

      const content = await this.ai.simpleChat(systemPrompt, context, {
        maxTokens: 1000, temperature: 0.5, timeout: 30_000,
      });

      let actions: any[] = [];
      try {
        const cleaned = content.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
        actions = JSON.parse(cleaned);
        if (!Array.isArray(actions)) actions = [actions];
      } catch {
        actions = [{ problem: 'AI вернул неструктурированный ответ', suggestion: content, severity: 'low', action: null }];
      }
      return { actions, context };
    } catch (e: any) {
      return { actions: [], context, error: e.message };
    }
  }

  /** Apply an AI-suggested action. */
  @Post('admin/ai-actions/apply')
  @UseGuards(AdminGuard)
  async applyAiAction(@Req() req: any, @Body() body: { action: any }) {
    const action = body.action;
    if (!action?.type) return { success: false, error: 'No action type' };

    let affected = 0;

    try {
      // Determine target users
      let userIds: number[] = [];
      if (action.target === 'all_inactive') {
        const { rows } = await this.pool.query(`
          SELECT DISTINCT user_id FROM user_events
          WHERE user_id NOT IN (
            SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - interval '24 hours'
          ) AND created_at >= now() - interval '30 days' LIMIT 100
        `).catch(() => ({ rows: [] }));
        userIds = rows.map((r: any) => r.user_id);
      } else if (action.target === 'error_users') {
        const { rows } = await this.pool.query(`
          SELECT DISTINCT user_id FROM user_events
          WHERE event LIKE '%error%' AND created_at >= now() - interval '7 days' LIMIT 100
        `).catch(() => ({ rows: [] }));
        userIds = rows.map((r: any) => r.user_id);
      } else if (action.target === 'drop_off_users') {
        const { rows } = await this.pool.query(`
          SELECT DISTINCT a.user_id FROM releases r
          JOIN artists a ON a.id = r.artist_id
          WHERE r.status = 'draft' AND r.created_at >= now() - interval '14 days' LIMIT 100
        `).catch(() => ({ rows: [] }));
        userIds = rows.map((r: any) => r.user_id);
      } else if (action.target === 'all') {
        const { rows } = await this.pool.query('SELECT id AS user_id FROM users LIMIT 500').catch(() => ({ rows: [] }));
        userIds = rows.map((r: any) => r.user_id);
      }

      if (action.type === 'notify' && userIds.length > 0) {
        const values = userIds.map((_, i) => `($${i * 4 + 1},$${i * 4 + 2},$${i * 4 + 3},$${i * 4 + 4})`).join(',');
        const params = userIds.flatMap(uid => [uid, action.title || 'Уведомление', action.message || '', 'ai']);
        try {
          await this.pool.query(`INSERT INTO notifications (user_id, title, message, type) VALUES ${values}`, params);
          affected = userIds.length;
        } catch { /* notifications table missing */ }
      } else if (action.type === 'create_ticket' && userIds.length > 0) {
        for (const uid of userIds.slice(0, 20)) {
          try {
            await this.pool.query(
              `INSERT INTO support_tickets (user_id, subject, message, priority) VALUES ($1,$2,$3,'medium')`,
              [uid, action.title || 'AI Тикет', action.message || ''],
            );
            affected++;
          } catch { /* support_tickets table missing */ }
        }
      }

      // Log the action
      try {
        await this.pool.query(
          `INSERT INTO admin_logs (admin_id, action, target_type, details)
           VALUES ($1, 'ai_action_applied', 'system', $2)`,
          [req.user.id, JSON.stringify({ action, affected })],
        );
      } catch { /* admin_logs table missing */ }

      return { success: true, affected };
    } catch (e: any) {
      return { success: false, error: e.message || 'Unknown error' };
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  SIGNALS — real-time business intelligence
  // ═══════════════════════════════════════════════════════════

  @Get('admin/dashboard/signals')
  @UseGuards(AdminGuard)
  async dashboardSignals() {
    const signals: { type: string; message: string; userId?: string; priority: string }[] = [];

    const queries = await Promise.all([
      // Users with 0 credits who were active recently
      this.pool.query(`
        SELECT u.id, u.email, COALESCE(b.credits, 0) AS credits
        FROM users u
        LEFT JOIN user_balance b ON b.user_id = u.id
        WHERE COALESCE(b.credits, 0) = 0
          AND u.id IN (SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - interval '3 days')
        ORDER BY u.created_at DESC LIMIT 10
      `).catch(() => ({ rows: [] })),

      // High activity users (>20 events in last 10 min)
      this.pool.query(`
        SELECT user_id, count(*)::int AS cnt
        FROM user_events
        WHERE created_at >= now() - interval '10 minutes'
        GROUP BY user_id HAVING count(*) > 20
        ORDER BY cnt DESC LIMIT 5
      `).catch(() => ({ rows: [] })),

      // New registrations in last 10 minutes
      this.pool.query(`
        SELECT id, email, created_at FROM users
        WHERE created_at >= now() - interval '10 minutes'
        ORDER BY created_at DESC LIMIT 5
      `).catch(() => ({ rows: [] })),

      // Users inactive 3+ days who were active before
      this.pool.query(`
        SELECT u.id, u.email, max(ue.created_at) AS last_active
        FROM users u
        JOIN user_events ue ON ue.user_id = u.id
        WHERE ue.created_at < now() - interval '3 days'
          AND u.id NOT IN (
            SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - interval '3 days'
          )
        GROUP BY u.id, u.email
        HAVING max(ue.created_at) >= now() - interval '30 days'
        ORDER BY max(ue.created_at) DESC LIMIT 10
      `).catch(() => ({ rows: [] })),

      // Monetization targets: active users with no subscription and low credits
      this.pool.query(`
        SELECT u.id, u.email, COALESCE(b.credits, 0) AS credits, COALESCE(p.plan, 'none') AS plan
        FROM users u
        LEFT JOIN user_balance b ON b.user_id = u.id
        LEFT JOIN profiles p ON p.user_id = u.id
        WHERE COALESCE(b.credits, 0) < 10
          AND (p.plan IS NULL OR p.plan = 'none' OR p.plan = 'start')
          AND u.id IN (SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - interval '7 days')
        ORDER BY u.created_at DESC LIMIT 10
      `).catch(() => ({ rows: [] })),

      // Fraud: suspicious patterns — many failed logins or rapid-fire events
      this.pool.query(`
        SELECT user_id, count(*)::int AS cnt, array_agg(DISTINCT event) AS events
        FROM user_events
        WHERE created_at >= now() - interval '1 hour'
        GROUP BY user_id HAVING count(*) > 50
        ORDER BY cnt DESC LIMIT 5
      `).catch(() => ({ rows: [] })),

      // Users who didn't complete onboarding (registered but no profile/releases)
      this.pool.query(`
        SELECT u.id, u.email, u.created_at
        FROM users u
        LEFT JOIN profiles p ON p.user_id = u.id
        LEFT JOIN artists a ON a.user_id = u.id
        LEFT JOIN releases r ON r.artist_id = a.id
        WHERE u.created_at >= now() - interval '14 days'
          AND p.user_id IS NULL
          AND r.id IS NULL
        ORDER BY u.created_at DESC LIMIT 10
      `).catch(() => ({ rows: [] })),
    ]);

    const [zeroCreds, highActivity, newRegs, inactive, monetize, fraud, noOnboarding] = queries;

    // Build signals
    for (const u of zeroCreds.rows) {
      signals.push({ type: 'money', message: `${u.email} — 0 кредитов, активен`, userId: String(u.id), priority: 'high' });
    }
    for (const u of highActivity.rows) {
      signals.push({ type: 'risk', message: `User #${u.user_id} — ${u.cnt} действий за 10 мин`, userId: String(u.user_id), priority: 'medium' });
    }
    for (const u of newRegs.rows) {
      signals.push({ type: 'growth', message: `Новая регистрация: ${u.email}`, userId: String(u.id), priority: 'low' });
    }
    for (const u of inactive.rows) {
      signals.push({ type: 'risk', message: `${u.email} — не заходил 3+ дней`, userId: String(u.id), priority: 'medium' });
    }
    for (const u of monetize.rows) {
      signals.push({ type: 'money', message: `${u.email} — ${u.credits} cr, план ${u.plan}, активен`, userId: String(u.id), priority: 'high' });
    }
    for (const u of fraud.rows) {
      signals.push({ type: 'risk', message: `User #${u.user_id} — ${u.cnt} событий/час (${(u.events || []).join(', ')})`, userId: String(u.user_id), priority: 'high' });
    }
    for (const u of noOnboarding.rows) {
      signals.push({ type: 'growth', message: `${u.email} — не завершил онбординг`, userId: String(u.id), priority: 'medium' });
    }

    // Sort: high first, then medium, then low
    const pOrder: Record<string, number> = { high: 0, medium: 1, low: 2 };
    signals.sort((a, b) => (pOrder[a.priority] ?? 2) - (pOrder[b.priority] ?? 2));

    return {
      signals,
      monetization_targets: monetize.rows,
      retention_targets: [...inactive.rows, ...noOnboarding.rows],
      fraud_alerts: fraud.rows,
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  USER ADMIN ACTIONS
  // ═══════════════════════════════════════════════════════════

  @Post('admin/users/:id/block')
  @UseGuards(AdminGuard)
  async blockUser(@Req() req: any) {
    try {
      const userId = req.params.id;
      await this.pool.query(
        "UPDATE profiles SET account_status = 'suspended' WHERE user_id = $1",
        [userId],
      );
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id)
         VALUES ($1, 'user_suspended', 'user', $2)`,
        [req.user.id, userId],
      );
      return { ok: true, status: 'suspended' };
    } catch (e: any) {
      return { ok: false, error: e.message || 'Failed to block user' };
    }
  }

  @Post('admin/users/:id/unblock')
  @UseGuards(AdminGuard)
  async unblockUser(@Req() req: any) {
    try {
      const userId = req.params.id;
      await this.pool.query(
        "UPDATE profiles SET account_status = 'active' WHERE user_id = $1",
        [userId],
      );
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id)
         VALUES ($1, 'user_activated', 'user', $2)`,
        [req.user.id, userId],
      );
      return { ok: true, status: 'active' };
    } catch (e: any) {
      return { ok: false, error: e.message || 'Failed to unblock user' };
    }
  }

  @Post('admin/users/:id/reset-limits')
  @UseGuards(AdminGuard)
  async resetLimits(@Req() req: any) {
    const userId = req.params.id;
    // Reset daily usage counters
    await this.pool.query(
      `UPDATE user_balance SET daily_used = 0, updated_at = now() WHERE user_id = $1`,
      [userId],
    ).catch(() => {});
    // Reset any rate limit flags
    await this.pool.query(
      `DELETE FROM user_events WHERE user_id = $1 AND event = 'rate_limited' AND created_at >= current_date`,
      [userId],
    ).catch(() => {});
    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id)
       VALUES ($1, 'limits_reset', 'user', $2)`,
      [req.user.id, userId],
    );
    return { ok: true };
  }
}
