import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { createHash } from 'crypto';
import { PG_POOL } from '../database/database.module';

// ── CASTING PLANS (prices in kopecks) ──
const CASTING_PLANS: Record<string, { price: number; label: string; perks: string[] }> = {
  base: {
    price: 99000, // 990 ₽
    label: 'BASE',
    perks: ['Участие в отборе', 'Выступление 5 минут'],
  },
  pro: {
    price: 299000, // 2990 ₽
    label: 'PRO',
    perks: ['Участие в отборе', 'Выступление 10 минут', 'Обратная связь от жюри', 'Видеозапись выступления'],
  },
  vip: {
    price: 599000, // 5990 ₽
    label: 'VIP',
    perks: ['Участие в отборе', 'Выступление 15 минут', 'Персональная консультация A&R', 'Видеозапись + промо', 'Приоритетное рассмотрение контракта'],
  },
  audience: {
    price: 100000, // 1000 ₽
    label: 'ЗРИТЕЛЬ',
    perks: ['Вход на мероприятие', 'Просмотр выступлений'],
  },
};

const TBANK_BASE = 'https://securepay.tinkoff.ru/v2';

@Injectable()
export class CastingService {
  private readonly log: Logger;
  private readonly terminalKey: string;
  private readonly password: string;
  private readonly appUrl: string;

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {
    this.log = new Logger('Casting');
    this.terminalKey = process.env.TINKOFF_TERMINAL_KEY || '';
    this.password = process.env.TINKOFF_PASSWORD || '';
    this.appUrl = process.env.APP_URL || 'https://aurixmusic.ru';
  }

  private generateToken(params: Record<string, any>): string {
    const data: Record<string, any> = { ...params, Password: this.password };
    delete data.Token;
    delete data.Receipt;
    delete data.DATA;
    const sorted = Object.keys(data).sort();
    const concatenated = sorted.map((k) => String(data[k])).join('');
    return createHash('sha256').update(concatenated).digest('hex');
  }

  getPlans() {
    return CASTING_PLANS;
  }

  async getSlots(city: string) {
    const { rows } = await this.pool.query(
      `SELECT
         50 - COUNT(*)::int AS remaining,
         COUNT(*)::int AS taken
       FROM casting_applications
       WHERE city = $1 AND status != 'cancelled'`,
      [city],
    );
    return { total: 50, remaining: Math.max(0, rows[0]?.remaining ?? 50), taken: rows[0]?.taken ?? 0 };
  }

