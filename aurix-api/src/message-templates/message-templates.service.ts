import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

/**
 * MessageTemplatesService — A/B-тестируемые шаблоны sales-сообщений.
 *
 * API:
 *   - pickVariant(code) — возвращает случайный активный variant с учётом weight
 *   - getStats(code) — конверсия по вариантам (offer_sent → payment_success)
 *   - listAll() — все шаблоны для admin UI
 *   - upsert(...)/setActive(...) — управление через UI (TODO: endpoints)
 *
 * Variant attribution: NextActionService при формировании suggested_message
 * передаёт обратно `template_variant`, который потом логируется в
 * offer_sent.meta.template_variant. По этому полю считаем conversion.
 */
@Injectable()
export class MessageTemplatesService {
  private readonly log = new Logger(MessageTemplatesService.name);

  // Кэш активных шаблонов в памяти, чтобы не бить БД при каждом next-action.
  // Простой TTL 60 сек — достаточно, чтобы изменения админа дошли быстро.
  private cache: Map<string, { rows: TemplateRow[]; expiresAt: number }> = new Map();
  private static readonly CACHE_TTL_MS = 60_000;

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  /**
   * Выбирает один вариант для action `code` с учётом weight.
   * Если шаблонов нет в БД — возвращает null (вызывающий код использует
   * fallback из next-action.service.ts ACTIONS).
   */
  async pickVariant(code: string): Promise<TemplateRow | null> {
    const variants = await this.getActiveVariants(code);
    if (variants.length === 0) return null;
    if (variants.length === 1) return variants[0];

    // Weighted random: суммируем веса, генерируем число в [0, total),
    // итерируемся пока accumulator не пересечёт roll.
    const totalWeight = variants.reduce((s, v) => s + v.weight, 0);
    if (totalWeight <= 0) return variants[0];
    const roll = Math.random() * totalWeight;
    let acc = 0;
    for (const v of variants) {
      acc += v.weight;
      if (roll < acc) return v;
    }
    return variants[variants.length - 1];
  }

  private async getActiveVariants(code: string): Promise<TemplateRow[]> {
    const cached = this.cache.get(code);
    if (cached && cached.expiresAt > Date.now()) {
      return cached.rows;
    }
    const { rows } = await this.pool.query<TemplateRow>(
      `SELECT id, code, variant_key, message, weight, active
         FROM message_templates
        WHERE code = $1 AND active = true
        ORDER BY variant_key`,
      [code],
    ).catch(() => ({ rows: [] as TemplateRow[] }));
    this.cache.set(code, {
      rows,
      expiresAt: Date.now() + MessageTemplatesService.CACHE_TTL_MS,
    });
    return rows;
  }

  /**
   * Все шаблоны (для admin UI). Без кэша.
   */
  async listAll(): Promise<TemplateRow[]> {
    const { rows } = await this.pool.query<TemplateRow>(
      `SELECT id, code, variant_key, message, weight, active, created_at, updated_at
         FROM message_templates
         ORDER BY code, variant_key`,
    ).catch(() => ({ rows: [] as TemplateRow[] }));
    return rows;
  }

  /**
   * A/B статистика: для каждого (code, variant_key) считаем sent / paid.
   * Источник — offer_sent events с meta.template_variant + payment_success
   * в окне 14 дней (как в v_offer_funnel).
   */
  async getStats(): Promise<TemplateStats[]> {
    const { rows } = await this.pool.query(`
      WITH offers AS (
        SELECT
          ue.user_id,
          ue.created_at AS sent_at,
          ue.meta->>'template_code' AS code,
          ue.meta->>'template_variant' AS variant_key
        FROM user_events ue
        WHERE ue.event = 'offer_sent'
          AND ue.meta ? 'template_code'
          AND ue.created_at >= now() - interval '60 days'
      ),
      attributed AS (
        SELECT
          o.code,
          o.variant_key,
          COUNT(*)::int AS sent,
          COUNT(*) FILTER (
            WHERE EXISTS (
              SELECT 1 FROM user_events ue2
               WHERE ue2.user_id = o.user_id
                 AND ue2.event = 'payment_success'
                 AND ue2.created_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
            )
          )::int AS paid
        FROM offers o
        GROUP BY o.code, o.variant_key
      )
      SELECT code, variant_key, sent, paid,
             CASE WHEN sent > 0
                  THEN ROUND(paid::numeric * 100 / sent, 2)
                  ELSE 0 END AS conversion_pct
        FROM attributed
        ORDER BY code, variant_key
    `).catch(() => ({ rows: [] }));
    return rows as any;
  }

