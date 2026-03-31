import { Injectable, Inject, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { TBankService } from './tbank.service';

@Injectable()
export class SubscriptionCronService {
  private readonly log = new Logger('SubscriptionCron');

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly tbank: TBankService,
  ) {}

  /**
   * Daily at 03:00 Moscow time (00:00 UTC):
   * 1. Attempt auto-renewal for expired subscriptions with a saved RebillId
   * 2. Expire subscriptions that have no RebillId or were cancelled
   * 3. Sync stale pending payments via T-Bank GetState
   */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async processSubscriptions() {
    this.log.log('=== Daily subscription cron started ===');

    const renewed = await this.autoRenew();
    const expired = await this.expireSubscriptions();
    const synced = await this.tbank.syncAllPending();

    this.log.log(`=== Cron complete: renewed=${renewed}, expired=${expired}, synced=${synced} ===`);
  }

  /**
   * Auto-renew subscriptions:
   * - subscription_end has passed (or is today)
   * - cancel_at_period_end = false
   * - last_rebill_id IS NOT NULL
   */
  private async autoRenew(): Promise<number> {
    const { rows } = await this.pool.query(`
      SELECT p.user_id::int AS user_id, p.plan, p.billing_period, p.last_rebill_id
      FROM profiles p
      JOIN users u ON u.id = p.user_id::int
      WHERE p.subscription_status = 'active'
        AND p.subscription_end <= now()
        AND p.cancel_at_period_end = false
        AND p.last_rebill_id IS NOT NULL
      LIMIT 100
    `);

    let renewed = 0;
    for (const row of rows) {
      try {
        const result = await this.tbank.chargeRecurrent(
          row.user_id,
          row.last_rebill_id,
          row.plan,
          row.billing_period || 'monthly',
        );
        if (result.success) {
          renewed++;
          this.log.log(`Auto-renewed user ${row.user_id} (${row.plan})`);
        } else {
          this.log.warn(`Auto-renew failed for user ${row.user_id}: ${result.error}`);
          // Mark subscription as expired after failed charge
          await this.pool.query(
            `UPDATE profiles SET subscription_status = 'expired', updated_at = now()
             WHERE user_id = $1::text`,
            [String(row.user_id)],
          );
          await this.pool.query(
            `INSERT INTO subscription_log (user_id, action, plan, meta)
             VALUES ($1, 'renewal_failed', $2, $3)`,
            [row.user_id, row.plan, JSON.stringify({ error: result.error })],
          );
        }
      } catch (e: any) {
        this.log.error(`Auto-renew error for user ${row.user_id}: ${e.message}`);
      }
    }

    return renewed;
  }

  /**
   * Expire subscriptions:
   * - subscription_end has passed
   * - Either cancel_at_period_end = true OR no rebill_id saved
   */
  private async expireSubscriptions(): Promise<number> {
    const { rows } = await this.pool.query(`
      UPDATE profiles SET
        subscription_status = 'expired',
        updated_at = now()
      WHERE subscription_status = 'active'
        AND subscription_end <= now()
        AND (cancel_at_period_end = true OR last_rebill_id IS NULL)
      RETURNING user_id, plan
    `);

    for (const row of rows) {
      await this.pool.query(
        `INSERT INTO subscription_log (user_id, action, plan, meta)
         VALUES ($1::int, $2, $3, $4)`,
        [row.user_id, row.cancel_at_period_end ? 'cancelled_expired' : 'expired', row.plan, '{}'],
      ).catch((e: any) => this.log.warn(`Log error: ${e.message}`));
    }

    if (rows.length) {
      this.log.log(`Expired ${rows.length} subscription(s)`);
    }

    return rows.length;
  }
}
