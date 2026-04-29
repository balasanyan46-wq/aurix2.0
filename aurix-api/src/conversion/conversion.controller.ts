import { Controller, Get, Inject, UseGuards } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { AdminGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';

/**
 * Conversion Tracking — артистическая воронка с деньгами.
 *
 * Источник: view `v_conversion_funnel` (миграция 091).
 *
 * Возвращает по каждому шагу:
 *   - users_count          — уникальных юзеров
 *   - conversion_pct       — % от предыдущего шага
 *   - drop_off_pct         — % отвалившихся на этом шаге
 *   - revenue_generated    — суммарный revenue юзеров, дошедших сюда (₽)
 */
// Read-only аналитика — доступ: analyst, admin, finance_admin.
@UseGuards(JwtAuthGuard, AdminGuard)
@Roles('analyst', 'admin', 'finance_admin')
@Controller()
export class ConversionController {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  @Get('admin/conversion')
  async funnel() {
    // 1) Counts по шагам.
    const { rows } = await this.pool.query(`SELECT * FROM v_conversion_funnel`)
      .catch(() => ({ rows: [{}] as any[] }));
    const f = rows[0] ?? {};

    const counts = {
      register: Number(f.step1_register ?? 0),
      track_uploaded: Number(f.step2_track_uploaded ?? 0),
      ai_chat: Number(f.step3_ai_chat ?? 0),
      release_created: Number(f.step4_release_created ?? 0),
      payment: Number(f.step5_payment ?? 0),
      repeat: Number(f.step6_repeat ?? 0),
    };
    const totalRevenueKopecks = Number(f.total_revenue_kopecks ?? 0);

    // 2) Revenue по шагам (сколько денег у юзеров, дошедших до шага).
    const { rows: revRows } = await this.pool.query(
      `SELECT step, revenue_kopecks FROM v_conversion_revenue_by_step`,
    ).catch(() => ({ rows: [] as any[] }));
    const revByStep: Record<string, number> = {};
    for (const r of revRows as any[]) {
      revByStep[r.step] = Math.round(Number(r.revenue_kopecks ?? 0) / 100);
    }

    // 3) Сборка структурированного ответа.
    const order: Array<{ key: keyof typeof counts; label: string; revKey?: string }> = [
      { key: 'register', label: 'Регистрация', revKey: 'register' },
      { key: 'track_uploaded', label: 'Загрузил трек', revKey: 'track_uploaded' },
      { key: 'ai_chat', label: 'AI-анализ', revKey: 'ai_chat' },
      { key: 'release_created', label: 'Оформил релиз', revKey: 'release_created' },
      { key: 'payment', label: 'Оплатил' },
      { key: 'repeat', label: 'Вернулся повторно' },
    ];

    const steps = order.map((step, idx) => {
      const usersCount = counts[step.key];
      const prevCount = idx === 0 ? usersCount : counts[order[idx - 1].key];
      const conversionPct = prevCount > 0
        ? Math.round((usersCount / prevCount) * 1000) / 10
        : 0;
      const dropOffPct = idx === 0 ? 0 : Math.round((100 - conversionPct) * 10) / 10;
      return {
        step: step.key,
        label: step.label,
        users_count: usersCount,
        conversion_pct: conversionPct,
        drop_off_pct: dropOffPct,
        revenue_generated_rub: step.revKey ? (revByStep[step.revKey] ?? 0) : 0,
      };
    });

    return {
      ok: true,
      total_revenue_rub: Math.round(totalRevenueKopecks / 100),
      steps,
      generated_at: new Date().toISOString(),
    };
  }

  /**
   * Offer → Payment funnel.
   *
   * Группирует офферы по product_offer и показывает каждую ступень:
   *   sent → clicked → checkout_started → paid.
   *
   * Окно атрибуции — 14 дней (см. view v_offer_funnel в миграции 094).
   */
  @Get('admin/offer-funnel')
  async offerFunnel() {
    const { rows } = await this.pool.query(`
      SELECT product_offer, sent, clicked, checkout, paid,
             revenue_kopecks::bigint AS revenue_kopecks,
             click_pct, checkout_pct, paid_pct
        FROM v_offer_funnel_stats
        ORDER BY sent DESC
    `).catch(() => ({ rows: [] }));

    // Aggregated totals across all offers.
    const totals = (rows as any[]).reduce(
      (acc, r: any) => ({
        sent: acc.sent + Number(r.sent ?? 0),
        clicked: acc.clicked + Number(r.clicked ?? 0),
        checkout: acc.checkout + Number(r.checkout ?? 0),
        paid: acc.paid + Number(r.paid ?? 0),
        revenue_kopecks: acc.revenue_kopecks + Number(r.revenue_kopecks ?? 0),
      }),
      { sent: 0, clicked: 0, checkout: 0, paid: 0, revenue_kopecks: 0 },
    );

    const totalPaidPct = totals.sent > 0
      ? Math.round((totals.paid / totals.sent) * 1000) / 10
      : 0;

    return {
      ok: true,
      // Глобальные суммы (для headline-карточки).
      total: {
        sent: totals.sent,
        clicked: totals.clicked,
        checkout: totals.checkout,
        paid: totals.paid,
        revenue_rub: Math.round(totals.revenue_kopecks / 100),
        paid_pct: totalPaidPct,
      },
      // Разбивка по продукту.
      by_offer: (rows as any[]).map((r: any) => ({
        product_offer: r.product_offer,
        sent: Number(r.sent ?? 0),
        clicked: Number(r.clicked ?? 0),
        checkout: Number(r.checkout ?? 0),
        paid: Number(r.paid ?? 0),
        revenue_rub: Math.round(Number(r.revenue_kopecks ?? 0) / 100),
        click_pct: Number(r.click_pct ?? 0),
        checkout_pct: Number(r.checkout_pct ?? 0),
        paid_pct: Number(r.paid_pct ?? 0),
      })),
      generated_at: new Date().toISOString(),
    };
  }
}
