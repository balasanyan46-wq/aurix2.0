import { Injectable, Inject, Optional } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { LeadsService } from '../leads/leads.service';

/**
 * Конфигурация очков. Меняется здесь — единое место правды.
 *
 * Логика scoring (см. requirements):
 *   +25 track_uploaded
 *   +20 ai_chat за последние 7 дней
 *   +15 paywall_viewed
 *   +20 plan_clicked
 *   +25 checkout_started
 *   +30 payment_failed       — горящий лид: пытался оплатить, не получилось
 *   +35 release_created
 *   +40 release_submitted
 *   -10 неактивность 7+ дней
 *
 * Score кэпится в [0, 100].
 */
const SCORE_RULES = {
  track_uploaded: 25,
  ai_chat_recent: 20,         // считаем только если событие было за 7 дней
  paywall_viewed: 15,
  plan_clicked: 20,
  checkout_started: 25,
  payment_failed: 30,
  release_created: 35,
  release_submitted: 40,
  inactive_7d_penalty: -10,
} as const;

/**
 * Минимальный delta для записи в lead_score_history. Если score изменился
 * меньше чем на это значение И bucket не изменился — пишем тихо в profile,
 * но не засоряем history.
 */
const SIGNIFICANT_DELTA = 5;

export type LeadBucket = 'cold' | 'warm' | 'hot';

export interface LeadScore {
  user_id: number;
  score: number;
  bucket: LeadBucket;
  reasons: Array<{ rule: string; points: number; detected: boolean }>;
  updated_at: string;
}

