import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool, PoolClient } from 'pg';
import { randomBytes } from 'crypto';
import { PG_POOL } from '../database/database.module';
import { NotificationsService } from '../notifications/notifications.service';

const REFERRAL_PERCENT = 0.10; // 10% passive income

@Injectable()
export class ReferralService {
  private readonly log = new Logger(ReferralService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly notifications: NotificationsService,
  ) {}

  // ── GET OR CREATE REFERRAL CODE ──────────────────────────

  async getOrCreateCode(userId: number): Promise<string> {
    const { rows } = await this.pool.query(
      `SELECT code FROM referral_codes WHERE user_id = $1`,
      [userId],
    );
    if (rows.length) return rows[0].code;

    const code = this.generateCode();
    await this.pool.query(
      `INSERT INTO referral_codes (user_id, code) VALUES ($1, $2) ON CONFLICT (user_id) DO NOTHING`,
      [userId, code],
    );
    return code;
  }

  private generateCode(): string {
    return randomBytes(4).toString('hex').toUpperCase(); // 8-char hex
  }

  // ── APPLY REFERRAL ON REGISTRATION ───────────────────────

  async applyReferralCode(newUserId: number, code: string): Promise<boolean> {
    const { rows } = await this.pool.query(
      `SELECT user_id FROM referral_codes WHERE code = $1`,
      [code.toUpperCase()],
    );
    if (!rows.length) return false;

    const referrerId = rows[0].user_id;
    if (referrerId === newUserId) return false; // can't refer yourself

    // Check if user already has a referrer
    const { rows: userRows } = await this.pool.query(
      `SELECT referred_by FROM users WHERE id = $1`,
      [newUserId],
    );
    if (userRows[0]?.referred_by) return false; // already referred

    await this.pool.query(
      `UPDATE users SET referred_by = $1 WHERE id = $2`,
      [referrerId, newUserId],
    );

    this.log.log(`Referral applied: user ${newUserId} referred by ${referrerId} (code: ${code})`);

    // Notify referrer
    this.notifications.send({
      user_id: referrerId,
      title: 'Новый реферал!',
      message: 'По вашей ссылке зарегистрировался новый пользователь. Вы будете получать 10% от каждого его платежа.',
      type: 'success',
      meta: { referred_user_id: newUserId },
    }).catch(e => this.log.error(`Notification error: ${e.message}`));

    return true;
  }

  // ── PROCESS REFERRAL REWARD ON PAYMENT ───────────────────
  // Call this AFTER a successful payment commit

  async processReferralReward(
    userId: number,
    paymentAmount: number, // in kopecks
    paymentType: string,   // 'subscription', 'credits', etc.
    paymentRef?: string,
  ): Promise<void> {
    try {
      // Find referrer
      const { rows: userRows } = await this.pool.query(
        `SELECT referred_by FROM users WHERE id = $1`,
        [userId],
      );
      const referrerId = userRows[0]?.referred_by;
      if (!referrerId) return; // no referrer

      // Amount in rubles (payment is in kopecks)
      const amountRubles = Math.floor(paymentAmount / 100);
      const rewardRubles = Math.floor(amountRubles * REFERRAL_PERCENT);
      if (rewardRubles <= 0) return;

      const client = await this.pool.connect();
      try {
        await client.query('BEGIN');

        // Log reward
        await client.query(
          `INSERT INTO referral_rewards (referrer_id, referred_id, payment_amount, reward_amount, payment_type, payment_ref)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [referrerId, userId, amountRubles, rewardRubles, paymentType, paymentRef || null],
        );

        // Credit reward to referrer balance
        await client.query(
          `INSERT INTO user_balance (user_id, referral_earnings) VALUES ($1, $2)
           ON CONFLICT (user_id) DO UPDATE SET
             referral_earnings = COALESCE(user_balance.referral_earnings, 0) + $2,
             updated_at = now()`,
          [referrerId, rewardRubles],
        );

        await client.query('COMMIT');

        this.log.log(`Referral reward: ${rewardRubles}₽ to user ${referrerId} from user ${userId} payment (${paymentType})`);

        // Notify referrer
        this.notifications.send({
          user_id: referrerId,
          title: 'Реферальный доход!',
          message: `Вы получили ${rewardRubles}₽ — 10% от платежа вашего реферала.`,
          type: 'success',
          meta: { reward: rewardRubles, payment_type: paymentType, from_user_id: userId },
        }).catch(e => this.log.error(`Notification error: ${e.message}`));
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    } catch (e: any) {
      this.log.error(`Referral reward processing failed: ${e.message}`);
      // Don't throw — referral reward failure shouldn't break the payment flow
    }
  }

  // ── GET REFERRAL STATS ──────────────────────────────────

  async getStats(userId: number) {
    const code = await this.getOrCreateCode(userId);

    const { rows: referrals } = await this.pool.query(
      `SELECT u.id, p.display_name, u.created_at
       FROM users u
       LEFT JOIN profiles p ON p.user_id = u.id
       WHERE u.referred_by = $1
       ORDER BY u.created_at DESC`,
      [userId],
    );

    const { rows: earningsRows } = await this.pool.query(
      `SELECT COALESCE(SUM(reward_amount), 0) as total_earned,
              COUNT(*) as total_rewards
       FROM referral_rewards WHERE referrer_id = $1`,
      [userId],
    );

    const { rows: recentRewards } = await this.pool.query(
      `SELECT rr.reward_amount, rr.payment_type, rr.created_at, p.display_name
       FROM referral_rewards rr
       LEFT JOIN profiles p ON p.user_id = rr.referred_id
       WHERE rr.referrer_id = $1
       ORDER BY rr.created_at DESC LIMIT 20`,
      [userId],
    );

    const { rows: balanceRows } = await this.pool.query(
      `SELECT COALESCE(referral_earnings, 0) as referral_earnings FROM user_balance WHERE user_id = $1`,
      [userId],
    );

    return {
      code,
      referral_link: `https://aurixmusic.ru/register?ref=${code}`,
      referrals_count: referrals.length,
      referrals: referrals.map(r => ({
        id: r.id,
        name: r.display_name || 'Аноним',
        joined_at: r.created_at,
      })),
      total_earned: earningsRows[0]?.total_earned || 0,
      total_rewards: earningsRows[0]?.total_rewards || 0,
      current_balance: balanceRows[0]?.referral_earnings || 0,
      recent_rewards: recentRewards.map(r => ({
        amount: r.reward_amount,
        type: r.payment_type,
        date: r.created_at,
        from_name: r.display_name || 'Аноним',
      })),
    };
  }
}
