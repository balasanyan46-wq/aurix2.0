import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { createHash } from 'crypto';
import { PG_POOL } from '../database/database.module';
import { CreditsService } from '../billing/credits.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ReferralService } from '../referral/referral.service';

// ── PRICING ──────────────────────────────────────────────

/** Subscription prices in kopecks */
const PLAN_PRICES: Record<string, Record<string, number>> = {
  monthly: {
    start: 99000,         // 990 ₽
    breakthrough: 199000,  // 1990 ₽
    empire: 399000,       // 3990 ₽
  },
  yearly: {
    start: 950400,         // 9504 ₽
    breakthrough: 1910400,  // 19104 ₽
    empire: 3830400,       // 38304 ₽
  },
};

const PLAN_LABELS: Record<string, string> = {
  start: 'AURIX Старт',
  breakthrough: 'AURIX Прорыв',
  empire: 'AURIX Империя',
};

/** Credit package config */
const CREDIT_PACKAGES: Record<string, { credits: number; price: number; label: string }> = {
  small:  { credits: 100,  price: 49000,  label: '100 кредитов' },
  medium: { credits: 500,  price: 199000, label: '500 кредитов' },
  large:  { credits: 1000, price: 349000, label: '1000 кредитов' },
};

const TBANK_BASE = 'https://securepay.tinkoff.ru/v2';

