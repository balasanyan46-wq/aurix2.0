import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

/**
 * RevenueService — SaaS-метрики из payments / subscription_log / users.
 *
 * НЕ использует billing_subscriptions — там user_id uuid (legacy Supabase),
 * не joinится с payments.user_id (int). Источник правды — payments.
 *
 * Все суммы храним в копейках (как в payments.amount), наружу отдаём в ₽.
 *
 * Метрики:
 *   - mrr           — Monthly Recurring Revenue (нормализованный на 1 месяц)
 *   - arr           — MRR × 12
 *   - arpu_30d      — revenue_30d / unique paying users
 *   - ltv           — total revenue / total paying users (cumulative avg)
 *   - churn_30d_pct — отменённых подписок в %, относительно активных в начале периода
 *   - conversion_to_paid_pct — paying / total registered
 *   - failed_30d, refunded_30d — count + amount
 *   - mom_growth_pct — revenue_this_month / revenue_prev_month
 *   - monthly_revenue_12m — time series для графика
 */
@Injectable()
export class RevenueService {
  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Главный метод: собирает все метрики одним вызовом.
   * Каждый запрос обёрнут в try/catch — отсутствие одной таблицы не валит весь dashboard.
   */
  async getMetrics(): Promise<RevenueMetrics> {
    const [
      mrrRow,
      arpuRow,
      ltvRow,
      churnRow,
      conversionRow,
      failedRow,
      refundedRow,
      growthRow,
      timeSeriesRows,
      breakdownByPlanRows,
    ] = await Promise.all([
      this.queryMrr(),
      this.queryArpu30d(),
      this.queryLtv(),
      this.queryChurn30d(),
      this.queryConversionToPaid(),
      this.queryFailed30d(),
      this.queryRefunded30d(),
      this.queryMomGrowth(),
      this.queryMonthlyRevenue12m(),
      this.queryRevenueByPlan(),
    ]);

    const mrrKopecks = Number(mrrRow.mrr ?? 0);
    const arpuKopecks = Number(arpuRow.arpu ?? 0);
    const ltvKopecks = Number(ltvRow.ltv ?? 0);

    return {
      generated_at: new Date().toISOString(),
      // Headline KPIs
      mrr_rub: kopToRub(mrrKopecks),
      arr_rub: kopToRub(mrrKopecks * 12),
      arpu_30d_rub: kopToRub(arpuKopecks),
      ltv_rub: kopToRub(ltvKopecks),
      churn_30d_pct: Number(churnRow.churn_pct ?? 0),
      conversion_to_paid_pct: Number(conversionRow.conversion_pct ?? 0),
      mom_growth_pct: Number(growthRow.growth_pct ?? 0),
      // Risk
      failed_payments_30d: {
        count: Number(failedRow.count ?? 0),
        total_rub: kopToRub(Number(failedRow.amount ?? 0)),
      },
      refunds_30d: {
        count: Number(refundedRow.count ?? 0),
        total_rub: kopToRub(Number(refundedRow.amount ?? 0)),
      },
      // Trends
      monthly_revenue_12m: (timeSeriesRows as any[]).map((r: any) => ({
        month: String(r.month).slice(0, 7), // YYYY-MM
        revenue_rub: kopToRub(Number(r.revenue ?? 0)),
        paying_users: Number(r.paying_users ?? 0),
      })),
      revenue_by_plan: (breakdownByPlanRows as any[]).map((r: any) => ({
        plan: String(r.plan ?? 'unknown'),
        revenue_30d_rub: kopToRub(Number(r.revenue ?? 0)),
        paying_users: Number(r.paying_users ?? 0),
      })),
      // Forecast: примитивный — текущий MRR + (MRR × growth_rate).
      // Положительный rate => рост, отрицательный => стагнация.
      forecast_next_month_rub: this.forecast(mrrKopecks, Number(growthRow.growth_pct ?? 0)),
    };
  }

  // ────────────────────────────────────────────────────────────────────
  //  Отдельные запросы (каждый сам ловит ошибки → возвращает defaults)
  // ────────────────────────────────────────────────────────────────────

  /**
   * MRR: confirmed подписочные платежи за текущий календарный месяц.
   * yearly нормализуем как amount/12 (контрибьюция в один месяц).
   * credits — НЕ считаем (это разовые покупки, не recurring).
   */
  private async queryMrr(): Promise<{ mrr: number }> {
    const { rows } = await this.pool.query(`
      SELECT COALESCE(SUM(
        CASE
          WHEN billing_period = 'yearly' THEN amount / 12.0
          ELSE amount
        END
      ), 0)::bigint AS mrr
      FROM payments
      WHERE status = 'confirmed'
        AND payment_type = 'subscription'
        AND confirmed_at >= date_trunc('month', now())
    `).catch(() => ({ rows: [{ mrr: 0 }] }));
    return rows[0];
  }

