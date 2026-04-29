import { Injectable, Inject, Logger, Optional } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { TelegramService } from '../telegram/telegram.service';

/**
 * SalesAlertsService — real-time оповещения менеджеров через Telegram.
 *
 * Отправляет в TG (через TelegramService.send → AI Gateway) три типа сигналов:
 *   1) payment_failed — детектится в момент webhook через метод
 *      `notifyPaymentFailed` (вызывается из TBankService — best-effort)
 *   2) urgent_ticket   — поллим раз в 15 минут support_tickets со status=open
 *      и age > 24h, шлём один раз (трекинг — admin_logs alert_sent)
 *   3) new_hot_lead    — поллим раз в 15 минут leads со status='new' и
 *      bucket='hot' и без assigned_to, шлём в общий чат
 *
 * Дедупликация: для каждого alert ключ (type + target_id) пишется в
 * admin_logs c action='sales_alert_sent', и при повторном poll'е мы
 * пропускаем уже отправленные.
 */
@Injectable()
export class SalesAlertsService {
  private readonly log = new Logger(SalesAlertsService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    @Optional() private readonly tg?: TelegramService,
  ) {}

  /**
   * Вызывается из TBankService webhook'а при payment_failed.
   * Best-effort — не падает если TG недоступен.
   */
  async notifyPaymentFailed(payment: {
    id: number;
    user_id: number;
    plan: string;
    amount: number;
  }): Promise<void> {
    if (!this.tg) return;
    const amountRub = Math.round(payment.amount / 100);
    const text = [
      `⚠️ *Failed payment*`,
      `User #${payment.user_id} · план ${payment.plan} · ${amountRub} ₽`,
      `Payment ID: ${payment.id}`,
      `\nЗайди в админку → Action Center и предложи помощь.`,
    ].join('\n');
    await this.tg.send(text).catch(() => {});
    await this.markAlertSent('payment_failed', String(payment.id));
  }

  /**
   * Cron: проверка urgent tickets > 24h без ответа.
   * Если открыт > 24h, не закрыт, и алерт ещё не слался — пингуем.
   */
  @Cron(CronExpression.EVERY_30_MINUTES, { name: 'sales_alerts_tickets' })
  async cronUrgentTickets(): Promise<void> {
    if (!this.tg) return;
    const { rows } = await this.pool.query(`
      SELECT t.id, t.subject, t.user_id, t.created_at, u.email
        FROM support_tickets t
        LEFT JOIN users u ON u.id::text = t.user_id::text
       WHERE t.status = 'open'
         AND t.created_at < now() - interval '24 hours'
         AND t.created_at >= now() - interval '7 days'
         AND NOT EXISTS (
           SELECT 1 FROM admin_logs al
            WHERE al.action = 'sales_alert_sent'
              AND al.target_type = 'urgent_ticket'
              AND al.target_id = t.id::text
         )
       LIMIT 5
    `).catch(() => ({ rows: [] }));

    for (const r of rows as any[]) {
      const text = [
        `🆘 *Urgent ticket > 24h*`,
        `${r.subject}`,
        `от ${r.email ?? `user#${r.user_id}`}`,
        `Открыт ${new Date(r.created_at).toLocaleString('ru')}`,
      ].join('\n');
      await this.tg.send(text).catch(() => {});
      await this.markAlertSent('urgent_ticket', String(r.id));
    }
  }

  /**
   * Cron: новые hot leads без assigned_to. Каждые 30 минут — менеджеры
   * получают пинг что появился свежий горячий клиент.
   */
  @Cron(CronExpression.EVERY_30_MINUTES, { name: 'sales_alerts_hot_leads' })
  async cronNewHotLeads(): Promise<void> {
    if (!this.tg) return;
    const { rows } = await this.pool.query(`
      SELECT l.id, l.user_id, l.lead_score, l.next_action, u.email
        FROM leads l
        LEFT JOIN users u ON u.id = l.user_id
       WHERE l.lead_bucket = 'hot'
         AND l.status = 'new'
         AND l.assigned_to IS NULL
         AND l.created_at >= now() - interval '24 hours'
         AND NOT EXISTS (
           SELECT 1 FROM admin_logs al
            WHERE al.action = 'sales_alert_sent'
              AND al.target_type = 'new_hot_lead'
              AND al.target_id = l.id::text
         )
       LIMIT 5
    `).catch(() => ({ rows: [] }));

    for (const r of rows as any[]) {
      const text = [
        `🔥 *New hot lead*`,
        `${r.email ?? `user#${r.user_id}`}`,
        `Score: ${r.lead_score}/100`,
        r.next_action ? `→ ${r.next_action}` : '',
        `\nОткрой админку → Leads → возьми в работу.`,
      ].filter(Boolean).join('\n');
      await this.tg.send(text).catch(() => {});
      await this.markAlertSent('new_hot_lead', String(r.id));
    }
  }

  /**
   * Идемпотентность: пишем в admin_logs что алерт отправлен.
   * Дальнейшие cron-итерации не дублируют отправку.
   */
  private async markAlertSent(type: string, targetId: string): Promise<void> {
    try {
      await this.pool.query(
        `INSERT INTO admin_logs (admin_id, action, target_type, target_id, details)
         VALUES (NULL, 'sales_alert_sent', $1, $2, $3)`,
        [type, targetId, JSON.stringify({ at: new Date().toISOString() })],
      );
    } catch (e: any) {
      this.log.warn(`markAlertSent failed: ${e.message}`);
    }
  }
}
