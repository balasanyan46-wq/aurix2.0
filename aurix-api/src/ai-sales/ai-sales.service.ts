import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { AiGatewayService } from '../ai/ai-gateway.service';

/**
 * AI → Sales: анализирует последние ai_studio_messages пользователя
 * и оценивает sales_signal (low | medium | high).
 *
 * Не вызывается на каждый GET — результаты кэшируются в ai_sales_signals.
 * Refresh запускается:
 *   - вручную через POST /admin/ai-sales-signals/refresh
 *   - через cron (рекомендация — раз в 30-60 минут на топ-N активных юзеров)
 */
@Injectable()
export class AiSalesService {
  private readonly log = new Logger(AiSalesService.name);

  /**
   * Сколько последних сообщений учитываем при анализе. Слишком много —
   * раздуем токены и контекст; слишком мало — не увидим намерения.
   */
  static readonly MESSAGE_WINDOW = 20;

  /**
   * Системный промпт. Жёстко требуем JSON, чтобы парсить детерминированно.
   * Если AI вернёт мусор — fallback на 'low'.
   */
  private static readonly SYSTEM_PROMPT = `Ты — sales-аналитик AURIX (платформа для музыкантов).
На вход тебе даны последние сообщения пользователя в студийном чате (роль user/assistant).

Твоя задача: оценить готовность пользователя купить продукт AURIX.

ПРОДУКТЫ:
- analysis_pro     — углублённый AI-анализ трека (590-1990 ₽)
- distribution     — дистрибуция релиза (2990-9900 ₽)
- promotion        — продвижение релиза (9900-50000 ₽)

Верни СТРОГО JSON-объект без markdown:
{
  "insight": "1 предложение: что ты увидел в его поведении",
  "recommendation": "1 предложение: что мы должны сделать",
  "sales_signal": "low" | "medium" | "high",
  "suggested_action": "конкретное действие на русском (например: 'Связаться и предложить промо-пакет')",
  "product_offer": "analysis_pro" | "promotion" | "distribution"
}

КРИТЕРИИ:
- high: явный интерес к покупке (спрашивал цены, просил помочь продать, упоминал продвижение, жаловался на охват)
- medium: активно использует, но без явного интереса к продуктам
- low: технические вопросы, нет покупательских сигналов

Если истории недостаточно — sales_signal: "low".`;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ai: AiGatewayService,
  ) {}

  /**
   * Анализирует одного пользователя. Сохраняет результат в ai_sales_signals.
   * Возвращает saved row.
   *
   * Идемпотентен в том смысле, что каждый вызов создаёт новую запись —
   * история сигналов сохраняется. Action Center читает только последний.
   */
  async analyzeUser(userId: number): Promise<{
    insight: string;
    recommendation: string;
    sales_signal: 'low' | 'medium' | 'high';
    suggested_action: string;
    product_offer: 'analysis_pro' | 'promotion' | 'distribution' | null;
    source_messages: number;
  } | null> {
    // Берём последние N сообщений. ai_studio_messages.user_id может быть uuid
    // или int в зависимости от миграции — поддерживаем оба варианта через ::text.
    const { rows: msgs } = await this.pool.query(
      `SELECT role, content FROM ai_studio_messages
        WHERE user_id::text = $1::text
        ORDER BY created_at DESC LIMIT $2`,
      [userId, AiSalesService.MESSAGE_WINDOW],
    ).catch(() => ({ rows: [] }));

    if (msgs.length === 0) return null;

    // В правильном порядке (от старых к новым) для AI-контекста.
    const ordered = [...msgs].reverse();
    const userText = ordered
      .map((m: any) => `[${m.role}] ${String(m.content).slice(0, 500)}`)
      .join('\n');

    let parsed: any;
    try {
      const content = await this.ai.simpleChat(
        AiSalesService.SYSTEM_PROMPT,
        userText,
        { maxTokens: 500, temperature: 0.3, timeout: 25_000 },
      );
      const cleaned = content.replace(/```json?\n?/g, '').replace(/```/g, '').trim();
      parsed = JSON.parse(cleaned);
    } catch (e: any) {
      this.log.warn(`AI sales analysis failed for user ${userId}: ${e.message}`);
      // Сохраняем "low" чтобы не зацикливаться на этом юзере при следующем cron.
      parsed = {
        insight: 'AI не смог проанализировать (fallback)',
        recommendation: 'Повторить попытку позже',
        sales_signal: 'low',
        suggested_action: '',
        product_offer: null,
      };
    }

    // Жёсткая валидация значений (AI может вернуть что угодно).
    const validSignal = ['low', 'medium', 'high'];
    const validOffer = ['analysis_pro', 'promotion', 'distribution'];
    const sales_signal = validSignal.includes(parsed.sales_signal)
      ? parsed.sales_signal
      : 'low';
    const product_offer = validOffer.includes(parsed.product_offer)
      ? parsed.product_offer
      : null;

    const result = {
      insight: String(parsed.insight ?? '').slice(0, 1000),
      recommendation: String(parsed.recommendation ?? '').slice(0, 1000),
      sales_signal: sales_signal as 'low' | 'medium' | 'high',
      suggested_action: String(parsed.suggested_action ?? '').slice(0, 500),
      product_offer: product_offer as 'analysis_pro' | 'promotion' | 'distribution' | null,
      source_messages: msgs.length,
    };

    await this.pool.query(
      `INSERT INTO ai_sales_signals
         (user_id, insight, recommendation, sales_signal, suggested_action,
          product_offer, source_messages)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [userId, result.insight, result.recommendation, result.sales_signal,
       result.suggested_action, result.product_offer, result.source_messages],
    ).catch((e) => this.log.warn(`Failed to save sales signal for user ${userId}: ${e.message}`));

    return result;
  }

  /**
   * Возвращает свежий список пользователей с sales_signal = high.
   * Берёт ПОСЛЕДНИЙ сигнал на пользователя — старые игнорирует
   * (пользователь мог стать "холоднее" со временем).
   */
  async listHighSignalUsers(limit = 20): Promise<Array<{
    user_id: number;
    email: string | null;
    insight: string;
    recommendation: string;
    suggested_action: string;
    product_offer: string | null;
    created_at: string;
  }>> {
    const { rows } = await this.pool.query(
      `
      SELECT DISTINCT ON (s.user_id)
             s.user_id, s.insight, s.recommendation, s.suggested_action,
             s.product_offer, s.created_at,
             u.email
        FROM ai_sales_signals s
        LEFT JOIN users u ON u.id = s.user_id
       WHERE s.created_at >= now() - interval '7 days'
       ORDER BY s.user_id, s.created_at DESC
      `,
    ).catch(() => ({ rows: [] }));

    // Фильтруем по последнему signal'у. SELECT DISTINCT ON даёт
    // последнюю строку, но не гарантирует, что это high — фильтр в SQL
    // через OUTER WHERE создаёт сложность с DISTINCT, проще filter в JS.
    const filtered: any[] = [];
    for (const r of rows as any[]) {
      // Подгружаем фактический последний signal — на случай, если в окне 7 дней
      // у юзера были и high, и потом low (берём свежайший).
      const { rows: latest } = await this.pool.query(
        `SELECT sales_signal FROM ai_sales_signals
          WHERE user_id = $1
          ORDER BY created_at DESC LIMIT 1`,
        [r.user_id],
      );
      if (latest[0]?.sales_signal === 'high') filtered.push(r);
      if (filtered.length >= limit) break;
    }
    return filtered;
  }

  /**
   * Bulk refresh: запускает анализ для топ-N последних пользователей с
   * сообщениями. Используется в cron / ручном refresh.
   * Возвращает количество успешно проанализированных.
   */
  async refreshTopActive(limit = 50): Promise<{ analyzed: number }> {
    const { rows } = await this.pool.query(
      `
      SELECT DISTINCT user_id::int AS user_id
        FROM ai_studio_messages
       WHERE created_at >= now() - interval '30 days'
       ORDER BY user_id
       LIMIT $1
      `,
      [limit],
    ).catch(() => ({ rows: [] }));

    let analyzed = 0;
    for (const r of rows as Array<{ user_id: number }>) {
      try {
        const res = await this.analyzeUser(r.user_id);
        if (res) analyzed++;
      } catch (e: any) {
        this.log.warn(`refreshTopActive: user ${r.user_id} failed: ${e.message}`);
      }
    }
    return { analyzed };
  }

  /**
   * Cron-friendly refresh с cooldown'ом + приоритизацией:
   *   - анализирует только активных юзеров с ai_chat за 7 дней или hot leads
   *   - пропускает тех, кого уже анализировали < 24 часов назад
   *   - жёсткий лимит 30 за прогон (защита от взрыва AI-квот)
   *
   * Возвращает: { analyzed, skipped_cooldown, errors }.
   */
  async refreshTopActiveWithCooldown(): Promise<{
    analyzed: number;
    skipped_cooldown: number;
    errors: number;
  }> {
    const HARD_LIMIT = 30;
    const COOLDOWN_HOURS = 24;

    // Кандидаты: активные юзеры (ai_chat за 7 дней) ИЛИ hot leads.
    // SELECT DISTINCT по user_id, исключая тех, у кого недавний сигнал.
    const { rows: candidates } = await this.pool.query(
      `
      WITH candidates AS (
        SELECT DISTINCT user_id::int AS user_id
          FROM ai_studio_messages
         WHERE created_at >= now() - interval '7 days'
        UNION
        SELECT DISTINCT l.user_id
          FROM leads l
         WHERE l.lead_bucket = 'hot' AND l.status NOT IN ('converted','lost')
      ),
      recent AS (
        -- Кто уже анализировался в последние COOLDOWN_HOURS
        SELECT DISTINCT user_id
          FROM ai_sales_signals
         WHERE created_at >= now() - interval '${COOLDOWN_HOURS} hours'
      )
      SELECT c.user_id
        FROM candidates c
        LEFT JOIN recent r ON r.user_id = c.user_id
       WHERE r.user_id IS NULL
       ORDER BY c.user_id
       LIMIT $1
      `,
      [HARD_LIMIT],
    ).catch(() => ({ rows: [] }));

    // Подсчёт сколько было пропущено из-за cooldown — для логов.
    const { rows: skippedCount } = await this.pool.query(
      `
      WITH candidates AS (
        SELECT DISTINCT user_id::int AS user_id
          FROM ai_studio_messages
         WHERE created_at >= now() - interval '7 days'
        UNION
        SELECT DISTINCT l.user_id
          FROM leads l
         WHERE l.lead_bucket = 'hot' AND l.status NOT IN ('converted','lost')
      )
      SELECT COUNT(*)::int AS c
        FROM candidates c
        WHERE EXISTS (
          SELECT 1 FROM ai_sales_signals s
           WHERE s.user_id = c.user_id
             AND s.created_at >= now() - interval '${COOLDOWN_HOURS} hours'
        )
      `,
    ).catch(() => ({ rows: [{ c: 0 }] }));

    let analyzed = 0;
    let errors = 0;
    for (const r of candidates as Array<{ user_id: number }>) {
      try {
        const res = await this.analyzeUser(r.user_id);
        if (res) analyzed++;
      } catch (e: any) {
        errors++;
        this.log.warn(`refreshTopActiveWithCooldown: user ${r.user_id} failed: ${e.message}`);
      }
    }

    return {
      analyzed,
      skipped_cooldown: skippedCount[0]?.c ?? 0,
      errors,
    };
  }
}