  /**
   * ARPU за 30 дней = total revenue / unique paying users за тот же период.
   */
  private async queryArpu30d(): Promise<{ arpu: number }> {
    const { rows } = await this.pool.query(`
      WITH revenue AS (
        SELECT user_id, SUM(amount) AS total
          FROM payments
         WHERE status = 'confirmed'
           AND confirmed_at >= now() - interval '30 days'
         GROUP BY user_id
      )
      SELECT CASE WHEN count(*) > 0
                  THEN COALESCE(SUM(total)::numeric / count(*), 0)
                  ELSE 0 END AS arpu
        FROM revenue
    `).catch(() => ({ rows: [{ arpu: 0 }] }));
    return rows[0];
  }

  /**
   * LTV = cumulative average revenue per paying user.
   * Простая модель — total / users. Для cohort LTV нужны cohort tables.
   */
  private async queryLtv(): Promise<{ ltv: number }> {
    const { rows } = await this.pool.query(`
      WITH user_totals AS (
        SELECT user_id, SUM(amount) AS total
          FROM payments
         WHERE status = 'confirmed'
         GROUP BY user_id
      )
      SELECT CASE WHEN count(*) > 0
                  THEN COALESCE(AVG(total)::numeric, 0)
                  ELSE 0 END AS ltv
        FROM user_totals
    `).catch(() => ({ rows: [{ ltv: 0 }] }));
    return rows[0];
  }

  /**
   * Churn за 30 дней.
   *
   * Numerator: subscription_log.action='cancelled' за последние 30 дней.
   * Denominator: уникальные active subscribers на начало периода
   *   (= те, у кого был activated за прошлые 12 мес и не cancelled до начала окна).
   *
   * Returns: процент (0..100).
   */
  private async queryChurn30d(): Promise<{ churn_pct: number }> {
    const { rows } = await this.pool.query(`
      WITH cancelled_30d AS (
        SELECT COUNT(DISTINCT user_id) AS c
          FROM subscription_log
         WHERE action = 'cancelled'
           AND created_at >= now() - interval '30 days'
      ),
      active_at_start AS (
        SELECT COUNT(DISTINCT sl.user_id) AS c
          FROM subscription_log sl
         WHERE sl.action IN ('activated', 'upgraded')
           AND sl.created_at < now() - interval '30 days'
           AND sl.created_at >= now() - interval '12 months'
           AND NOT EXISTS (
             SELECT 1 FROM subscription_log sl2
              WHERE sl2.user_id = sl.user_id
                AND sl2.action IN ('cancelled', 'expired')
                AND sl2.created_at < now() - interval '30 days'
                AND sl2.created_at > sl.created_at
           )
      )
      SELECT CASE WHEN (SELECT c FROM active_at_start) > 0
                  THEN ROUND(
                    (SELECT c FROM cancelled_30d)::numeric * 100 /
                    (SELECT c FROM active_at_start), 2
                  )
                  ELSE 0 END AS churn_pct
    `).catch(() => ({ rows: [{ churn_pct: 0 }] }));
    return rows[0];
  }

  /**
   * Conversion to paid = unique paying users / total registered users.
   */
  private async queryConversionToPaid(): Promise<{ conversion_pct: number }> {
    const { rows } = await this.pool.query(`
      WITH paying AS (
        SELECT COUNT(DISTINCT user_id) AS c
          FROM payments WHERE status = 'confirmed'
      ),
      total AS (SELECT COUNT(*) AS c FROM users)
      SELECT CASE WHEN (SELECT c FROM total) > 0
                  THEN ROUND(
                    (SELECT c FROM paying)::numeric * 100 /
                    (SELECT c FROM total), 2
                  )
                  ELSE 0 END AS conversion_pct
    `).catch(() => ({ rows: [{ conversion_pct: 0 }] }));
    return rows[0];
  }

  private async queryFailed30d(): Promise<{ count: number; amount: number }> {
    const { rows } = await this.pool.query(`
      SELECT COUNT(*)::int AS count, COALESCE(SUM(amount), 0)::bigint AS amount
        FROM payments
       WHERE status = 'failed'
         AND created_at >= now() - interval '30 days'
    `).catch(() => ({ rows: [{ count: 0, amount: 0 }] }));
    return rows[0];
  }

