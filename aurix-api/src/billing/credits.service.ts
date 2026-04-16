import { Injectable, Inject, Logger, HttpException, HttpStatus, OnModuleInit } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

export interface SpendResult {
  ok: boolean;
  balance: number;
  cost: number;
  transactionId?: number;
}

@Injectable()
export class CreditsService implements OnModuleInit {
  private readonly log = new Logger('Credits');
  private costCache = new Map<string, number>();

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async onModuleInit() {
    await this.loadCosts();
  }

  /** Load cost config into memory. */
  async loadCosts() {
    try {
      const { rows } = await this.pool.query('SELECT action_key, cost FROM credit_costs');
      this.costCache.clear();
      for (const r of rows) this.costCache.set(r.action_key, r.cost);
      this.log.log(`Loaded ${this.costCache.size} credit costs`);
    } catch (e) {
      this.log.warn(`Failed to load costs: ${e}`);
    }
  }

  /** Get cost for an action. */
  getCost(actionKey: string): number {
    return this.costCache.get(actionKey) ?? 1;
  }

  // ── BALANCE ──────────────────────────────────────────────

  /** Get or create balance for a user. */
  async getBalance(userId: number): Promise<number> {
    const { rows } = await this.pool.query(
      `INSERT INTO user_balance (user_id, credits) VALUES ($1, 0)
       ON CONFLICT (user_id) DO NOTHING
       RETURNING credits`,
      [userId],
    );
    if (rows.length) return rows[0].credits;
    const { rows: existing } = await this.pool.query(
      'SELECT credits FROM user_balance WHERE user_id = $1', [userId],
    );
    return existing[0]?.credits ?? 0;
  }

  /** Check if user can afford an action. */
  async canAfford(userId: number, actionKey: string): Promise<{ ok: boolean; balance: number; cost: number }> {
    const cost = this.getCost(actionKey);
    const balance = await this.getBalance(userId);
    return { ok: balance >= cost, balance, cost };
  }

  // ── SPEND ────────────────────────────────────────────────