  async createParticipation(dto: {
    name: string;
    phone: string;
    city: string;
    plan: string;
    quantity?: number;
  }) {
    const plan = CASTING_PLANS[dto.plan];
    if (!plan) throw new Error(`Invalid plan: ${dto.plan}`);

    const qty = dto.plan === 'audience' ? (dto.quantity || 1) : 1;
    const totalAmount = plan.price * qty;

    // Check slots (only for artist plans)
    if (dto.plan !== 'audience') {
      const slots = await this.getSlots(dto.city);
      if (slots.remaining <= 0) throw new Error('Все места заняты в этом городе');
    }

    const orderId = `cast_${dto.plan}_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;

    // Create pending record
    const { rows } = await this.pool.query(
      `INSERT INTO casting_applications
         (user_id, name, artist_name, phone, city, media_link, about, status, plan, order_id, amount, created_at)
       VALUES (NULL, $1, $1, $2, $3, '', $7, 'pending_payment', $4, $5, $6, NOW())
       RETURNING *`,
      [dto.name, dto.phone, dto.city, dto.plan, orderId, totalAmount, qty > 1 ? `${qty} билетов` : ''],
    );
    const application = rows[0];

    const description = dto.plan === 'audience'
      ? `КОД АРТИСТА — Зритель x${qty} (${dto.city})`
      : `КОД АРТИСТА — ${plan.label} (${dto.city})`;

    // Create T-Bank payment
    const initParams: Record<string, any> = {
      TerminalKey: this.terminalKey,
      Amount: totalAmount,
      OrderId: orderId,
      Description: description,
      PayType: 'O',
      NotificationURL: `${this.appUrl}/api/casting/webhook`,
      SuccessURL: `${this.appUrl}/casting/success?orderId=${orderId}`,
      FailURL: `${this.appUrl}/casting?status=fail`,
    };
    initParams.Token = this.generateToken(initParams);

    try {
      const resp = await fetch(`${TBANK_BASE}/Init`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(initParams),
      });
      const data = await resp.json() as Record<string, any>;

      if (data.Success && data.PaymentURL) {
        await this.pool.query(
          `UPDATE casting_applications SET tbank_payment_id = $1, payment_url = $2 WHERE id = $3`,
          [String(data.PaymentId), data.PaymentURL, application.id],
        );
        this.log.log(`Casting payment created: order=${orderId} plan=${dto.plan} city=${dto.city}`);
        return { success: true, paymentUrl: data.PaymentURL, orderId };
      }

      await this.pool.query(
        `UPDATE casting_applications SET status = 'cancelled' WHERE id = $1`,
        [application.id],
      );
      return { success: false, error: data.Message || 'Payment init failed' };
    } catch (e: any) {
      this.log.error(`Casting payment error: ${e.message}`);
      return { success: false, error: 'Payment service unavailable' };
    }
  }

  verifyToken(body: Record<string, any>): boolean {
    const receivedToken = body.Token;
    if (!receivedToken) return false;
    const expected = this.generateToken(body);
    return expected === receivedToken;
  }

  async handleWebhook(body: Record<string, any>): Promise<{ ok: boolean }> {
    const { OrderId, Status } = body;
    if (!OrderId || !Status) return { ok: false };

    // Only handle casting orders
    if (!OrderId.startsWith('cast_')) return { ok: false };

    this.log.log(`Casting webhook: order=${OrderId} status=${Status}`);

    if (!this.verifyToken(body)) {
      this.log.error(`Casting webhook signature failed for ${OrderId}`);
      return { ok: false };
    }

    if (Status === 'CONFIRMED') {
      await this.pool.query(
        `UPDATE casting_applications SET status = 'paid', paid_at = NOW() WHERE order_id = $1 AND status = 'pending_payment'`,
        [OrderId],
      );
      this.log.log(`Casting PAID: ${OrderId}`);
    } else if (['REJECTED', 'CANCELED', 'DEADLINE_EXPIRED'].includes(Status)) {
      await this.pool.query(
        `UPDATE casting_applications SET status = 'cancelled' WHERE order_id = $1 AND status = 'pending_payment'`,
        [OrderId],
      );
    }
    return { ok: true };
  }

  async findByOrderId(orderId: string) {
    const { rows } = await this.pool.query(
      `SELECT * FROM casting_applications WHERE order_id = $1`,
      [orderId],
    );
    return rows[0] || null;
  }

  async findAll(filters?: { city?: string; status?: string; search?: string }) {
    let query = `SELECT * FROM casting_applications WHERE status != 'pending_payment' AND status != 'cancelled'`;
    const params: any[] = [];
    let idx = 1;

    if (filters?.city) {
      query += ` AND city = $${idx++}`;
      params.push(filters.city);
    }
    if (filters?.status) {
      query += ` AND status = $${idx++}`;
      params.push(filters.status);
    }
    if (filters?.search) {
      query += ` AND (name ILIKE $${idx} OR artist_name ILIKE $${idx})`;
      params.push(`%${filters.search}%`);
      idx++;
    }

    query += ` ORDER BY created_at DESC`;
    const { rows } = await this.pool.query(query, params);
    return rows;
  }

  async findById(id: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM casting_applications WHERE id = $1`,
      [id],
    );
    return rows[0] || null;
  }

  async updateStatus(id: number, status: string) {
    const allowed = ['paid', 'approved', 'rejected', 'invited'];
    if (!allowed.includes(status)) throw new Error(`Invalid status: ${status}`);
    const { rows } = await this.pool.query(
      `UPDATE casting_applications SET status = $1 WHERE id = $2 RETURNING *`,
      [status, id],
    );
    return rows[0];
  }

  async getStats() {
    const { rows } = await this.pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE status NOT IN ('pending_payment','cancelled') AND plan != 'audience')::int AS total,
        COUNT(*) FILTER (WHERE status = 'paid' AND plan != 'audience')::int AS paid_count,
        COUNT(*) FILTER (WHERE status = 'approved')::int AS approved_count,
        COUNT(*) FILTER (WHERE status = 'rejected')::int AS rejected_count,
        COUNT(*) FILTER (WHERE status = 'invited')::int AS invited_count,
        COUNT(*) FILTER (WHERE status NOT IN ('pending_payment','cancelled') AND plan = 'audience')::int AS audience_count,
        COALESCE(SUM(amount) FILTER (WHERE status NOT IN ('pending_payment','cancelled')), 0)::bigint AS total_revenue
      FROM casting_applications
    `);
    return rows[0];
  }
}
