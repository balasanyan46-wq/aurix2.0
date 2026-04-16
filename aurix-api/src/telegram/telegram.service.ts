import { Injectable, Inject, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { Pool } from 'pg';
import axios from 'axios';
import { PG_POOL } from '../database/database.module';

const ADMIN_CHAT_ID = process.env.TELEGRAM_CHAT_ID || '139474470';

@Injectable()
export class TelegramService {
  private readonly log = new Logger('TelegramBot');
  private lastUpdateId = 0;

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  // ── Send message via gateway ─────────────────────────────

  async send(text: string, chatId?: string) {
    const gwUrl = process.env.AI_GATEWAY_URL;
    const gwSecret = process.env.AI_GATEWAY_SECRET;
    if (!gwUrl) return;

    try {
      await axios.post(`${gwUrl}/telegram/send`, {
        text,
        chat_id: chatId || ADMIN_CHAT_ID,
        parse_mode: 'Markdown',
      }, {
        headers: { 'X-Gateway-Secret': gwSecret || '', 'Content-Type': 'application/json' },
        timeout: 10000,
      });
    } catch (e: any) {
      this.log.error(`Send failed: ${e.message}`);
    }
  }

  // ── Poll for bot updates every 5 seconds (via EU gateway — Telegram blocked in RU) ──

  @Interval(5000)
  async pollUpdates() {
    const gwUrl = process.env.AI_GATEWAY_URL;
    const gwSecret = process.env.AI_GATEWAY_SECRET;
    if (!gwUrl) return;

    try {
      const { data } = await axios.post(`${gwUrl}/telegram/get-updates`, {
        offset: this.lastUpdateId + 1,
      }, {
        headers: { 'X-Gateway-Secret': gwSecret || '', 'Content-Type': 'application/json' },
        timeout: 10000,
      });

      if (!data?.result || !Array.isArray(data.result)) return;

      for (const update of data.result) {
        this.lastUpdateId = Math.max(this.lastUpdateId, update.update_id);
        const msg = update.message;
        if (!msg?.text) continue;

        const chatId = String(msg.chat.id);
        const text = msg.text.trim();

        // Only respond to admin
        if (chatId !== ADMIN_CHAT_ID) continue;

        if (text === '/stats' || text === '/stats@AURIXMonitor_bot') {
          await this.handleStats(chatId);
        } else if (text === '/users' || text === '/users@AURIXMonitor_bot') {
          await this.handleUsers(chatId);
        } else if (text === '/help' || text === '/start' || text === '/start@AURIXMonitor_bot') {
          await this.handleHelp(chatId);
        }
      }
    } catch (e: any) {
      // Silently fail — gateway might not support get-updates yet
    }
  }

  // ── /stats command ───────────────────────────────────────

  private async handleStats(chatId: string) {
    try {
      const [users, releases, tracks, tickets, payments] = await Promise.all([
        this.pool.query(`SELECT COUNT(*) as cnt FROM users`),
        this.pool.query(`SELECT COUNT(*) as cnt, COUNT(*) FILTER (WHERE status = 'live') as live FROM releases`),
        this.pool.query(`SELECT COUNT(*) as cnt FROM tracks`),
        this.pool.query(`SELECT COUNT(*) as cnt, COUNT(*) FILTER (WHERE status = 'open') as open FROM support_tickets`),
        this.pool.query(`SELECT COUNT(*) as cnt, COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed, COALESCE(SUM(amount) FILTER (WHERE status = 'confirmed'), 0) as revenue FROM payments`),
      ]);

      const today = await this.pool.query(
        `SELECT COUNT(*) as cnt FROM users WHERE created_at >= CURRENT_DATE`,
      );

      const text = [
        `📊 *AURIX Статистика*`,
        ``,
        `👤 Пользователей: *${users.rows[0].cnt}*`,
        `📅 Новых сегодня: *${today.rows[0].cnt}*`,
        ``,
        `💿 Релизов: *${releases.rows[0].cnt}* (live: ${releases.rows[0].live})`,
        `🎵 Треков: *${tracks.rows[0].cnt}*`,
        ``,
        `💰 Платежей: *${payments.rows[0].cnt}* (confirmed: ${payments.rows[0].confirmed})`,
        `💵 Выручка: *${Math.round(Number(payments.rows[0].revenue) / 100)} ₽*`,
        ``,
        `🎫 Тикетов: *${tickets.rows[0].cnt}* (открытых: ${tickets.rows[0].open})`,
      ].join('\n');

      await this.send(text, chatId);
    } catch (e: any) {
      await this.send(`❌ Ошибка получения статистики: ${e.message}`, chatId);
    }
  }

  // ── /users command ───────────────────────────────────────

  private async handleUsers(chatId: string) {
    try {
      const total = await this.pool.query(`SELECT COUNT(*) as cnt FROM users`);
      const today = await this.pool.query(
        `SELECT COUNT(*) as cnt FROM users WHERE created_at >= CURRENT_DATE`,
      );
      const week = await this.pool.query(
        `SELECT COUNT(*) as cnt FROM users WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'`,
      );
      const month = await this.pool.query(
        `SELECT COUNT(*) as cnt FROM users WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'`,
      );
      const verified = await this.pool.query(
        `SELECT COUNT(*) as cnt FROM users WHERE email_verified = true`,
      );
      const withSub = await this.pool.query(
        `SELECT COUNT(DISTINCT user_id) as cnt FROM billing_subscriptions WHERE status = 'active'`,
      );

      // Last 5 registrations
      const recent = await this.pool.query(
        `SELECT u.email, u.created_at, p.display_name
         FROM users u LEFT JOIN profiles p ON p.user_id = u.id
         ORDER BY u.created_at DESC LIMIT 5`,
      );

      const recentList = recent.rows.map((r: any) => {
        const name = r.display_name || r.email?.split('@')[0] || '?';
        const date = new Date(r.created_at).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' });
        return `  • ${name} — ${date}`;
      }).join('\n');

      const text = [
        `👥 *AURIX Пользователи*`,
        ``,
        `Всего: *${total.rows[0].cnt}*`,
        `Верифицировано: *${verified.rows[0].cnt}*`,
        `С подпиской: *${withSub.rows[0].cnt}*`,
        ``,
        `📅 Сегодня: *+${today.rows[0].cnt}*`,
        `📅 За неделю: *+${week.rows[0].cnt}*`,
        `📅 За месяц: *+${month.rows[0].cnt}*`,
        ``,
        `🆕 Последние регистрации:`,
        recentList,
      ].join('\n');

      await this.send(text, chatId);
    } catch (e: any) {
      await this.send(`❌ Ошибка: ${e.message}`, chatId);
    }
  }

  // ── /help command ────────────────────────────────────────

  private async handleHelp(chatId: string) {
    const text = [
      `🤖 *AURIX Monitor Bot*`,
      ``,
      `Доступные команды:`,
      `/stats — Общая статистика платформы`,
      `/users — Детальная информация по пользователям`,
      `/help — Список команд`,
      ``,
      `Автоматические уведомления:`,
      `🔴 5xx ошибки сервера`,
      `⚠️ Спайки 4xx ошибок`,
      `💬 Новые обращения в поддержку`,
    ].join('\n');

    await this.send(text, chatId);
  }

  // ── Public method for support notifications ──────────────

  async notifySupportTicket(subject: string, userName: string) {
    const text = [
      `💬 *Новое обращение в поддержку*`,
      ``,
      `От: *${userName}*`,
      `Тема: ${subject}`,
      ``,
      `🕐 ${new Date().toLocaleTimeString('ru-RU', { timeZone: 'Europe/Moscow' })}`,
    ].join('\n');

    await this.send(text);
  }
}