  /**
   * Multi-channel attribution: какой transport (push / email / internal)
   * лучше конвертит в payment.
   *
   * Источник: offer_sent.meta.transport (записывается в /admin/notifications)
   * + payment_success в окне 14 дней.
   */
  async getStatsByChannel(): Promise<ChannelStats[]> {
    const { rows } = await this.pool.query(`
      WITH offers AS (
        SELECT
          ue.user_id,
          ue.created_at AS sent_at,
          COALESCE(ue.meta->>'transport', 'unknown') AS channel
        FROM user_events ue
        WHERE ue.event = 'offer_sent'
          AND ue.created_at >= now() - interval '60 days'
      ),
      attributed AS (
        SELECT
          o.channel,
          COUNT(*)::int AS sent,
          COUNT(*) FILTER (
            WHERE EXISTS (
              SELECT 1 FROM user_events ue2
               WHERE ue2.user_id = o.user_id
                 AND ue2.event = 'payment_success'
                 AND ue2.created_at BETWEEN o.sent_at AND o.sent_at + interval '14 days'
            )
          )::int AS paid
        FROM offers o
        GROUP BY o.channel
      )
      SELECT channel, sent, paid,
             CASE WHEN sent > 0
                  THEN ROUND(paid::numeric * 100 / sent, 2)
                  ELSE 0 END AS conversion_pct
        FROM attributed
        ORDER BY sent DESC
    `).catch(() => ({ rows: [] }));
    return rows as any;
  }

  /**
   * Создание / обновление шаблона.
   * UPSERT по (code, variant_key) — повторный вызов с тем же ключом
   * обновляет message/weight/active.
   */
  async upsert(input: {
    code: string;
    variant_key: string;
    message: string;
    weight?: number;
    active?: boolean;
    created_by?: number | null;
  }): Promise<TemplateRow> {
    const { rows } = await this.pool.query<TemplateRow>(
      `
      INSERT INTO message_templates (code, variant_key, message, weight, active, created_by)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (code, variant_key)
      DO UPDATE SET
        message = EXCLUDED.message,
        weight  = EXCLUDED.weight,
        active  = EXCLUDED.active
      RETURNING *
      `,
      [
        input.code,
        input.variant_key || 'A',
        input.message,
        input.weight ?? 1,
        input.active ?? true,
        input.created_by ?? null,
      ],
    );
    // Сбросим кэш для этого code
    this.cache.delete(input.code);
    return rows[0];
  }

  /**
   * Включить / выключить вариант. Используется быстрого toggle'а в UI.
   */
  async setActive(id: number, active: boolean): Promise<TemplateRow | null> {
    const { rows } = await this.pool.query<TemplateRow>(
      `UPDATE message_templates SET active = $2 WHERE id = $1 RETURNING *`,
      [id, active],
    );
    if (rows[0]) this.cache.delete(rows[0].code);
    return rows[0] ?? null;
  }

  /**
   * Удалить вариант. Удаление variant 'A' запрещено если других не осталось —
   * это защита от потери fallback'а. Возвращает row если удалили, null если
   * нельзя.
   */
  async deleteVariant(id: number): Promise<TemplateRow | null> {
    const { rows: target } = await this.pool.query<TemplateRow>(
      `SELECT * FROM message_templates WHERE id = $1`,
      [id],
    );
    if (!target[0]) return null;
    const { rows: others } = await this.pool.query(
      `SELECT count(*)::int AS c FROM message_templates
        WHERE code = $1 AND id <> $2 AND active = true`,
      [target[0].code, id],
    );
    if ((others[0]?.c ?? 0) === 0) {
      // Это последний активный — нельзя удалять, иначе sales-flow сломается.
      return null;
    }
    await this.pool.query(`DELETE FROM message_templates WHERE id = $1`, [id]);
    this.cache.delete(target[0].code);
    return target[0];
  }

  /**
   * Sanity-check fallback: возвращает hardcoded текст если в БД пусто.
   * Используется next-action.service.ts если БД ещё не накатана.
   */
  static fallback(code: string): string | null {
    const map: Record<string, string> = {
      contact_hot_lead: 'Привет! Вижу, ты активно пользуешься AURIX. Подскажи, чем могу помочь — хочешь подобрать подходящий план или обсудить продвижение?',
      upsell_promotion: 'Отлично, что ты выпустил релиз! Теперь самое важное — продвижение. Расскажу про наш Promotion Pack.',
      push_to_payment: 'Видел, что ты подготовил релиз — осталось только оплатить дистрибуцию.',
      suggest_release: 'AI уже проанализировал твой материал — самое время оформить релиз.',
      suggest_analysis: 'Видел, что ты загрузил трек. Хочешь, AURIX AI проанализирует его?',
    };
    return map[code] ?? null;
  }
}

export interface TemplateRow {
  id: number;
  code: string;
  variant_key: string;
  message: string;
  weight: number;
  active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface TemplateStats {
  code: string;
  variant_key: string;
  sent: number;
  paid: number;
  conversion_pct: number;
}

export interface ChannelStats {
  channel: string; // push | email | internal | unknown
  sent: number;
  paid: number;
  conversion_pct: number;
}