@Injectable()
export class LeadScoringService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    // @Optional — иначе циркулярный модульный импорт. LeadsService
    // подключается через LeadsModule.exports, и если он отсутствует
    // (например в тестах) — scoring продолжает работать без leads-синка.
    @Optional() private readonly leads?: LeadsService,
  ) {}

  /**
   * Bucket из числового score. Границы согласно ТЗ.
   */
  private bucketFromScore(score: number): LeadBucket {
    if (score >= 71) return 'hot';
    if (score >= 30) return 'warm';
    return 'cold';
  }

  /**
   * Считает score для одного пользователя по сырым событиям из user_events.
   * Возвращает разбивку (для отображения «почему такой score» в UI).
   */
  async computeScore(userId: number): Promise<LeadScore> {
    // Один большой запрос — выгоднее, чем N мелких. Все правила в одной
    // выборке через CASE. Если user_events отсутствует — все нули.
    const { rows } = await this.pool.query(
      `
      SELECT
        BOOL_OR(event = 'track_uploaded') AS has_track,
        BOOL_OR(event = 'ai_chat' AND created_at >= now() - interval '7 days') AS has_ai_recent,
        BOOL_OR(event = 'paywall_viewed') AS has_paywall,
        BOOL_OR(event = 'plan_clicked') AS has_plan_click,
        BOOL_OR(event = 'checkout_started') AS has_checkout,
        BOOL_OR(event = 'payment_failed') AS has_payment_failed,
        BOOL_OR(event = 'release_created') AS has_release_created,
        BOOL_OR(event = 'release_submitted') AS has_release_submitted,
        MAX(created_at) AS last_active
      FROM user_events WHERE user_id = $1
      `,
      [userId],
    ).catch(() => ({ rows: [{}] }));

    const r = rows[0] ?? {};
    const reasons: LeadScore['reasons'] = [];
    let score = 0;

    const apply = (rule: keyof typeof SCORE_RULES, detected: boolean) => {
      const points = SCORE_RULES[rule];
      reasons.push({ rule, points, detected });
      if (detected) score += points;
    };

    apply('track_uploaded', !!r.has_track);
    apply('ai_chat_recent', !!r.has_ai_recent);
    apply('paywall_viewed', !!r.has_paywall);
    apply('plan_clicked', !!r.has_plan_click);
    apply('checkout_started', !!r.has_checkout);
    apply('payment_failed', !!r.has_payment_failed);
    apply('release_created', !!r.has_release_created);
    apply('release_submitted', !!r.has_release_submitted);

    // Penalty за неактивность: если последняя активность > 7 дней назад.
    let inactive = false;
    if (r.last_active) {
      const lastMs = new Date(r.last_active).getTime();
      const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
      inactive = lastMs < sevenDaysAgo;
    } else {
      // Нет ни одного события — фактически неактивен.
      inactive = true;
    }
    apply('inactive_7d_penalty', inactive);

    // Кэп в [0, 100]
    score = Math.max(0, Math.min(100, score));
    const bucket = this.bucketFromScore(score);

    return {
      user_id: userId,
      score,
      bucket,
      reasons,
      updated_at: new Date().toISOString(),
    };
  }

  /**
   * Считает score и сохраняет в profiles. Пишет историю только если
   * изменение существенное (>= SIGNIFICANT_DELTA или сменился bucket).
   * Это требование из ТЗ — не засоряем lead_score_history.
   */
  async recalculateAndSave(userId: number, reason = 'recalc'): Promise<LeadScore> {
    const computed = await this.computeScore(userId);

    // Старые значения для сравнения.
    const { rows: oldRows } = await this.pool.query(
      `SELECT lead_score, lead_bucket FROM profiles WHERE user_id = $1`,
      [userId],
    ).catch(() => ({ rows: [] }));
    const oldScore = oldRows[0]?.lead_score ?? null;
    const oldBucket = oldRows[0]?.lead_bucket ?? null;

    // Сохраняем в profiles. Если строки нет (ещё не создан профиль),
    // тихо пропускаем — score появится после создания profile.
    await this.pool.query(
      `UPDATE profiles
          SET lead_score = $2, lead_bucket = $3, score_updated_at = now()
        WHERE user_id = $1`,
      [userId, computed.score, computed.bucket],
    ).catch(() => {});

    // Синхронизация с leads pipeline. При hot bucket'е автоматически
    // создаётся / обновляется lead. Тихий fail если LeadsService не
    // зарегистрирован в DI (например, в isolated unit-тестах).
    if (this.leads) {
      try {
        await this.leads.ensureLead(userId, computed.score, computed.bucket, 'system');
      } catch {/* leads sync best-effort */}
    }

    // История — только если существенно.
    const delta = oldScore == null ? computed.score : computed.score - oldScore;
    const bucketChanged = oldBucket != null && oldBucket !== computed.bucket;
    if (Math.abs(delta) >= SIGNIFICANT_DELTA || bucketChanged) {
      await this.pool.query(
        `INSERT INTO lead_score_history
           (user_id, old_score, new_score, old_bucket, new_bucket, delta, reason)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [userId, oldScore, computed.score, oldBucket, computed.bucket, delta, reason],
      ).catch(() => {});
    }

    return computed;
  }

  /**
   * Массовый пересчёт. Берём только пользователей с активностью за
   * последние 30 дней — мёртвые leads не интересны и так в cold.
   * Возвращает количество пересчитанных.
   */
  async recalculateAll(reason = 'cron'): Promise<{ recalculated: number }> {
    const { rows } = await this.pool.query(`
      SELECT DISTINCT user_id FROM user_events
      WHERE created_at >= now() - interval '30 days'
      LIMIT 10000
    `).catch(() => ({ rows: [] }));

    let count = 0;
    for (const r of rows as Array<{ user_id: number }>) {
      try {
        await this.recalculateAndSave(r.user_id, reason);
        count++;
      } catch { /* skip individual failures */ }
    }
    return { recalculated: count };
  }

  /**
   * Список лидов по bucket'у с сортировкой по score DESC.
   */
  async listByBucket(bucket: LeadBucket, limit = 50): Promise<any[]> {
    const { rows } = await this.pool.query(
      `
      SELECT
        u.id AS user_id,
        u.email,
        p.display_name,
        p.artist_name,
        p.plan,
        p.lead_score,
        p.lead_bucket,
        p.score_updated_at,
        p.subscription_status
      FROM profiles p
      JOIN users u ON u.id = p.user_id
      WHERE p.lead_bucket = $1
      ORDER BY p.lead_score DESC, p.score_updated_at DESC NULLS LAST
      LIMIT $2
      `,
      [bucket, limit],
    ).catch(() => ({ rows: [] }));
    return rows;
  }
}
