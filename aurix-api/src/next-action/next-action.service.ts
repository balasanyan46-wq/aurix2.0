import { Injectable, Inject, Optional } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { LeadsService } from '../leads/leads.service';
import { MessageTemplatesService } from '../message-templates/message-templates.service';

/**
 * Next Action Engine — детерминированные правила «что должен сделать
 * менеджер с этим юзером сейчас».
 *
 * Правила (в порядке приоритета — сверху побеждает):
 *
 *  1) lead_score > 70                    → "Связаться с артистом"
 *  2) есть payment, нет повторной активности → "Сделать upsell"
 *  3) есть release_created, нет payment   → "Довести до оплаты"
 *  4) есть ai_chat, нет release_created   → "Предложить оформить релиз"
 *  5) есть track_uploaded, нет ai_chat    → "Предложить анализ трека"
 *  6) ничего из выше                      → null (нет действия)
 *
 * Возвращает структуру:
 *   { code, action, reason, possible_revenue, suggested_message }
 *
 * code — машинный идентификатор для UI/аналитики (contact_hot_lead, upsell, ...).
 * possible_revenue — оценка (₽). Используется в Action Center для приоритизации.
 */
@Injectable()
export class NextActionService {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly leads: LeadsService,
    // @Optional чтобы next-action не падал, если миграция 095 ещё не накатана
    // или MessageTemplatesService недоступен по другим причинам.
    @Optional() private readonly templates?: MessageTemplatesService,
  ) {}

  /**
   * Конкретные предложения. Цены/тексты можно править здесь без миграций.
   * Не локализую — текст идёт прямо в UI и в leads.next_action.
   */
  private static readonly ACTIONS = {
    contact_hot_lead: {
      action: 'Связаться с артистом',
      possible_revenue: 5000,
      suggested_message: 'Привет! Вижу, ты активно пользуешься AURIX. Подскажи, чем могу помочь — хочешь подобрать подходящий план или обсудить продвижение?',
    },
    upsell_promotion: {
      action: 'Сделать upsell (продвижение)',
      possible_revenue: 10000,
      suggested_message: 'Отлично, что ты выпустил релиз! Теперь самое важное — продвижение. Расскажу про наш Promotion Pack: попадание в плейлисты, реклама в соцсетях, охват 50k+.',
    },
    push_to_payment: {
      action: 'Довести до оплаты',
      possible_revenue: 2990,
      suggested_message: 'Видел, что ты подготовил релиз — осталось только оплатить дистрибуцию. Если есть вопросы по тарифу, напиши, помогу выбрать.',
    },
    suggest_release: {
      action: 'Предложить оформить релиз',
      possible_revenue: 1990,
      suggested_message: 'AI уже проанализировал твой материал — самое время оформить релиз. Заберу за тебя всю техническую часть: ISRC, копирайт, заливку.',
    },
    suggest_analysis: {
      action: 'Предложить анализ трека',
      possible_revenue: 590,
      suggested_message: 'Видел, что ты загрузил трек. Хочешь, AURIX AI проанализирует его — даст разбор по миксу, потенциалу, аудитории. Это бесплатно для пробы.',
    },
  } as const;

  /**
   * Главная функция: возвращает следующее действие для пользователя.
   *
   * suggested_message выбирается через A/B (MessageTemplatesService) если
   * сервис доступен и в БД есть шаблоны для code'а. Иначе fallback на
   * хардкоднутый текст из ACTIONS.
   *
   * `template_code` + `template_variant` нужны фронту, чтобы их положить
   * в meta.offer_sent для A/B-атрибуции (см. MessageTemplatesService.getStats).
   */
  async getNextAction(userId: number): Promise<{
    code: keyof typeof NextActionService.ACTIONS | null;
    action: string | null;
    reason: string;
    possible_revenue: number;
    suggested_message: string | null;
    template_code: string | null;
    template_variant: string | null;
  }> {
    // Один запрос — все нужные сигналы сразу.
    const { rows } = await this.pool.query(
      `
      SELECT
        BOOL_OR(event = 'track_uploaded') AS has_track,
        BOOL_OR(event = 'ai_chat') AS has_ai,
        BOOL_OR(event = 'release_created') AS has_release,
        BOOL_OR(event = 'release_submitted') AS has_release_submitted,
        BOOL_OR(event = 'subscription_changed') AS has_payment,
        MAX(created_at) AS last_active,
        MAX(CASE WHEN event = 'subscription_changed' THEN created_at END) AS last_payment
      FROM user_events WHERE user_id = $1
      `,
      [userId],
    ).catch(() => ({ rows: [{}] }));

    const r = rows[0] ?? {};
    const hasTrack = !!r.has_track;
    const hasAi = !!r.has_ai;
    const hasRelease = !!r.has_release || !!r.has_release_submitted;
    const hasPayment = !!r.has_payment;

    // lead_score из profiles (быстрее чем пересчитывать).
    const { rows: profileRows } = await this.pool.query(
      `SELECT lead_score, lead_bucket FROM profiles WHERE user_id = $1`,
      [userId],
    ).catch(() => ({ rows: [] }));
    const score = (profileRows[0]?.lead_score as number | undefined) ?? 0;

    // Правило 1: hot lead перебивает всё. Менеджер должен прямо позвонить/написать.
    if (score > 70) {
      return await this.buildResult(
        'contact_hot_lead',
        `Lead score ${score} > 70 — артист активный, готов покупать`,
      );
    }

    // Правило 2: уже платил, но активность остановилась — upsell.
    if (hasPayment && r.last_payment) {
      const lastPaymentMs = new Date(r.last_payment).getTime();
      const lastActiveMs = r.last_active ? new Date(r.last_active).getTime() : 0;
      const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
      const paymentOlderThan7d = lastPaymentMs < sevenDaysAgo;
      const noRecentActivity = lastActiveMs < sevenDaysAgo;
      if (paymentOlderThan7d && noRecentActivity) {
        return await this.buildResult(
          'upsell_promotion',
          'Оплатил подписку, но не активен 7+ дней — повторная вовлечённость через продвижение',
        );
      }
    }

    // Правило 3: создал релиз, не платил.
    if (hasRelease && !hasPayment) {
      return await this.buildResult(
        'push_to_payment',
        'Создал релиз, но не оплатил дистрибуцию',
      );
    }

    // Правило 4: говорил с AI, нет релиза.
    if (hasAi && !hasRelease) {
      return await this.buildResult(
        'suggest_release',
        'Использовал AI, но не оформил релиз',
      );
    }

    // Правило 5: загрузил трек, нет AI-чата.
    if (hasTrack && !hasAi) {
      return await this.buildResult(
        'suggest_analysis',
        'Загрузил трек, но не воспользовался AI-анализом',
      );
    }

    return {
      code: null,
      action: null,
      reason: 'Нет триггеров',
      possible_revenue: 0,
      suggested_message: null,
      template_code: null,
      template_variant: null,
    };
  }

  /**
   * Сборщик результата: action/reason/possible_revenue из ACTIONS,
   * suggested_message — через MessageTemplatesService.pickVariant если
   * доступен, иначе fallback на хардкоднутый текст.
   */
  private async buildResult(
    code: keyof typeof NextActionService.ACTIONS,
    reason: string,
  ): Promise<{
    code: keyof typeof NextActionService.ACTIONS;
    action: string;
    reason: string;
    possible_revenue: number;
    suggested_message: string;
    template_code: string;
    template_variant: string | null;
  }> {
    const a = NextActionService.ACTIONS[code];
    let message: string = a.suggested_message;
    let variantKey: string | null = null;

    if (this.templates) {
      const picked = await this.templates.pickVariant(code).catch(() => null);
      if (picked) {
        message = picked.message;
        variantKey = picked.variant_key;
      }
    }

    return {
      code,
      action: a.action,
      reason,
      possible_revenue: a.possible_revenue,
      suggested_message: message,
      template_code: code,
      template_variant: variantKey,
    };
  }

  /**
   * Удобство: пересчитать next_action и записать в активный lead'ов.
   * Используется при cron-апдейте leads и в ручных вызовах из UI.
   */
  async refreshAndPersist(userId: number): Promise<void> {
    const next = await this.getNextAction(userId);
    await this.leads.setNextAction(userId, next.action);
  }
}