@Injectable()
export class TBankService {
  private readonly log = new Logger('TBank');
  private readonly terminalKey: string;
  private readonly password: string;
  private readonly appUrl: string;

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly credits: CreditsService,
    private readonly notifications: NotificationsService,
    private readonly referral: ReferralService,
  ) {
    this.terminalKey = process.env.TINKOFF_TERMINAL_KEY || '';
    this.password = process.env.TINKOFF_PASSWORD || '';
    this.appUrl = process.env.APP_URL || 'https://aurixmusic.ru';
    if (!this.terminalKey || !this.password) {
      this.log.error('CRITICAL: TINKOFF_TERMINAL_KEY or TINKOFF_PASSWORD not set — payments will not work!');
    }
  }

  // ══════════════════════════════════════════════════════════
  // T-BANK CRYPTO
  // ══════════════════════════════════════════════════════════

  private generateToken(params: Record<string, any>): string {
    const data: Record<string, any> = { ...params, Password: this.password };
    // T-Bank API: exclude non-primitive and meta fields from token
    delete data.Token;
    delete data.Receipt;
    delete data.DATA;
    delete data.Shops;
    delete data.Receipts;

    const sorted = Object.keys(data).sort();
    const concatenated = sorted.map((k) => String(data[k])).join('');
    return createHash('sha256').update(concatenated).digest('hex');
  }

  verifyToken(body: Record<string, any>): boolean {
    const receivedToken = body.Token;
    if (!receivedToken) return false;
    return this.generateToken(body) === receivedToken;
  }

  private async tbankPost(endpoint: string, params: Record<string, any>): Promise<any> {
    params.TerminalKey = this.terminalKey;
    params.Token = this.generateToken(params);

    const resp = await fetch(`${TBANK_BASE}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    });
    return resp.json();
  }

  // ══════════════════════════════════════════════════════════
  // CREATE SUBSCRIPTION PAYMENT (with Recurrent)
  // ══════════════════════════════════════════════════════════

  async createPayment(
    userId: number,
    plan: string,
    billingPeriod: string = 'monthly',
  ): Promise<{ success: boolean; paymentUrl?: string; orderId?: string; error?: string }> {
    const period = billingPeriod === 'yearly' ? 'yearly' : 'monthly';
    const prices = PLAN_PRICES[period];
    if (!prices || !prices[plan]) {
      return { success: false, error: `Invalid plan: ${plan}` };
    }

    const amount = prices[plan];
    const orderId = `sub_${userId}_${plan}_${Date.now()}`;
    const description = `${PLAN_LABELS[plan] || plan} (${period === 'yearly' ? 'год' : 'месяц'})`;

    const { rows } = await this.pool.query(
      `INSERT INTO payments (user_id, plan, billing_period, amount, status, order_id, payment_type)
       VALUES ($1, $2, $3, $4, 'pending', $5, 'subscription')
       RETURNING id`,
      [userId, plan, period, amount, orderId],
    );
    const paymentId = rows[0].id;

    if (!this.terminalKey || !this.password) {
      this.log.error('Cannot create payment: TINKOFF_TERMINAL_KEY or TINKOFF_PASSWORD not configured');
      return { success: false, error: 'Платёжная система не настроена. Обратитесь в поддержку.' };
    }

    const initParams: Record<string, any> = {
      TerminalKey: this.terminalKey,
      Amount: amount,
      OrderId: orderId,
      Description: description,
      PayType: 'O', // One-stage payment (immediate charge)
      CustomerKey: String(userId),
      NotificationURL: `${this.appUrl}/api/payments/webhook`,
      SuccessURL: `${this.appUrl}/payment-result?orderId=${orderId}&status=success`,
      FailURL: `${this.appUrl}/payment-result?orderId=${orderId}&status=fail`,
    };

    initParams.Token = this.generateToken(initParams);

    try {
      const resp = await fetch(`${TBANK_BASE}/Init`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(initParams),
      });
      const data = await resp.json() as Record<string, any>;

      this.log.log(`Init response: Success=${data.Success} PaymentId=${data.PaymentId} Status=${data.Status} URL=${data.PaymentURL ? 'yes' : 'no'} ErrorCode=${data.ErrorCode || 'none'} Message=${data.Message || 'none'}`);

      if (data.Success && data.PaymentURL) {
        await this.pool.query(
          `UPDATE payments SET tbank_payment_id = $1, payment_url = $2, updated_at = now()
           WHERE id = $3`,
          [String(data.PaymentId), data.PaymentURL, paymentId],
        );
        this.log.log(`Subscription payment created: order=${orderId} plan=${plan} amount=${amount}`);
        return { success: true, paymentUrl: data.PaymentURL, orderId };
      }

      await this.pool.query(
        `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
        [paymentId],
      );
      this.log.error(`T-Bank Init failed: ${JSON.stringify(data)}`);
      return { success: false, error: data.Message || data.Details || 'T-Bank Init failed' };
    } catch (e: any) {
      this.log.error(`T-Bank Init error: ${e.message}`);
      return { success: false, error: 'Payment service unavailable' };
    }
  }

  // ══════════════════════════════════════════════════════════
  // CREATE CREDITS PURCHASE
  // ══════════════════════════════════════════════════════════

  async createCreditsPurchase(
    userId: number,
    packageId: string,
  ): Promise<{ success: boolean; paymentUrl?: string; orderId?: string; error?: string }> {
    const pkg = CREDIT_PACKAGES[packageId];
    if (!pkg) {
      return { success: false, error: `Invalid package: ${packageId}. Use: small, medium, large` };
    }

    const orderId = `cred_${userId}_${packageId}_${Date.now()}`;

    const { rows } = await this.pool.query(
      `INSERT INTO payments (user_id, plan, billing_period, amount, status, order_id, payment_type, credits_amount, credit_package)
       VALUES ($1, 'credits', 'one_time', $2, 'pending', $3, 'credits', $4, $5)
       RETURNING id`,
      [userId, pkg.price, orderId, pkg.credits, packageId],
    );
    const paymentId = rows[0].id;

    const initParams: Record<string, any> = {
      TerminalKey: this.terminalKey,
      Amount: pkg.price,
      OrderId: orderId,
      Description: `AURIX ${pkg.label}`,
      PayType: 'O',
      CustomerKey: String(userId),
      NotificationURL: `${this.appUrl}/api/payments/webhook`,
      SuccessURL: `${this.appUrl}/payment-result?orderId=${orderId}&status=success`,
      FailURL: `${this.appUrl}/payment-result?orderId=${orderId}&status=fail`,
    };

    initParams.Token = this.generateToken(initParams);

    try {
      const resp = await fetch(`${TBANK_BASE}/Init`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(initParams),
      });
      const data = await resp.json() as Record<string, any>;

      this.log.log(`Credits Init response: Success=${data.Success} PaymentId=${data.PaymentId} Error=${data.ErrorCode || 'none'}`);

      if (data.Success && data.PaymentURL) {
        await this.pool.query(
          `UPDATE payments SET tbank_payment_id = $1, payment_url = $2, updated_at = now() WHERE id = $3`,
          [String(data.PaymentId), data.PaymentURL, paymentId],
        );
        this.log.log(`Credits purchase created: order=${orderId} package=${packageId} credits=${pkg.credits}`);
        return { success: true, paymentUrl: data.PaymentURL, orderId };
      }

      await this.pool.query(
        `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
        [paymentId],
      );
      return { success: false, error: data.Message || 'T-Bank Init failed' };
    } catch (e: any) {
      this.log.error(`T-Bank credits Init error: ${e.message}`);
      return { success: false, error: 'Payment service unavailable' };
    }
  }

  // ══════════════════════════════════════════════════════════
  // RECURRING CHARGE (auto-renewal)
  // ══════════════════════════════════════════════════════════

  async chargeRecurrent(
    userId: number,
    rebillId: string,
    plan: string,
    billingPeriod: string,
  ): Promise<{ success: boolean; error?: string }> {
    const period = billingPeriod === 'yearly' ? 'yearly' : 'monthly';
    const prices = PLAN_PRICES[period];
    if (!prices || !prices[plan]) {
      return { success: false, error: `Invalid plan for rebill: ${plan}` };
    }

    const amount = prices[plan];
    const orderId = `rebill_${userId}_${plan}_${Date.now()}`;

    // Create payment record for the rebill
    const { rows } = await this.pool.query(
      `INSERT INTO payments (user_id, plan, billing_period, amount, status, order_id, payment_type, rebill_id)
       VALUES ($1, $2, $3, $4, 'pending', $5, 'subscription', $6)
       RETURNING id`,
      [userId, plan, period, amount, orderId, rebillId],
    );
    const paymentId = rows[0].id;

    try {
      // T-Bank Recurrent: Init first to get a PaymentId, then Charge with RebillId
      const initData = await this.tbankPost('Init', {
        Amount: amount,
        OrderId: orderId,
        Description: `Автопродление: ${PLAN_LABELS[plan] || plan}`,
        CustomerKey: String(userId),
        NotificationURL: `${this.appUrl}/api/payments/webhook`,
      });

      if (!initData.Success) {
        await this.pool.query(
          `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
          [paymentId],
        );
        this.log.error(`Rebill Init failed for user ${userId}: ${JSON.stringify(initData)}`);
        return { success: false, error: initData.Message || 'Rebill Init failed' };
      }

      const tbankPaymentId = String(initData.PaymentId);

      await this.pool.query(
        `UPDATE payments SET tbank_payment_id = $1, updated_at = now() WHERE id = $2`,
        [tbankPaymentId, paymentId],
      );

      // Now charge with the RebillId
      const chargeData = await this.tbankPost('Charge', {
        PaymentId: tbankPaymentId,
        RebillId: rebillId,
      });

      if (chargeData.Success) {
        this.log.log(`Rebill charge sent for user ${userId}, awaiting webhook confirmation`);
        return { success: true };
      }

      await this.pool.query(
        `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
        [paymentId],
      );
      this.log.error(`Rebill Charge failed for user ${userId}: ${JSON.stringify(chargeData)}`);
      return { success: false, error: chargeData.Message || 'Charge failed' };
    } catch (e: any) {
      await this.pool.query(
        `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
        [paymentId],
      );
      this.log.error(`Rebill error for user ${userId}: ${e.message}`);
      return { success: false, error: e.message };
    }
  }

  // ══════════════════════════════════════════════════════════
  // WEBHOOK HANDLER (idempotent, atomic)
  // ══════════════════════════════════════════════════════════

  async handleWebhook(body: Record<string, any>, internalSync = false): Promise<{ ok: boolean }> {
    const { OrderId, Status, PaymentId, RebillId } = body;

    if (!OrderId || !Status) {
      this.log.warn('Webhook missing OrderId or Status');
      return { ok: false };
    }

    this.log.log(`Webhook: order=${OrderId} status=${Status} paymentId=${PaymentId} rebillId=${RebillId || 'none'}${internalSync ? ' [internal-sync]' : ''}`);

    if (!internalSync && !this.verifyToken(body)) {
      this.log.error(`Webhook signature failed for order ${OrderId}`);
      return { ok: false };
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query(
        `SELECT id, user_id, plan, billing_period, amount, status, payment_type, credits_amount, credit_package
         FROM payments WHERE order_id = $1 FOR UPDATE`,
        [OrderId],
      );

      if (!rows.length) {
        this.log.warn(`Webhook: payment not found for order ${OrderId}`);
        await client.query('ROLLBACK');
        return { ok: false };
      }

      const payment = rows[0];

      // Idempotency
      if (payment.status === 'confirmed' && Status === 'CONFIRMED') {
        await client.query('ROLLBACK');
        return { ok: true };
      }
      if (payment.status === 'failed' && (Status === 'REJECTED' || Status === 'CANCELED')) {
        await client.query('ROLLBACK');
        return { ok: true };
      }

      if (Status === 'CONFIRMED') {
        await client.query(
          `UPDATE payments SET status = 'confirmed', tbank_payment_id = $1,
           confirmed_at = now(), updated_at = now(), rebill_id = COALESCE($3, rebill_id)
           WHERE id = $2`,
          [String(PaymentId), payment.id, RebillId ? String(RebillId) : null],
        );

        if (payment.payment_type === 'credits') {
          // ── CREDITS PURCHASE ──
          await this.handleCreditsPurchase(client, payment);
        } else {
          // ── SUBSCRIPTION PAYMENT ──
          await this.handleSubscriptionPayment(client, payment, RebillId);
        }

        await client.query('COMMIT');

        // Post-commit: grant plan credits (non-critical)
        if (payment.payment_type !== 'credits') {
          try {
            await this.credits.grantPlanCredits(payment.user_id, payment.plan);
          } catch (e: any) {
            this.log.warn(`Failed to grant plan credits for user ${payment.user_id}: ${e.message}`);
          }
        }

        this.log.log(`Payment CONFIRMED: user=${payment.user_id} type=${payment.payment_type} plan=${payment.plan} amount=${payment.amount}`);

        // Process referral reward (10% passive income to referrer)
        this.referral.processReferralReward(
          payment.user_id,
          payment.amount,
          payment.payment_type === 'credits' ? 'credits' : 'subscription',
          String(payment.id),
        ).catch(e => this.log.warn(`Referral reward failed: ${e.message}`));
      } else if (['REJECTED', 'CANCELED', 'DEADLINE_EXPIRED', 'AUTH_FAIL'].includes(Status)) {
        await client.query(
          `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
          [payment.id],
        );
        await client.query(
          `INSERT INTO subscription_log (user_id, action, plan, payment_id, meta)
           VALUES ($1, 'payment_failed', $2, $3, $4)`,
          [payment.user_id, payment.plan, payment.id, JSON.stringify({ status: Status })],
        );
        await client.query('COMMIT');
        this.log.log(`Payment FAILED: user=${payment.user_id} order=${OrderId} status=${Status}`);
      } else {
        await client.query('ROLLBACK');
        this.log.log(`Webhook: intermediate status ${Status} for order ${OrderId}`);
      }

      return { ok: true };
    } catch (e: any) {
      await client.query('ROLLBACK');
      this.log.error(`Webhook error: ${e.message}`, e.stack);
      return { ok: false };
    } finally {
      client.release();
    }
  }

  private async handleSubscriptionPayment(client: PoolClient, payment: any, rebillId?: string) {
    const daysToAdd = payment.billing_period === 'yearly' ? 365 : 30;

    // If user has active sub, extend from current end; otherwise from now
    const { rows: profileRows } = await client.query(
      `SELECT subscription_end, subscription_status FROM profiles WHERE user_id = $1`,
      [payment.user_id],
    );
    let baseDate = new Date();
    if (profileRows[0]?.subscription_status === 'active' && profileRows[0]?.subscription_end) {
      const currentEnd = new Date(profileRows[0].subscription_end);
      if (currentEnd > baseDate) baseDate = currentEnd; // extend, don't overlap
    }

    const subscriptionEnd = new Date(baseDate);
    subscriptionEnd.setDate(subscriptionEnd.getDate() + daysToAdd);

    await client.query(
      `UPDATE profiles SET
         plan = $1, plan_id = $1,
         billing_period = $2,
         subscription_status = 'active',
         subscription_end = $3,
         cancel_at_period_end = false,
         last_rebill_id = COALESCE($5, last_rebill_id),
         updated_at = now()
       WHERE user_id = $4`,
      [payment.plan, payment.billing_period, subscriptionEnd.toISOString(), payment.user_id, rebillId ? String(rebillId) : null],
    );

    // Reset usage limits for new period
    await client.query(
      `INSERT INTO usage_limits (user_id, period_start, ai_requests, video_gen, analytics_q)
       VALUES ($1, CURRENT_DATE, 0, 0, 0)
       ON CONFLICT (user_id, period_start) DO UPDATE SET ai_requests = 0, video_gen = 0, analytics_q = 0, updated_at = now()`,
      [payment.user_id],
    );

    await client.query(
      `INSERT INTO subscription_log (user_id, action, plan, payment_id, meta)
       VALUES ($1, 'activated', $2, $3, $4)`,
      [
        payment.user_id,
        payment.plan,
        payment.id,
        JSON.stringify({
          amount: payment.amount,
          billing_period: payment.billing_period,
          subscription_end: subscriptionEnd.toISOString(),
          rebill_id: rebillId || null,
        }),
      ],
    );

    // In-app notification: subscription activated
    const planLabel = { start: 'Старт', breakthrough: 'Прорыв', empire: 'Империя' }[payment.plan] || payment.plan;
    this.notifications.send({
      user_id: payment.user_id,
      title: 'Подписка активирована',
      message: `Ваш план «${planLabel}» активирован до ${subscriptionEnd.toLocaleDateString('ru-RU')}`,
      type: 'success',
      meta: { plan: payment.plan, subscription_end: subscriptionEnd.toISOString() },
    }).catch(e => this.log.error(`Notification error: ${e.message}`));
  }

  private async handleCreditsPurchase(client: PoolClient, payment: any) {
    const creditsAmount = payment.credits_amount || 0;
    if (creditsAmount <= 0) return;

    // Grant credits using existing CreditsService pattern (inline for atomicity)
    await client.query(
      `INSERT INTO user_balance (user_id, credits) VALUES ($1, 0) ON CONFLICT DO NOTHING`,
      [payment.user_id],
    );
    const { rows: balRows } = await client.query(
      `UPDATE user_balance SET credits = credits + $2, updated_at = now()
       WHERE user_id = $1 RETURNING credits`,
      [payment.user_id, creditsAmount],
    );
    const newBalance = balRows[0]?.credits ?? creditsAmount;

    await client.query(
      `INSERT INTO credit_transactions (user_id, type, amount, balance_after, reason, meta)
       VALUES ($1, 'topup', $2, $3, $4, $5)`,
      [
        payment.user_id,
        creditsAmount,
        newBalance,
        `Покупка: ${payment.credit_package} (+${creditsAmount} кредитов)`,
        JSON.stringify({ payment_id: payment.id, package: payment.credit_package }),
      ],
    );

    await client.query(
      `INSERT INTO subscription_log (user_id, action, plan, payment_id, meta)
       VALUES ($1, 'credits_purchased', 'credits', $2, $3)`,
      [
        payment.user_id,
        payment.id,
        JSON.stringify({ credits: creditsAmount, package: payment.credit_package, balance: newBalance }),
      ],
    );

    this.log.log(`Credits purchased: user=${payment.user_id} +${creditsAmount} balance=${newBalance}`);

    // In-app notification: credits purchased
    this.notifications.send({
      user_id: payment.user_id,
      title: 'Кредиты начислены',
      message: `На ваш счёт зачислено ${creditsAmount} кредитов. Баланс: ${newBalance}`,
      type: 'success',
      meta: { credits: creditsAmount, balance: newBalance },
    }).catch(e => this.log.error(`Notification error: ${e.message}`));
  }

  // ══════════════════════════════════════════════════════════
  // CANCEL SUBSCRIPTION
  // ══════════════════════════════════════════════════════════

  async cancelSubscription(userId: number): Promise<{ success: boolean; error?: string; expiresAt?: string }> {
    const { rows } = await this.pool.query(
      `SELECT plan, subscription_status, subscription_end, cancel_at_period_end
       FROM profiles WHERE user_id = $1`,
      [userId],
    );

    const profile = rows[0];
    if (!profile || profile.subscription_status !== 'active') {
      return { success: false, error: 'No active subscription to cancel' };
    }

    if (profile.cancel_at_period_end) {
      return { success: true, expiresAt: profile.subscription_end }; // Already scheduled
    }

    await this.pool.query(
      `UPDATE profiles SET cancel_at_period_end = true, updated_at = now()
       WHERE user_id = $1`,
      [userId],
    );

    await this.pool.query(
      `INSERT INTO subscription_log (user_id, action, plan, meta)
       VALUES ($1, 'cancel_scheduled', $2, $3)`,
      [userId, profile.plan, JSON.stringify({ expires_at: profile.subscription_end })],
    );

    this.log.log(`Subscription cancel scheduled: user=${userId} expires=${profile.subscription_end}`);

    this.notifications.send({
      user_id: userId,
      title: 'Подписка будет отменена',
      message: `Ваша подписка будет действовать до ${new Date(profile.subscription_end).toLocaleDateString('ru-RU')}`,
      type: 'warning',
      meta: { expires_at: profile.subscription_end },
    }).catch(() => {});

    return { success: true, expiresAt: profile.subscription_end };
  }

  async reactivateSubscription(userId: number): Promise<{ success: boolean }> {
    await this.pool.query(
      `UPDATE profiles SET cancel_at_period_end = false, updated_at = now()
       WHERE user_id = $1 AND subscription_status = 'active'`,
      [userId],
    );

    await this.pool.query(
      `INSERT INTO subscription_log (user_id, action, plan) VALUES ($1, 'cancel_reverted', null)`,
      [userId],
    );

    this.notifications.send({
      user_id: userId,
      title: 'Подписка восстановлена',
      message: 'Отмена подписки отозвана. Ваша подписка продолжит действовать',
      type: 'success',
    }).catch(() => {});

    return { success: true };
  }

  // ══════════════════════════════════════════════════════════
  // PAYMENT STATE SYNC (T-Bank GetState fallback)
  // ══════════════════════════════════════════════════════════

  async checkPaymentStatus(orderId: string): Promise<any> {
    const { rows } = await this.pool.query(
      `SELECT id, user_id, plan, amount, status, tbank_payment_id, payment_type, order_id, created_at, confirmed_at
       FROM payments WHERE order_id = $1`,
      [orderId],
    );
    if (!rows.length) return null;
    return rows[0];
  }

  async syncPendingPayment(orderId: string): Promise<{ synced: boolean; status?: string }> {
    const payment = await this.checkPaymentStatus(orderId);
    if (!payment || payment.status !== 'pending') {
      return { synced: false, status: payment?.status };
    }

    if (!payment.tbank_payment_id) {
      return { synced: false, status: 'pending' };
    }

    try {
      const data = await this.tbankPost('GetState', {
        PaymentId: payment.tbank_payment_id,
      });

      if (!data.Success) {
        return { synced: false, status: 'pending' };
      }

      const tbankStatus = data.Status;
      this.log.log(`GetState for order ${orderId}: T-Bank status=${tbankStatus}`);

      // If T-Bank says CONFIRMED but we still have pending, process it
      if (tbankStatus === 'CONFIRMED') {
        await this.handleWebhook({
          OrderId: payment.order_id,
          Status: 'CONFIRMED',
          PaymentId: payment.tbank_payment_id,
          RebillId: data.RebillId,
        }, true);
        return { synced: true, status: 'confirmed' };
      }

      if (['REJECTED', 'CANCELED', 'DEADLINE_EXPIRED'].includes(tbankStatus)) {
        await this.pool.query(
          `UPDATE payments SET status = 'failed', updated_at = now() WHERE id = $1`,
          [payment.id],
        );
        return { synced: true, status: 'failed' };
      }

      return { synced: false, status: tbankStatus };
    } catch (e: any) {
      this.log.error(`GetState error for order ${orderId}: ${e.message}`);
      return { synced: false, status: 'error' };
    }
  }

  /** Sync all stale pending payments (older than 15 minutes) */
  async syncAllPending(): Promise<number> {
    const { rows } = await this.pool.query(
      `SELECT order_id FROM payments
       WHERE status = 'pending' AND tbank_payment_id IS NOT NULL
         AND created_at < now() - interval '15 minutes'
         AND created_at > now() - interval '24 hours'
       ORDER BY created_at ASC LIMIT 20`,
    );

    let synced = 0;
    for (const row of rows) {
      const result = await this.syncPendingPayment(row.order_id);
      if (result.synced) synced++;
    }

    if (synced > 0) this.log.log(`Synced ${synced}/${rows.length} pending payments`);
    return synced;
  }

  // ══════════════════════════════════════════════════════════
  // USAGE LIMITS
  // ══════════════════════════════════════════════════════════

  async checkUsageLimit(userId: number, limitType: 'ai_requests' | 'video_gen' | 'analytics_q'): Promise<{
    allowed: boolean;
    used: number;
    limit: number;
    remaining: number;
  }> {
    // Get user's plan
    const { rows: profileRows } = await this.pool.query(
      `SELECT plan, subscription_status, subscription_end FROM profiles WHERE user_id = $1`,
      [userId],
    );
    const plan = profileRows[0]?.plan || 'free';
    const isActive = profileRows[0]?.subscription_status === 'active'
      && profileRows[0]?.subscription_end
      && new Date(profileRows[0].subscription_end) > new Date();

    // If no active sub, treat as free plan
    const effectivePlan = isActive ? plan : 'free';

    // Get plan limits
    const { rows: limitRows } = await this.pool.query(
      `SELECT ${limitType} AS lim FROM plan_limits WHERE plan = $1`,
      [effectivePlan],
    );
    const planLimit = limitRows[0]?.lim ?? 3; // free default: 3

    // 0 = unlimited
    if (planLimit === 0) {
      return { allowed: true, used: 0, limit: 0, remaining: -1 };
    }

    // Get current period start (first day of current month)
    const now = new Date();
    const periodStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;

    // Get or create usage record
    const { rows: usageRows } = await this.pool.query(
      `INSERT INTO usage_limits (user_id, period_start) VALUES ($1, $2)
       ON CONFLICT (user_id, period_start) DO NOTHING
       RETURNING *`,
      [userId, periodStart],
    );

    let used: number;
    if (usageRows.length) {
      used = usageRows[0][limitType] || 0;
    } else {
      const { rows: existing } = await this.pool.query(
        `SELECT ${limitType} AS used FROM usage_limits WHERE user_id = $1 AND period_start = $2`,
        [userId, periodStart],
      );
      used = existing[0]?.used ?? 0;
    }

    const remaining = planLimit - used;
    return {
      allowed: remaining > 0,
      used,
      limit: planLimit,
      remaining: Math.max(0, remaining),
    };
  }

  async incrementUsage(userId: number, limitType: 'ai_requests' | 'video_gen' | 'analytics_q'): Promise<void> {
    const now = new Date();
    const periodStart = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;

    await this.pool.query(
      `INSERT INTO usage_limits (user_id, period_start, ${limitType})
       VALUES ($1, $2, 1)
       ON CONFLICT (user_id, period_start)
       DO UPDATE SET ${limitType} = usage_limits.${limitType} + 1, updated_at = now()`,
      [userId, periodStart],
    );
  }

  // ══════════════════════════════════════════════════════════
  // SUBSCRIPTION QUERIES
  // ══════════════════════════════════════════════════════════

  async getSubscription(userId: number) {
    const { rows } = await this.pool.query(
      `SELECT plan, plan_id, billing_period, subscription_status, subscription_end,
              cancel_at_period_end, last_rebill_id
       FROM profiles WHERE user_id = $1`,
      [userId],
    );

    const profile = rows[0];
    if (!profile) {
      return { plan: 'free', status: 'none', active: false, cancel_at_period_end: false };
    }

    const now = new Date();
    const end = profile.subscription_end ? new Date(profile.subscription_end) : null;
    const isActive = profile.subscription_status === 'active' && end !== null && end > now;

    // Auto-expire if past due
    if (profile.subscription_status === 'active' && end !== null && end <= now) {
      await this.pool.query(
        `UPDATE profiles SET subscription_status = 'expired', updated_at = now()
         WHERE user_id = $1`,
        [userId],
      );
      await this.pool.query(
        `INSERT INTO subscription_log (user_id, action, plan, meta)
         VALUES ($1, 'expired', $2, $3)`,
        [userId, profile.plan, JSON.stringify({ expired_at: now.toISOString() })],
      );
      return {
        plan: profile.plan || 'free',
        status: 'expired',
        active: false,
        billing_period: profile.billing_period,
        subscription_end: profile.subscription_end,
        cancel_at_period_end: profile.cancel_at_period_end,
        has_recurring: !!profile.last_rebill_id,
      };
    }

    return {
      plan: profile.plan || 'free',
      status: profile.subscription_status || 'none',
      active: isActive,
      billing_period: profile.billing_period,
      subscription_end: profile.subscription_end,
      cancel_at_period_end: profile.cancel_at_period_end || false,
      has_recurring: !!profile.last_rebill_id,
    };
  }

  async getPaymentHistory(userId: number, limit = 20) {
    const { rows } = await this.pool.query(
      `SELECT id, plan, billing_period, amount, status, order_id, payment_type,
              credits_amount, credit_package, created_at, confirmed_at
       FROM payments WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
      [userId, limit],
    );
    return rows;
  }

  // ══════════════════════════════════════════════════════════
  // ADMIN
  // ══════════════════════════════════════════════════════════

  async allPayments(opts: { status?: string; type?: string; limit?: number; offset?: number }) {
    let q = `SELECT p.*, u.email FROM payments p LEFT JOIN users u ON u.id = p.user_id WHERE 1=1`;
    const params: any[] = [];
    if (opts.status) { params.push(opts.status); q += ` AND p.status = $${params.length}`; }
    if (opts.type) { params.push(opts.type); q += ` AND p.payment_type = $${params.length}`; }
    q += ' ORDER BY p.created_at DESC';
    params.push(opts.limit || 50); q += ` LIMIT $${params.length}`;
    params.push(opts.offset || 0); q += ` OFFSET $${params.length}`;
    const { rows } = await this.pool.query(q, params);
    return rows;
  }

  async paymentStats() {
    const [total, confirmed, monthly, byPlan, activeSubs, mrr, creditStats] = await Promise.all([
      this.pool.query('SELECT count(*)::int AS c FROM payments'),
      this.pool.query("SELECT count(*)::int AS c, COALESCE(sum(amount),0)::bigint AS total FROM payments WHERE status = 'confirmed'"),
      this.pool.query(`
        SELECT date_trunc('month', confirmed_at)::date AS month,
               count(*)::int AS c,
               sum(amount)::bigint AS total
        FROM payments WHERE status = 'confirmed' AND confirmed_at >= now() - interval '12 months'
        GROUP BY month ORDER BY month DESC
      `),
      this.pool.query(`
        SELECT plan, count(*)::int AS c, sum(amount)::bigint AS total
        FROM payments WHERE status = 'confirmed' AND payment_type = 'subscription'
        GROUP BY plan ORDER BY total DESC
      `),
      this.pool.query(`
        SELECT count(*)::int AS c
        FROM profiles
        WHERE subscription_status = 'active' AND subscription_end > now()
      `),
      // MRR: sum of monthly-equivalent prices for active subscriptions
      this.pool.query(`
        SELECT COALESCE(sum(
          CASE
            WHEN billing_period = 'yearly' THEN
              CASE plan
                WHEN 'start' THEN 99000
                WHEN 'breakthrough' THEN 199000
                WHEN 'empire' THEN 399000
                ELSE 0
              END
            ELSE
              CASE plan
                WHEN 'start' THEN 99000
                WHEN 'breakthrough' THEN 199000
                WHEN 'empire' THEN 399000
                ELSE 0
              END
          END
        ), 0)::bigint AS mrr_kopecks
        FROM profiles
        WHERE subscription_status = 'active' AND subscription_end > now()
      `),
      this.pool.query(`
        SELECT count(*)::int AS c, COALESCE(sum(amount),0)::bigint AS total
        FROM payments WHERE status = 'confirmed' AND payment_type = 'credits'
      `),
    ]);

    return {
      total_payments: total.rows[0].c,
      confirmed_payments: confirmed.rows[0].c,
      total_revenue_kopecks: Number(confirmed.rows[0].total),
      total_revenue_rub: Math.round(Number(confirmed.rows[0].total) / 100),
      active_subscriptions: activeSubs.rows[0].c,
      mrr_rub: Math.round(Number(mrr.rows[0].mrr_kopecks) / 100),
      credits_sold: creditStats.rows[0].c,
      credits_revenue_rub: Math.round(Number(creditStats.rows[0].total) / 100),
      monthly_revenue: monthly.rows.map((r: any) => ({
        month: r.month,
        count: r.c,
        revenue_rub: Math.round(Number(r.total) / 100),
      })),
      by_plan: byPlan.rows.map((r: any) => ({
        plan: r.plan,
        count: r.c,
        revenue_rub: Math.round(Number(r.total) / 100),
      })),
    };
  }

  /** Get credit packages for display */
  getCreditPackages() {
    return Object.entries(CREDIT_PACKAGES).map(([id, pkg]) => ({
      id,
      credits: pkg.credits,
      price_kopecks: pkg.price,
      price_rub: Math.round(pkg.price / 100),
      label: pkg.label,
    }));
  }
}
