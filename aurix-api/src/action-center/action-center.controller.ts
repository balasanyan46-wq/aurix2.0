import {
  Controller,
  Get,
  Inject,
  UseGuards,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { LeadScoringService } from '../lead-scoring/lead-scoring.service';
import { LeadsService } from '../leads/leads.service';
import { NextActionService } from '../next-action/next-action.service';
import { AiSalesService } from '../ai-sales/ai-sales.service';

/**
 * Action Center — единый "что делать сегодня" feed.
 *
 * Объединяет 8 категорий задач в один список с приоритетами:
 *   - hot_leads               (готовы покупать)
 *   - failed_payments         (ошибка оплаты)
 *   - stuck_releases          (релиз на модерации > 3 дней)
 *   - urgent_tickets          (open тикеты > 24 ч)
 *   - inactive_users          (давно не заходил)
 *   - ai_risk_flags           (подозрительная активность)
 *   - deletion_requests       (запрос на удаление профиля)
 *   - users_with_0_credits    (платный план но 0 кредитов)
 *
 * Каждый item: { id, type, priority, title, description, user_id?,
 *               suggested_action, created_at, source }
 */
// Action Center видят все sales-roles: support отвечает на тикеты,
// moderator модерирует релизы, analyst смотрит метрики.
@UseGuards(JwtAuthGuard, AdminGuard)
@Roles('support', 'moderator', 'analyst', 'admin', 'finance_admin')
@Controller()
export class ActionCenterController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly leadService: LeadScoringService,
    private readonly leads: LeadsService,
    private readonly nextAction: NextActionService,
    private readonly aiSales: AiSalesService,
  ) {}

  @Get('admin/action-center')
  async actionCenter() {
    const items: ActionItem[] = [];

    // Параллельно: 11 источников. Каждый ловит ошибки сам.
    const [
      hotLeadsFromPipeline,
      hotLeadsFromScore,
      failedPayments,
      stuckReleases,
      urgentTickets,
      inactiveUsers,
      riskFlags,
      deletionRequests,
      zeroCreditsPaid,
      usersWithNextAction,
      aiSalesHigh,
    ] = await Promise.all([
      this.fetchHotLeadsFromPipeline(),
      this.fetchHotLeads(),
      this.fetchFailedPayments(),
      this.fetchStuckReleases(),
      this.fetchUrgentTickets(),
      this.fetchInactiveUsers(),
      this.fetchRiskFlags(),
      this.fetchDeletionRequests(),
      this.fetchZeroCreditsPaid(),
      this.fetchUsersWithNextAction(),
      this.fetchAiSalesSignalsHigh(),
    ]);

    items.push(...hotLeadsFromPipeline);
    items.push(...hotLeadsFromScore);
    items.push(...failedPayments);
    items.push(...stuckReleases);
    items.push(...urgentTickets);
    items.push(...inactiveUsers);
    items.push(...riskFlags);
    items.push(...deletionRequests);
    items.push(...zeroCreditsPaid);
    items.push(...usersWithNextAction);
    items.push(...aiSalesHigh);

    // Дедуп по (type, user_id) — разные источники могут вернуть одного юзера.
    const seen = new Set<string>();
    const deduped = items.filter(i => {
      const key = `${i.type}:${i.user_id ?? i.id}`;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });

    // Сортируем: critical → high → medium → low; внутри — по possible_revenue desc.
    const order: Record<string, number> = { critical: 0, high: 1, medium: 2, low: 3 };
    deduped.sort((a, b) => {
      const p = (order[a.priority] ?? 9) - (order[b.priority] ?? 9);
      if (p !== 0) return p;
      return (b.possible_revenue ?? 0) - (a.possible_revenue ?? 0);
    });

    const groups = {
      urgent: deduped.filter(i => i.priority === 'critical'),
      money: deduped.filter(i =>
        i.type === 'failed_payment' ||
        i.type === 'zero_credits_paid' ||
        i.type === 'hot_lead' ||
        i.type === 'hot_lead_pipeline' ||
        i.type === 'ai_sales_signal' ||
        i.type === 'next_action'
      ),
      releases: deduped.filter(i => i.type === 'stuck_release'),
      support: deduped.filter(i => i.type === 'urgent_ticket' || i.type === 'deletion_request'),
      retention: deduped.filter(i => i.type === 'inactive_user'),
      risks: deduped.filter(i => i.type === 'ai_risk_flag'),
    };

    // Сумма потенциального дохода — UI показывает в заголовке, чтобы
    // менеджер видел "сколько денег можно собрать сегодня".
    const possibleRevenueTotal = deduped.reduce(
      (s, i) => s + (i.possible_revenue ?? 0),
      0,
    );

    return {
      ok: true,
      total: deduped.length,
      possible_revenue_total: possibleRevenueTotal,
      items: deduped,
      groups,
      generated_at: new Date().toISOString(),
    };
  }

  // ────────────────────────────────────────────────────────────────────
  //  Источники данных
  // ────────────────────────────────────────────────────────────────────

  private async fetchHotLeads(): Promise<ActionItem[]> {
    // Hot lead = lead_bucket='hot'. Берём топ-10 по score.
    const items = await this.leadService.listByBucket('hot', 10).catch(() => []);
    return items.map((u: any) => ({
      id: `hot_lead:${u.user_id}`,
      type: 'hot_lead',
      priority: 'high' as Priority,
      title: `Готов купить: ${u.email}`,
      description: `Score ${u.lead_score}, план ${u.plan ?? 'free'}, ${u.subscription_status ?? 'no sub'}`,
      user_id: u.user_id,
      suggested_action: 'send_offer',
      created_at: u.score_updated_at ?? new Date().toISOString(),
      source: 'lead_scoring',
    }));
  }

  private async fetchFailedPayments(): Promise<ActionItem[]> {
    const { rows } = await this.pool.query(`
      SELECT p.id, p.user_id, p.amount, p.plan, p.created_at, u.email
      FROM payments p
      LEFT JOIN users u ON u.id = p.user_id
      WHERE p.status = 'failed' AND p.created_at >= now() - interval '14 days'
      ORDER BY p.created_at DESC LIMIT 20
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `failed_payment:${r.id}`,
      type: 'failed_payment',
      priority: 'critical' as Priority,
      title: `Ошибка оплаты: ${r.email ?? `user#${r.user_id}`}`,
      description: `${(r.amount / 100).toFixed(2)} ₽ за план ${r.plan}`,
      user_id: r.user_id,
      suggested_action: 'contact_user',
      created_at: r.created_at,
      source: 'payments',
    }));
  }

  private async fetchStuckReleases(): Promise<ActionItem[]> {
    // Stuck = в review/submitted/approved более 3 дней.
    const { rows } = await this.pool.query(`
      SELECT r.id, r.title, r.status, r.created_at, a.user_id, u.email
      FROM releases r
      LEFT JOIN artists a ON a.id = r.artist_id
      LEFT JOIN users u ON u.id = a.user_id
      WHERE r.status IN ('submitted', 'in_review', 'approved')
        AND r.created_at < now() - interval '3 days'
      ORDER BY r.created_at ASC LIMIT 20
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `stuck_release:${r.id}`,
      type: 'stuck_release',
      priority: 'high' as Priority,
      title: `Релиз завис: «${r.title}»`,
      description: `Статус ${r.status}, висит с ${new Date(r.created_at).toLocaleDateString('ru')}`,
      user_id: r.user_id,
      suggested_action: 'review_release',
      created_at: r.created_at,
      source: 'releases',
    }));
  }

  private async fetchUrgentTickets(): Promise<ActionItem[]> {
    const { rows } = await this.pool.query(`
      SELECT t.id, t.subject, t.user_id, t.created_at, u.email
      FROM support_tickets t
      LEFT JOIN users u ON u.id::text = t.user_id::text
      WHERE t.status = 'open' AND t.created_at < now() - interval '24 hours'
      ORDER BY t.created_at ASC LIMIT 20
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `urgent_ticket:${r.id}`,
      type: 'urgent_ticket',
      priority: 'critical' as Priority,
      title: `Тикет > 24 ч: ${r.subject}`,
      description: `От ${r.email ?? `user#${r.user_id}`}`,
      user_id: r.user_id,
      suggested_action: 'reply_ticket',
      created_at: r.created_at,
      source: 'support_tickets',
    }));
  }

  private async fetchInactiveUsers(): Promise<ActionItem[]> {
    // Юзеры с подпиской, которые не заходили 14+ дней — risk of churn.
    const { rows } = await this.pool.query(`
      SELECT u.id, u.email, max(ue.created_at) AS last_active, p.plan
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      LEFT JOIN user_events ue ON ue.user_id = u.id
      WHERE p.plan IN ('start', 'breakthrough', 'empire')
        AND p.subscription_status = 'active'
      GROUP BY u.id, u.email, p.plan
      HAVING max(ue.created_at) < now() - interval '14 days'
         AND max(ue.created_at) >= now() - interval '60 days'
      ORDER BY max(ue.created_at) ASC LIMIT 15
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `inactive:${r.id}`,
      type: 'inactive_user',
      priority: 'medium' as Priority,
      title: `Не заходил 14+ дней: ${r.email}`,
      description: `План ${r.plan}, последний вход ${r.last_active ? new Date(r.last_active).toLocaleDateString('ru') : '—'}`,
      user_id: r.id,
      suggested_action: 'send_retention',
      created_at: r.last_active ?? new Date().toISOString(),
      source: 'user_events',
    }));
  }

  private async fetchRiskFlags(): Promise<ActionItem[]> {
    // Подозрительная активность — резкие всплески.
    const { rows } = await this.pool.query(`
      SELECT user_id, count(*)::int AS cnt, array_agg(DISTINCT event) AS events
      FROM user_events
      WHERE created_at >= now() - interval '1 hour'
      GROUP BY user_id HAVING count(*) > 50
      ORDER BY cnt DESC LIMIT 5
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `risk:${r.user_id}`,
      type: 'ai_risk_flag',
      priority: 'high' as Priority,
      title: `Подозрительная активность user#${r.user_id}`,
      description: `${r.cnt} событий за час: ${(r.events || []).slice(0, 5).join(', ')}`,
      user_id: r.user_id,
      suggested_action: 'review_activity',
      created_at: new Date().toISOString(),
      source: 'fraud_detection',
    }));
  }

  private async fetchDeletionRequests(): Promise<ActionItem[]> {
    const { rows } = await this.pool.query(`
      SELECT id, user_id, created_at, reason
      FROM release_delete_requests
      WHERE status = 'pending'
      ORDER BY created_at ASC LIMIT 20
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `delete_req:${r.id}`,
      type: 'deletion_request',
      priority: 'medium' as Priority,
      title: `Запрос на удаление #${r.id}`,
      description: r.reason ?? 'Без причины',
      user_id: r.user_id,
      suggested_action: 'review_deletion',
      created_at: r.created_at,
      source: 'release_delete_requests',
    }));
  }

  private async fetchZeroCreditsPaid(): Promise<ActionItem[]> {
    // Платные юзеры с 0 кредитов — должна сработать автопополнение или
    // явная коммуникация (UX-проблема: заплатил, но не понимает почему пусто).
    const { rows } = await this.pool.query(`
      SELECT u.id, u.email, p.plan, COALESCE(b.credits, 0) AS credits
      FROM users u
      JOIN profiles p ON p.user_id = u.id
      LEFT JOIN user_balance b ON b.user_id = u.id
      WHERE p.plan IN ('start', 'breakthrough', 'empire')
        AND p.subscription_status = 'active'
        AND COALESCE(b.credits, 0) = 0
      ORDER BY u.id DESC LIMIT 10
    `).catch(() => ({ rows: [] }));
    return rows.map((r: any) => ({
      id: `zero_credits_paid:${r.id}`,
      type: 'zero_credits_paid',
      priority: 'high' as Priority,
      title: `Платный юзер с 0 кредитов: ${r.email}`,
      description: `План ${r.plan}, кредиты: 0`,
      user_id: r.id,
      suggested_action: 'top_up_or_explain',
      created_at: new Date().toISOString(),
      source: 'user_balance',
    }));
  }

  // ────────────────────────────────────────────────────────────────────
  //  Источники этапа 5 — интеграция с leads + next_action + ai_sales
  // ────────────────────────────────────────────────────────────────────

  /**
   * Hot leads из таблицы `leads` (новая pipeline). Это уже отслеживаемые
   * лиды со статусом — отличается от fetchHotLeads (который читает
   * profiles.lead_bucket напрямую). Источник правды для менеджера.
   */
  private async fetchHotLeadsFromPipeline(): Promise<ActionItem[]> {
    const items = await this.leads.list({
      bucket: 'hot',
      limit: 15,
    }).catch(() => [] as any[]);
    return (items as any[])
      .filter((l: any) => l.status !== 'converted' && l.status !== 'lost')
      .map((l: any) => ({
        id: `hot_lead_pipeline:${l.id}`,
        type: 'hot_lead_pipeline',
        priority: 'high' as Priority,
        title: `Hot lead: ${l.email ?? `user#${l.user_id}`}`,
        description: `Score ${l.lead_score}, статус ${l.status}` +
          (l.assigned_to ? `, назначен admin#${l.assigned_to}` : ', без менеджера') +
          (l.next_action ? ` · ${l.next_action}` : ''),
        user_id: l.user_id,
        suggested_action: 'contact_lead',
        next_action: l.next_action,
        possible_revenue: 5000, // дефолт для hot lead'а; точнее посчитает next_action
        created_at: l.updated_at ?? new Date().toISOString(),
        source: 'leads_pipeline',
      }));
  }

  /**
   * Юзеры с прописанным next_action (любого приоритета). Помогает менеджеру
   * сосредоточиться на конкретных шагах вместо общих сигналов.
   */
  private async fetchUsersWithNextAction(): Promise<ActionItem[]> {
    const { rows } = await this.pool.query(`
      SELECT l.id AS lead_id, l.user_id, l.next_action, l.status, l.lead_score,
             u.email
        FROM leads l
        LEFT JOIN users u ON u.id = l.user_id
       WHERE l.next_action IS NOT NULL
         AND l.next_action <> ''
         AND l.status NOT IN ('converted', 'lost')
       ORDER BY l.lead_score DESC, l.updated_at DESC
       LIMIT 20
    `).catch(() => ({ rows: [] }));

    // Для каждого подкачаем suggested_message и possible_revenue из NextActionService.
    const out: ActionItem[] = [];
    for (const r of rows as any[]) {
      const next = await this.nextAction.getNextAction(r.user_id).catch(() => null);
      out.push({
        id: `next_action:${r.lead_id}`,
        type: 'next_action',
        priority: r.lead_score > 70 ? 'high' as Priority : 'medium' as Priority,
        title: r.next_action,
        description: `${r.email ?? `user#${r.user_id}`} · score ${r.lead_score}`,
        user_id: r.user_id,
        suggested_action: 'execute_next_action',
        next_action: r.next_action,
        suggested_message: next?.suggested_message ?? null,
        possible_revenue: next?.possible_revenue ?? 0,
        // A/B template attribution — нужно пробросить дальше в meta.offer_sent.
        template_code: next?.template_code ?? null,
        template_variant: next?.template_variant ?? null,
        created_at: new Date().toISOString(),
        source: 'next_action_engine',
      });
    }
    return out;
  }

  /**
   * AI sales signals = high. Источник: ai_sales_signals (свежие за 7 дней).
   * Эти сигналы дают конкретный product_offer — используется UI для
   * формирования preset offer'ов.
   */
  private async fetchAiSalesSignalsHigh(): Promise<ActionItem[]> {
    const items = await this.aiSales.listHighSignalUsers(15).catch(() => []);
    return items.map((s: any) => ({
      id: `ai_sales:${s.user_id}`,
      type: 'ai_sales_signal',
      priority: 'high' as Priority,
      title: `AI: ${s.email ?? `user#${s.user_id}`} готов купить`,
      description: s.insight || s.recommendation || 'Высокий sales signal',
      user_id: s.user_id,
      suggested_action: s.suggested_action || 'send_offer',
      suggested_message: s.recommendation,
      product_offer: s.product_offer,
      // Грубая оценка по product_offer.
      possible_revenue: s.product_offer === 'promotion' ? 20000
        : s.product_offer === 'distribution' ? 5000
        : s.product_offer === 'analysis_pro' ? 990
        : 3000,
      created_at: s.created_at ?? new Date().toISOString(),
      source: 'ai_sales_signals',
    }));
  }
}

// ──────────────────────────────────────────────────────────────────────
//  Типы
// ──────────────────────────────────────────────────────────────────────

type Priority = 'low' | 'medium' | 'high' | 'critical';

interface ActionItem {
  id: string;
  type: string;
  priority: Priority;
  title: string;
  description: string;
  user_id?: number;
  suggested_action: string;
  // Этап 5: интеграция с next-action engine и sales signals.
  next_action?: string | null;
  suggested_message?: string | null;
  possible_revenue?: number;
  product_offer?: string | null;
  // A/B template attribution — для трекинга которая версия текста сработала.
  template_code?: string | null;
  template_variant?: string | null;
  created_at: string;
  source: string;
}