  /**
   * Atomically spend credits. Returns the result.
   * Throws NO_CREDITS if insufficient balance.
   */
  async spend(userId: number, actionKey: string, reason?: string): Promise<SpendResult> {
    const cost = this.getCost(actionKey);
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Ensure row exists
      await client.query(
        'INSERT INTO user_balance (user_id, credits) VALUES ($1, 0) ON CONFLICT DO NOTHING',
        [userId],
      );

      // Atomic debit with check
      const { rows } = await client.query(
        `UPDATE user_balance SET credits = credits - $2, updated_at = now()
         WHERE user_id = $1 AND credits >= $2
         RETURNING credits`,
        [userId, cost],
      );

      if (!rows.length) {
        await client.query('ROLLBACK');
        const bal = await this.getBalance(userId);
        return { ok: false, balance: bal, cost };
      }

      const newBalance = rows[0].credits;

      // Log transaction
      const { rows: txRows } = await client.query(
        `INSERT INTO credit_transactions (user_id, type, amount, balance_after, reason, meta)
         VALUES ($1, 'spend', $2, $3, $4, $5) RETURNING id`,
        [userId, -cost, newBalance, reason || actionKey, JSON.stringify({ action_key: actionKey })],
      );

      await client.query('COMMIT');

      this.log.log(`User ${userId} spent ${cost} credits (${actionKey}), balance: ${newBalance}`);

      // Notify user when credits drop below 100
      if (newBalance <= 100 && newBalance + cost > 100) {
        this.pool.query(
          `INSERT INTO notifications (user_id, title, message, type, meta) VALUES ($1, $2, $3, $4, $5)`,
          [userId, 'Кредиты заканчиваются', `Осталось ${newBalance} кредитов. Пополните баланс чтобы продолжить использовать AI.`, 'warning', JSON.stringify({ balance: newBalance })],
        ).catch(() => {});
      }
      // Notify when credits hit zero
      if (newBalance <= 0 && newBalance + cost > 0) {
        this.pool.query(
          `INSERT INTO notifications (user_id, title, message, type, meta) VALUES ($1, $2, $3, $4, $5)`,
          [userId, 'Кредиты закончились', 'Ваш баланс кредитов исчерпан. Пополните баланс для использования AI функций.', 'warning', JSON.stringify({ balance: 0 })],
        ).catch(() => {});
      }

      return { ok: true, balance: newBalance, cost, transactionId: txRows[0].id };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  // ── TOP-UP ───────────────────────────────────────────────

  /** Add credits to user balance. */
  async topup(userId: number, amount: number, type: 'topup' | 'bonus' | 'plan_grant' | 'refund', reason?: string): Promise<{ balance: number; transactionId: number }> {
    if (amount <= 0) throw new HttpException('amount must be positive', HttpStatus.BAD_REQUEST);

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        'INSERT INTO user_balance (user_id, credits) VALUES ($1, 0) ON CONFLICT DO NOTHING',
        [userId],
      );

      const { rows } = await client.query(
        `UPDATE user_balance SET credits = credits + $2, updated_at = now()
         WHERE user_id = $1 RETURNING credits`,
        [userId, amount],
      );

      const newBalance = rows[0].credits;

      const { rows: txRows } = await client.query(
        `INSERT INTO credit_transactions (user_id, type, amount, balance_after, reason)
         VALUES ($1, $2, $3, $4, $5) RETURNING id`,
        [userId, type, amount, newBalance, reason || `${type}: +${amount}`],
      );

      await client.query('COMMIT');

      this.log.log(`User ${userId} topped up ${amount} (${type}), balance: ${newBalance}`);
      return { balance: newBalance, transactionId: txRows[0].id };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  // ── PLAN GRANT ───────────────────────────────────────────

  /** Grant credits based on plan. Called when user subscribes/upgrades. */
  async grantPlanCredits(userId: number, planId: string): Promise<{ balance: number; granted: number }> {
    const { rows } = await this.pool.query(
      'SELECT credits FROM plan_credits WHERE plan_id = $1', [planId],
    );
    const credits = rows[0]?.credits ?? 0;
    if (credits <= 0) return { balance: await this.getBalance(userId), granted: 0 };

    const result = await this.topup(userId, credits, 'plan_grant', `План: ${planId} (+${credits})`);
    return { balance: result.balance, granted: credits };
  }

  // ── TRANSACTIONS ─────────────────────────────────────────

  /** Get transactions for a user. */
  async getTransactions(userId: number, limit = 50, offset = 0) {
    const { rows } = await this.pool.query(
      `SELECT * FROM credit_transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );
    return rows;
  }

  /** Admin: all transactions. */
  async allTransactions(opts: { userId?: number; type?: string; limit?: number; offset?: number }) {
    let q = 'SELECT t.*, u.email FROM credit_transactions t LEFT JOIN users u ON u.id = t.user_id WHERE 1=1';
    const p: any[] = [];
    if (opts.userId) { p.push(opts.userId); q += ` AND t.user_id = $${p.length}`; }
    if (opts.type) { p.push(opts.type); q += ` AND t.type = $${p.length}`; }
    q += ' ORDER BY t.created_at DESC';
    p.push(opts.limit || 100); q += ` LIMIT $${p.length}`;
    p.push(opts.offset || 0); q += ` OFFSET $${p.length}`;
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  /** Admin: get all costs config. */
  async getCosts() {
    const { rows } = await this.pool.query('SELECT * FROM credit_costs ORDER BY action_key');
    return rows;
  }

  /** Admin: update a cost. */
  async updateCost(actionKey: string, cost: number) {
    await this.pool.query(
      'UPDATE credit_costs SET cost = $2, updated_at = now() WHERE action_key = $1',
      [actionKey, cost],
    );
    await this.loadCosts();
  }

  /** Admin: get plan credits config. */
  async getPlanCredits() {
    const { rows } = await this.pool.query('SELECT * FROM plan_credits ORDER BY plan_id');
    return rows;
  }

  // ── ORDER-BASED PAYMENT ─────────────────────────────────

  /** Create a pending order. Returns orderId for the client. */
  async createOrder(
    userId: number,
    credits: number,
    priceLabel: string,
  ): Promise<{ orderId: string }> {
    if (credits <= 0 || credits > 10000) {
      throw new HttpException('Invalid credits amount (1-10000)', HttpStatus.BAD_REQUEST);
    }

    // Expire stale orders first
    await this.pool.query(
      `UPDATE billing_orders SET status = 'expired', updated_at = now()
       WHERE user_id = $1 AND status = 'pending' AND created_at < now() - interval '30 minutes'`,
      [userId],
    ).catch(() => {});

    const { rows } = await this.pool.query(
      `INSERT INTO billing_orders (user_id, amount, credits, price_label, status)
       VALUES ($1, $2, $3, $4, 'pending')
       RETURNING id`,
      [userId, credits, credits, priceLabel],
    );

    return { orderId: rows[0].id };
  }

  /** Confirm a pending order and grant credits. Idempotent. */
  async confirmOrder(
    userId: number,
    orderId: string,
  ): Promise<{ ok: boolean; balance: number; credits: number; error?: string }> {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Lock the order row for update to prevent double-confirm
      const { rows } = await client.query(
        `SELECT id, user_id, credits, status
         FROM billing_orders
         WHERE id = $1
         FOR UPDATE`,
        [orderId],
      );

      if (!rows.length) {
        await client.query('ROLLBACK');
        return { ok: false, balance: 0, credits: 0, error: 'Order not found' };
      }

      const order = rows[0];

      // Security: order must belong to this user
      if (order.user_id !== userId) {
        await client.query('ROLLBACK');
        return { ok: false, balance: 0, credits: 0, error: 'Order does not belong to user' };
      }

      // Already paid — idempotent return
      if (order.status === 'paid') {
        await client.query('ROLLBACK');
        const balance = await this.getBalance(userId);
        return { ok: true, balance, credits: order.credits };
      }

      // Must be pending
      if (order.status !== 'pending') {
        await client.query('ROLLBACK');
        return { ok: false, balance: 0, credits: 0, error: `Order status is "${order.status}", expected "pending"` };
      }

      // Grant credits
      await client.query(
        'INSERT INTO user_balance (user_id, credits) VALUES ($1, 0) ON CONFLICT DO NOTHING',
        [userId],
      );

      const { rows: balRows } = await client.query(
        `UPDATE user_balance SET credits = credits + $2, updated_at = now()
         WHERE user_id = $1 RETURNING credits`,
        [userId, order.credits],
      );

      const newBalance = balRows[0].credits;

      // Log transaction
      await client.query(
        `INSERT INTO credit_transactions (user_id, type, amount, balance_after, reason, meta)
         VALUES ($1, 'topup', $2, $3, $4, $5)`,
        [
          userId,
          order.credits,
          newBalance,
          `Покупка: +${order.credits} кредитов`,
          JSON.stringify({ order_id: orderId }),
        ],
      );

      // Mark order as paid
      await client.query(
        `UPDATE billing_orders SET status = 'paid', confirmed_at = now(), updated_at = now()
         WHERE id = $1`,
        [orderId],
      );

      await client.query('COMMIT');

      this.log.log(`Order ${orderId} confirmed — user ${userId} received ${order.credits} credits, balance: ${newBalance}`);
      return { ok: true, balance: newBalance, credits: order.credits };
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }

  /** Get user's orders. */
  async getOrders(userId: number, limit = 20) {
    const { rows } = await this.pool.query(
      `SELECT id, credits, price_label, status, created_at, confirmed_at
       FROM billing_orders WHERE user_id = $1
       ORDER BY created_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows;
  }

  /** Admin: all orders. */
  async allOrders(opts: { status?: string; limit?: number; offset?: number }) {
    let q = `SELECT o.*, u.email FROM billing_orders o LEFT JOIN users u ON u.id = o.user_id WHERE 1=1`;
    const p: any[] = [];
    if (opts.status) { p.push(opts.status); q += ` AND o.status = $${p.length}`; }
    q += ' ORDER BY o.created_at DESC';
    p.push(opts.limit || 50); q += ` LIMIT $${p.length}`;
    p.push(opts.offset || 0); q += ` OFFSET $${p.length}`;
    const { rows } = await this.pool.query(q, p);
    return rows;
  }

  /** Admin: revenue stats. */
  async stats() {
    const [total, today, byType, topSpenders] = await Promise.all([
      this.pool.query("SELECT count(*)::int AS c, COALESCE(sum(ABS(amount)),0)::int AS total FROM credit_transactions WHERE type = 'spend'"),
      this.pool.query("SELECT count(*)::int AS c, COALESCE(sum(ABS(amount)),0)::int AS total FROM credit_transactions WHERE type = 'spend' AND created_at >= current_date"),
      this.pool.query("SELECT type, count(*)::int AS c, sum(amount)::int AS total FROM credit_transactions GROUP BY type ORDER BY c DESC"),
      this.pool.query(`
        SELECT t.user_id, u.email, sum(ABS(t.amount))::int AS spent
        FROM credit_transactions t LEFT JOIN users u ON u.id = t.user_id
        WHERE t.type = 'spend' AND t.created_at >= current_date - 30
        GROUP BY t.user_id, u.email ORDER BY spent DESC LIMIT 10
      `),
    ]);

    return {
      total_spend_ops: total.rows[0].c,
      total_credits_spent: total.rows[0].total,
      today_ops: today.rows[0].c,
      today_credits: today.rows[0].total,
      by_type: byType.rows,
      top_spenders_30d: topSpenders.rows,
    };
  }
}
