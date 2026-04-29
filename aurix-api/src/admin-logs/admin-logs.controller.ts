import { Controller, Get, Post, Patch, Body, Query, Req, Param, Inject, UseGuards, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard, RolesGuard, userHasPermission } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { requireConfirmation } from '../auth/dangerous-action.util';
import { AdminLogsService } from './admin-logs.service';
import { SystemService } from '../system/system.service';
import { AiGatewayService } from '../ai/ai-gateway.service';
import { TBankService } from '../payments/tbank.service';
import { MailService } from '../mail/mail.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class AdminLogsController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly svc: AdminLogsService,
    private readonly systemService: SystemService,
    private readonly ai: AiGatewayService,
    private readonly tbank: TBankService,
    private readonly mail: MailService,
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
    const [user, profile, releases, tickets, lastLogin, recentActions] = await Promise.all([
      this.pool.query('SELECT id, email, created_at, verified, email_verified FROM users WHERE id = $1', [userId]).catch(() => ({ rows: [] })),
      this.pool.query('SELECT * FROM profiles WHERE user_id = $1', [userId]).catch(() => ({ rows: [] })),
      this.pool.query(`SELECT r.id, r.title, r.status, r.created_at
         FROM releases r JOIN artists a ON a.id = r.artist_id
         WHERE a.user_id = $1::int ORDER BY r.created_at DESC`, [userId]).catch(() => ({ rows: [] })),
      this.pool.query('SELECT id, subject, status, created_at FROM support_tickets WHERE user_id::text = $1::text ORDER BY created_at DESC', [userId]).catch(() => ({ rows: [] })),
      this.pool.query(`SELECT created_at FROM user_events WHERE user_id = $1::int AND event = 'login' ORDER BY created_at DESC LIMIT 1`, [userId]).catch(() => ({ rows: [] })),
      this.pool.query(`SELECT event, target_type, target_id, meta, created_at FROM user_events WHERE user_id = $1::int ORDER BY created_at DESC LIMIT 30`, [userId]).catch(() => ({ rows: [] })),
    ]);
    const userRow = user.rows[0] || null;
    if (userRow) {
      userRow.last_login = lastLogin.rows[0]?.created_at || null;
      userRow.email_verified = userRow.email_verified ?? userRow.verified ?? false;
    }
    return {
      user: userRow,
      profile: profile.rows[0] || null,
      releases: releases.rows,
      tickets: tickets.rows,
      recent_actions: recentActions.rows,
    };
  }

  /** AI-powered platform analysis using AI Gateway. */
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

  // ════════════════════════════════════════════════════════════════════
  //  AI ACTIONS: SAFETY LIMITS
  //  Жёсткие лимиты на массовые операции (применяются и в preview, и в apply).
  //  notify max 100, ticket max 500 (но per-iteration cap = 20),
  //  bonus max 200, email piggy-back на notify до 200.
  // ════════════════════════════════════════════════════════════════════
  private static readonly AI_ACTION_LIMITS: Record<string, number> = {
    notify: 100,
    create_ticket: 500,
    bonus: 200,
    email: 200,
  };

  /**
   * Внутренний хелпер: достаёт целевой список user_id под action.target,
   * с учётом лимита по типу. Используется и preview, и apply — поэтому
   * один источник правды.
   */
  private async resolveAiActionTargets(action: any): Promise<number[]> {
    const limit = AdminLogsController.AI_ACTION_LIMITS[action?.type] ?? 100;
    const target = action?.target;
    let userIds: number[] = [];
    if (target === 'all_inactive') {
      const { rows } = await this.pool.query(`
        SELECT DISTINCT user_id FROM user_events
        WHERE user_id NOT IN (
          SELECT DISTINCT user_id FROM user_events WHERE created_at >= now() - interval '24 hours'
        ) AND created_at >= now() - interval '30 days' LIMIT $1
      `, [limit]).catch(() => ({ rows: [] }));
      userIds = rows.map((r: any) => r.user_id);
    } else if (target === 'error_users') {
      const { rows } = await this.pool.query(`
        SELECT DISTINCT user_id FROM user_events
        WHERE event LIKE '%error%' AND created_at >= now() - interval '7 days' LIMIT $1
      `, [limit]).catch(() => ({ rows: [] }));
      userIds = rows.map((r: any) => r.user_id);
    } else if (target === 'drop_off_users') {
      const { rows } = await this.pool.query(`
        SELECT DISTINCT a.user_id FROM releases r
        JOIN artists a ON a.id = r.artist_id
        WHERE r.status = 'draft' AND r.created_at >= now() - interval '14 days' LIMIT $1
      `, [limit]).catch(() => ({ rows: [] }));
      userIds = rows.map((r: any) => r.user_id);
    } else if (target === 'all') {
      // Жёсткий потолок 500 для 'all' — даже если limit указывает больше.
      const cap = Math.min(limit, 500);
      const { rows } = await this.pool.query('SELECT id AS user_id FROM users LIMIT $1', [cap]).catch(() => ({ rows: [] }));
      userIds = rows.map((r: any) => r.user_id);
    }
    return userIds;
  }

  /**
   * AI ACTIONS — PREVIEW.
   *
   * Не выполняет действие. Возвращает что произошло бы:
   *   - count: сколько пользователей будет затронуто
   *   - sample_users: первые 5 для UI (email, id)
   *   - risk_level: low | medium | high
   *   - summary: человеко-читаемое описание на русском
   *
   * UI обязан показать preview перед apply (флоу: preview → confirm
   * dialog → apply). Без preview admin не должен видеть кнопку Apply.
   */
  @Post('admin/ai-actions/preview')
  @UseGuards(AdminGuard)
  async previewAiAction(@Body() body: { action: any }) {
    const action = body?.action;
    if (!action?.type) {
      throw new HttpException(
        { ok: false, error: 'invalid_action', message: 'Передайте action с полем type' },
        HttpStatus.BAD_REQUEST,
      );
    }

    const userIds = await this.resolveAiActionTargets(action);
    const count = userIds.length;
    const limit = AdminLogsController.AI_ACTION_LIMITS[action.type] ?? 100;

    // Выборка sample для отображения в диалоге подтверждения.
    let sample: Array<{ id: number; email: string }> = [];
    if (count > 0) {
      const sampleIds = userIds.slice(0, 5);
      const { rows } = await this.pool.query(
        `SELECT id, email FROM users WHERE id = ANY($1::int[])`,
        [sampleIds],
      ).catch(() => ({ rows: [] }));
      sample = rows.map((r: any) => ({ id: r.id, email: r.email }));
    }

    // Risk level — наивная эвристика по количеству и типу.
    // high: массовая email/notify (50+), либо action на 'all'
    // medium: 10-49 пользователей или ticket-создание
    // low: 1-9 пользователей
    let risk: 'low' | 'medium' | 'high' = 'low';
    if (action.target === 'all' || count >= 50) risk = 'high';
    else if (count >= 10 || action.type === 'create_ticket') risk = 'medium';

    const targetLabel: Record<string, string> = {
      all_inactive: 'неактивных пользователей (нет входа > 24 ч)',
      error_users: 'пользователей с ошибками за 7 дней',
      drop_off_users: 'пользователей с незаконченными релизами (14 дней)',
      all: 'ВСЕХ пользователей платформы',
    };
    const typeLabel: Record<string, string> = {
      notify: 'отправит push-уведомление и email',
      create_ticket: 'создаст support-тикет',
      bonus: 'начислит бонус',
      email: 'отправит email',
    };

    const summary = `Действие ${typeLabel[action.type] ?? action.type} ` +
      `для ${count} ${targetLabel[action.target] ?? action.target ?? 'пользователей'}. ` +
      `Лимит: ${limit}. Уровень риска: ${risk.toUpperCase()}.`;

    return {
      ok: true,
      count,
      limit,
      risk_level: risk,
      summary,
      sample_users: sample,
      action_type: action.type,
      target: action.target,
    };
  }

  /**
   * AI ACTIONS — APPLY.
   *
   * Выполняет действие. Требует confirmed=true и reason >= 5 символов
   * (защита от случайного клика). Жёсткие лимиты применяются на уровне
   * resolveAiActionTargets. Все вызовы пишутся в admin_logs с reason.
   */
  @Post('admin/ai-actions/apply')
  @UseGuards(AdminGuard)
  async applyAiAction(
    @Req() req: any,
    @Body() body: { action: any; confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: confirmed + reason обязательны. UI должен сначала вызвать
    // /admin/ai-actions/preview и показать диалог.
    const reason = requireConfirmation(body);

    const action = body.action;
    if (!action?.type) {
      throw new HttpException(
        { ok: false, error: 'invalid_action', message: 'Action не задан' },
        HttpStatus.BAD_REQUEST,
      );
    }

    let affected = 0;

    try {
      const userIds = await this.resolveAiActionTargets(action);

      if (action.type === 'notify' && userIds.length > 0) {
        const values = userIds.map((_, i) => `($${i * 4 + 1},$${i * 4 + 2},$${i * 4 + 3},$${i * 4 + 4})`).join(',');
        const params = userIds.flatMap(uid => [uid, action.title || 'Уведомление', action.message || '', 'ai']);
        try {
          await this.pool.query(`INSERT INTO notifications (user_id, title, message, type) VALUES ${values}`, params);
          affected = userIds.length;
        } catch { /* notifications table missing */ }

        // Email fan-out — лимит 200 (см. AI_ACTION_LIMITS.email).
        try {
          const emailLimit = AdminLogsController.AI_ACTION_LIMITS.email;
          const { rows: emailRows } = await this.pool.query(
            `SELECT email FROM users WHERE id = ANY($1::int[]) AND email IS NOT NULL`,
            [userIds.slice(0, emailLimit)],
          );
          const title = action.title || 'Уведомление AURIX';
          const message = action.message || '';
          let mailed = 0;
          await Promise.all(
            emailRows.map((r: any) =>
              this.mail
                .sendAdminMessage(r.email, title, message)
                .then((res) => { if (res.success) mailed++; })
                .catch(() => {}),
            ),
          );
          (action as any)._emails_sent = mailed;
        } catch { /* SMTP unavailable */ }
      } else if (action.type === 'create_ticket' && userIds.length > 0) {
        // Per-iteration cap — медленный insert, не хотим зависнуть на 500 тикетах.
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

      // Audit log с reason — критично для разбора post-incident.
      try {
        await this.pool.query(
          `INSERT INTO admin_logs (admin_id, action, target_type, details)
           VALUES ($1, 'ai_action_applied', 'system', $2)`,
          [req.user.id, JSON.stringify({ action, affected, reason })],
        );
      } catch { /* admin_logs table missing */ }

      return {
        success: true,
        affected,
        emails_sent: (action as any)._emails_sent ?? 0,
      };
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
  //  USER AI STUDIO MESSAGES (admin view)
  // ═══════════════════════════════════════════════════════════

  @Get('admin/users/:id/ai-messages')
  @UseGuards(AdminGuard)
  async userAiMessages(@Req() req: any, @Query('limit') limit?: string) {
    const userId = req.params.id;
    const lim = +(limit || 200);
    const { rows } = await this.pool.query(
      'SELECT id, role, content, meta, created_at FROM ai_studio_messages WHERE user_id=$1 ORDER BY created_at ASC LIMIT $2',
      [userId, lim],
    );
    return rows;
  }

  // ═══════════════════════════════════════════════════════════
  //  USER ADMIN ACTIONS
  // ═══════════════════════════════════════════════════════════

  @Post('admin/users/:id/block')
  @UseGuards(AdminGuard)
  async blockUser(
    @Req() req: any,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: требуем явное confirmed + reason >= 5 символов.
    // 400 при отсутствии — UI обязан показать диалог подтверждения.
    const reason = requireConfirmation(body);
    try {
      const userId = req.params.id;
      await this.pool.query(
        "UPDATE profiles SET account_status = 'suspended' WHERE user_id = $1",
        [userId],
      );
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
         VALUES ($1, 'user_suspended', 'user', $2, $3)`,
        [req.user.id, userId, JSON.stringify({ reason })],
      );
      return { ok: true, status: 'suspended' };
    } catch (e: any) {
      return { ok: false, error: e.message || 'Failed to block user' };
    }
  }

  @Post('admin/users/:id/unblock')
  @UseGuards(AdminGuard)
  async unblockUser(
    @Req() req: any,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: разблокировка тоже опасное действие — нужно зафиксировать
    // обоснование (особенно если был активный фрод-кейс).
    const reason = requireConfirmation(body);
    try {
      const userId = req.params.id;
      await this.pool.query(
        "UPDATE profiles SET account_status = 'active' WHERE user_id = $1",
        [userId],
      );
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
         VALUES ($1, 'user_activated', 'user', $2, $3)`,
        [req.user.id, userId, JSON.stringify({ reason })],
      );
      return { ok: true, status: 'active' };
    } catch (e: any) {
      return { ok: false, error: e.message || 'Failed to unblock user' };
    }
  }

  @Post('admin/users/:id/reset-limits')
  @UseGuards(AdminGuard)
  async resetLimits(
    @Req() req: any,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: сброс дневных лимитов даёт юзеру свободу спама.
    const reason = requireConfirmation(body);
    const userId = req.params.id;
    await this.pool.query(
      `UPDATE user_balance SET daily_used = 0, updated_at = now() WHERE user_id = $1`,
      [userId],
    ).catch(() => {});
    await this.pool.query(
      `DELETE FROM user_events WHERE user_id = $1 AND event = 'rate_limited' AND created_at >= current_date`,
      [userId],
    ).catch(() => {});
    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'limits_reset', 'user', $2, $3)`,
      [req.user.id, userId, JSON.stringify({ reason })],
    );
    return { ok: true };
  }

  // ═══════════════════════════════════════════════════════════
  //  KILL SESSIONS — revoke refresh tokens + close active sessions
  // ═══════════════════════════════════════════════════════════

  @Post('admin/users/:id/kill-sessions')
  @UseGuards(AdminGuard)
  async killSessions(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: пользователь будет выкинут со всех устройств. Требуем reason.
    const reason = requireConfirmation(body);
    const userId = Number(id);
    if (!Number.isFinite(userId) || userId <= 0) {
      throw new HttpException('Invalid user id', HttpStatus.BAD_REQUEST);
    }

    const { rowCount: revokedTokens } = await this.pool.query(
      `DELETE FROM refresh_tokens WHERE user_id = $1`,
      [userId],
    );

    const { rowCount: closedSessions } = await this.pool.query(
      `UPDATE user_sessions
          SET ended_at = now(),
              duration_s = COALESCE(duration_s, EXTRACT(EPOCH FROM (now() - started_at))::int)
        WHERE user_id = $1 AND ended_at IS NULL`,
      [userId],
    );

    await this.pool.query(
      `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
       VALUES ($1, 'sessions_killed', 'user', $2, $3)`,
      [req.user.id, userId, JSON.stringify({ reason, revoked_tokens: revokedTokens, closed_sessions: closedSessions })],
    );

    return {
      ok: true,
      revoked_tokens: revokedTokens ?? 0,
      closed_sessions: closedSessions ?? 0,
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  EDIT USER — profile fields (name, email, phone, plan, role, sub status)
  // ═══════════════════════════════════════════════════════════

  @Patch('admin/users/:id')
  @UseGuards(AdminGuard)
  async editUser(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: {
      name?: string;
      email?: string;
      phone?: string;
      plan?: string;
      role?: string;
      subscriptionStatus?: string;
      // Только для смены роли:
      confirmed?: boolean;
      reason?: string;
    },
  ) {
    const userId = Number(id);
    if (!Number.isFinite(userId) || userId <= 0) {
      throw new HttpException('Invalid user id', HttpStatus.BAD_REQUEST);
    }

    const name = trimOrNull(body.name);
    const email = trimOrNull(body.email);
    const phone = trimOrNull(body.phone);
    const plan = trimOrNull(body.plan);
    const role = trimOrNull(body.role);
    const subStatus = trimOrNull(body.subscriptionStatus);

    // Расширенная валидация ролей. Включает все 8 ролей новой модели.
    const ALLOWED_ROLES = [
      'user', 'artist', 'support', 'moderator', 'analyst',
      'finance_admin', 'admin', 'super_admin',
    ];
    if (role && !ALLOWED_ROLES.includes(role)) {
      throw new HttpException('Invalid role', HttpStatus.BAD_REQUEST);
    }
    if (plan && !['free', 'start', 'breakthrough', 'empire'].includes(plan)) {
      throw new HttpException('Invalid plan', HttpStatus.BAD_REQUEST);
    }
    if (subStatus && !['none', 'active', 'trial', 'expired', 'canceled'].includes(subStatus)) {
      throw new HttpException('Invalid subscriptionStatus', HttpStatus.BAD_REQUEST);
    }
    if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpException('Invalid email', HttpStatus.BAD_REQUEST);
    }

    // ════════════════════════════════════════════════════════════════
    // SAFETY: ограничения на смену роли.
    // 1) только super_admin может менять role
    // 2) admin не может выдать admin/super_admin
    // 3) admin не может изменить свою собственную роль
    // 4) обязательны confirmed=true и reason >= 5 символов
    // 5) лог пишется в role_change_log + admin_logs
    // ════════════════════════════════════════════════════════════════
    let roleChangeReason: string | null = null;
    let oldRole: string | null = null;
    if (role) {
      const actorRole = (req.user.role || '').toString();
      if (actorRole !== 'super_admin') {
        throw new HttpException(
          { ok: false, error: 'role_change_forbidden', message: 'Только super_admin может менять роли пользователей' },
          HttpStatus.FORBIDDEN,
        );
      }
      if (Number(req.user.id) === userId) {
        // Защита от самовозвышения/самопонижения.
        throw new HttpException(
          { ok: false, error: 'self_role_change_forbidden', message: 'Нельзя менять свою собственную роль' },
          HttpStatus.FORBIDDEN,
        );
      }
      // Confirm + reason обязательны для смены роли.
      roleChangeReason = requireConfirmation({
        confirmed: body.confirmed,
        reason: body.reason,
      });
      // Запоминаем старую роль для role_change_log.
      const { rows: oldRows } = await this.pool.query(
        `SELECT role FROM users WHERE id = $1`,
        [userId],
      );
      oldRole = oldRows[0]?.role ?? null;
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Email must remain unique across users
      if (email) {
        const { rows: existing } = await client.query(
          `SELECT id FROM users WHERE email = $1 AND id <> $2 LIMIT 1`,
          [email, userId],
        );
        if (existing.length) {
          await client.query('ROLLBACK');
          throw new HttpException('Email already used by another user', HttpStatus.CONFLICT);
        }
      }

      // users table: email, name, role
      const userUpd: string[] = [];
      const userVals: any[] = [];
      if (email) { userVals.push(email); userUpd.push(`email = $${userVals.length}`); }
      if (name !== null) { userVals.push(name); userUpd.push(`name = $${userVals.length}`); }
      if (role) { userVals.push(role); userUpd.push(`role = $${userVals.length}`); }
      if (userUpd.length) {
        userVals.push(userId);
        await client.query(`UPDATE users SET ${userUpd.join(', ')} WHERE id = $${userVals.length}`, userVals);
      }

      // profiles table: display_name, phone, role, plan, plan_id, subscription_status
      const profUpd: string[] = [];
      const profVals: any[] = [];
      if (name !== null) { profVals.push(name); profUpd.push(`display_name = $${profVals.length}`); }
      if (phone !== null) { profVals.push(phone); profUpd.push(`phone = $${profVals.length}`); }
      if (role) { profVals.push(role); profUpd.push(`role = $${profVals.length}`); }
      if (plan) {
        profVals.push(plan); profUpd.push(`plan = $${profVals.length}`);
        profVals.push(plan); profUpd.push(`plan_id = $${profVals.length}`);
      }
      if (subStatus) { profVals.push(subStatus); profUpd.push(`subscription_status = $${profVals.length}`); }

      if (profUpd.length) {
        profVals.push(userId);
        await client.query(
          `UPDATE profiles SET ${profUpd.join(', ')}, updated_at = now() WHERE user_id = $${profVals.length}`,
          profVals,
        );
      }

      await client.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
         VALUES ($1, 'user_edited', 'user', $2, $3)`,
        [req.user.id, userId, JSON.stringify({
          fields: { name, email, phone, plan, role, subStatus },
          // reason пишется только если была смена роли — для остальных полей
          // не требуем, чтобы не сломать ежедневные правки CRM-полей.
          reason: roleChangeReason,
        })],
      );

      // Отдельный audit на смену роли — для быстрого аудита без grep по details.
      if (role && roleChangeReason) {
        await client.query(
          `INSERT INTO role_change_log (changed_by, target_user, old_role, new_role, reason)
           VALUES ($1, $2, $3, $4, $5)`,
          [req.user.id, userId, oldRole, role, roleChangeReason],
        ).catch(() => {
          // Если миграция role_change_log ещё не накатана — не падаем.
        });
      }

      await client.query('COMMIT');
      return { ok: true };
    } catch (e: any) {
      await client.query('ROLLBACK').catch(() => {});
      if (e instanceof HttpException) throw e;
      throw new HttpException(e.message || 'Update failed', HttpStatus.INTERNAL_SERVER_ERROR);
    } finally {
      client.release();
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  REFUND — cancel a confirmed T-Bank payment
  // ═══════════════════════════════════════════════════════════

  // Refund доступен finance_admin (специализированная роль) + admin + super_admin.
  // RolesGuard проверяет роль из БД. AdminGuard заменён на RolesGuard, потому
  // что finance_admin не входит в admin/super_admin allow-list AdminGuard'а.
  @Post('admin/payments/:id/refund')
  @UseGuards(RolesGuard)
  @Roles('finance_admin', 'admin')
  async refundPayment(
    @Req() req: any,
    @Param('id') id: string,
    @Body() body: { confirmed?: boolean; reason?: string },
  ) {
    // SAFETY: возврат денег — необратимая финансовая операция.
    // Обязательно confirmed + reason >= 5 символов.
    const reason = requireConfirmation(body);
    // Тонкая проверка permission — refund доступен finance_admin/admin/super_admin
    // (super_admin неявно через userHasPermission). Если у роли нет этого
    // permission — 403 даже если AdminGuard пропустил.
    const hasPerm = await userHasPermission(this.pool, req.user.id, 'admin.payments.refund');
    if (!hasPerm) {
      throw new HttpException(
        { ok: false, error: 'permission_denied', message: 'Нужен permission admin.payments.refund' },
        HttpStatus.FORBIDDEN,
      );
    }
    const paymentId = Number(id);
    if (!Number.isFinite(paymentId) || paymentId <= 0) {
      throw new HttpException('Invalid payment id', HttpStatus.BAD_REQUEST);
    }

    const result = await this.tbank.refundPayment(paymentId, req.user.id, reason);
    return result.ok
      ? { ok: true, newStatus: result.newStatus }
      : { ok: false, error: result.error };
  }
}

function trimOrNull(v: string | undefined): string | null {
  if (v == null) return null;
  const t = String(v).trim();
  return t.length ? t : null;
}