  private async queryRefunded30d(): Promise<{ count: number; amount: number }> {
    const { rows } = await this.pool.query(`
      SELECT COUNT(*)::int AS count, COALESCE(SUM(amount), 0)::bigint AS amount
        FROM payments
       WHERE status = 'refunded'
         AND updated_at >= now() - interval '30 days'
    `).catch(() => ({ rows: [{ count: 0, amount: 0 }] }));
    return rows[0];
  }

  /**
   * MoM growth: revenue этого месяца vs предыдущего, % (отриц = падение).
   */
  private async queryMomGrowth(): Promise<{ growth_pct: number }> {
    const { rows } = await this.pool.query(`
      WITH this_month AS (
        SELECT COALESCE(SUM(amount), 0)::bigint AS rev
          FROM payments
         WHERE status = 'confirmed'
           AND confirmed_at >= date_trunc('month', now())
      ),
      prev_month AS (
        SELECT COALESCE(SUM(amount), 0)::bigint AS rev
          FROM payments
         WHERE status = 'confirmed'
           AND confirmed_at >= date_trunc('month', now()) - interval '1 month'
           AND confirmed_at <  date_trunc('month', now())
      )
      SELECT CASE WHEN (SELECT rev FROM prev_month) > 0
                  THEN ROUND(
                    ((SELECT rev FROM this_month)::numeric -
                     (SELECT rev FROM prev_month)::numeric) * 100 /
                    (SELECT rev FROM prev_month)::numeric, 2
                  )
                  ELSE 0 END AS growth_pct
    `).catch(() => ({ rows: [{ growth_pct: 0 }] }));
    return rows[0];
  }

  /**
   * 12-месячная time series: revenue + уникальные paying users по месяцам.
   * Используется для линейного графика на dashboard.
   */
  private async queryMonthlyRevenue12m(): Promise<any[]> {
    const { rows } = await this.pool.query(`
      SELECT
        date_trunc('month', confirmed_at)::date AS month,
        COALESCE(SUM(amount), 0)::bigint AS revenue,
        COUNT(DISTINCT user_id)::int AS paying_users
      FROM payments
      WHERE status = 'confirmed'
        AND confirmed_at >= date_trunc('month', now()) - interval '11 months'
      GROUP BY 1
      ORDER BY 1
    `).catch(() => ({ rows: [] }));
    return rows;
  }

  /**
   * Revenue breakdown по плану за 30 дней. Помогает увидеть, какой план
   * приносит больше денег.
   */
  private async queryRevenueByPlan(): Promise<any[]> {
    const { rows } = await this.pool.query(`
      SELECT
        plan,
        COALESCE(SUM(amount), 0)::bigint AS revenue,
        COUNT(DISTINCT user_id)::int AS paying_users
      FROM payments
      WHERE status = 'confirmed'
        AND confirmed_at >= now() - interval '30 days'
      GROUP BY plan
      ORDER BY revenue DESC
    `).catch(() => ({ rows: [] }));
    return rows;
  }

  /**
   * Forecast next month: текущий MRR × (1 + growth_pct/100).
   * Простая линейная экстраполяция — для роста на 20% выдаст MRR×1.2.
   * Капируем в [0, MRR×3] чтобы не показывать абсурдные значения.
   */
  private forecast(mrrKopecks: number, growthPct: number): number {
    if (mrrKopecks <= 0) return 0;
    const mult = Math.max(0, Math.min(3, 1 + growthPct / 100));
    return kopToRub(Math.round(mrrKopecks * mult));
  }
}

/**
 * Конвертация копеек → рубли (округление). Naming sticks к ₽.
 */
function kopToRub(kop: number): number {
  return Math.round(Number(kop) / 100);
}

// ──────────────────────────────────────────────────────────────────────
//  Public types
// ──────────────────────────────────────────────────────────────────────

export interface RevenueMetrics {
  generated_at: string;
  mrr_rub: number;
  arr_rub: number;
  arpu_30d_rub: number;
  ltv_rub: number;
  churn_30d_pct: number;
  conversion_to_paid_pct: number;
  mom_growth_pct: number;
  failed_payments_30d: { count: number; total_rub: number };
  refunds_30d: { count: number; total_rub: number };
  monthly_revenue_12m: Array<{ month: string; revenue_rub: number; paying_users: number }>;
  revenue_by_plan: Array<{ plan: string; revenue_30d_rub: number; paying_users: number }>;
  forecast_next_month_rub: number;
}
