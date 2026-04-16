import { Injectable, Inject, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { ReferralService } from '../referral/referral.service';

@Injectable()
export class BeatsService {
  private readonly log = new Logger('Beats');

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly referral: ReferralService,
  ) {}

  async create(sellerId: number, dto: any) {
    // Validate prices are non-negative
    const priceLease = Math.max(0, Math.round(Number(dto.price_lease) || 0));
    const priceExclusive = Math.max(0, Math.round(Number(dto.price_exclusive) || 0));
    const priceUnlimited = Math.max(0, Math.round(Number(dto.price_unlimited) || 0));

    const { rows } = await this.pool.query(
      `INSERT INTO beats (seller_id, title, description, genre, sub_genre, bpm, key, mood, tags,
        audio_url, audio_path, preview_url, cover_url, duration, price_lease, price_exclusive, price_unlimited, is_free, status)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19) RETURNING *`,
      [
        sellerId, dto.title, dto.description || null, dto.genre || null, dto.sub_genre || null,
        dto.bpm || null, dto.key || null, dto.mood || null, dto.tags || [],
        dto.audio_url, dto.audio_path || null, dto.preview_url || null, dto.cover_url || null,
        dto.duration || null, priceLease, priceExclusive, priceUnlimited,
        dto.is_free ?? false, 'pending',
      ],
    );
    return rows[0];
  }

  async findAll(opts: { genre?: string; mood?: string; bpmMin?: number; bpmMax?: number; search?: string; limit?: number; offset?: number; sellerId?: number }) {
    const conditions = ["b.status = 'active'"];
    const params: any[] = [];
    let idx = 1;

    if (opts.genre) { conditions.push(`b.genre = $${idx}`); params.push(opts.genre); idx++; }
    if (opts.mood) { conditions.push(`b.mood = $${idx}`); params.push(opts.mood); idx++; }
    if (opts.bpmMin) { conditions.push(`b.bpm >= $${idx}`); params.push(opts.bpmMin); idx++; }
    if (opts.bpmMax) { conditions.push(`b.bpm <= $${idx}`); params.push(opts.bpmMax); idx++; }
    if (opts.sellerId) { conditions.push(`b.seller_id = $${idx}`); params.push(opts.sellerId); idx++; }
    if (opts.search) { conditions.push(`(b.title ILIKE $${idx} OR b.description ILIKE $${idx})`); params.push(`%${opts.search}%`); idx++; }

    const limit = Math.min(opts.limit || 20, 50);
    const offset = opts.offset || 0;

    const { rows } = await this.pool.query(
      `SELECT b.*, u.name as seller_name
       FROM beats b
       JOIN users u ON u.id = b.seller_id
       WHERE ${conditions.join(' AND ')}
       ORDER BY b.created_at DESC
       LIMIT $${idx} OFFSET $${idx + 1}`,
      [...params, limit, offset],
    );
    return rows;
  }

  async findById(id: number) {
    const { rows } = await this.pool.query(
      `SELECT b.*, u.name as seller_name FROM beats b JOIN users u ON u.id = b.seller_id WHERE b.id = $1`, [id],
    );
    return rows[0] || null;
  }

  async findBySeller(sellerId: number) {
    const { rows } = await this.pool.query(
      `SELECT * FROM beats WHERE seller_id = $1 ORDER BY created_at DESC`, [sellerId],
    );
    return rows;
  }

  async update(id: number, fields: Record<string, any>) {
    // Don't allow reactivating a sold beat
    if (fields.status === 'active') {
      const beat = await this.findById(id);
      if (beat?.is_sold_exclusive) {
        throw new Error('Cannot reactivate exclusively sold beat');
      }
    }
    // Validate prices are non-negative
    for (const priceKey of ['price_lease', 'price_exclusive', 'price_unlimited']) {
      if (priceKey in fields) {
        fields[priceKey] = Math.max(0, Math.round(Number(fields[priceKey]) || 0));
      }
    }
    const allowed = ['title', 'description', 'genre', 'sub_genre', 'bpm', 'key', 'mood', 'tags',
      'audio_url', 'audio_path', 'preview_url', 'cover_url', 'duration',
      'price_lease', 'price_exclusive', 'price_unlimited', 'is_free'];
    const sets: string[] = [];
    const vals: any[] = [];
    let idx = 1;
    for (const k of allowed) {
      if (k in fields) { sets.push(`${k} = $${idx}`); vals.push(fields[k]); idx++; }
    }
    if (!sets.length) return this.findById(id);
    sets.push('updated_at = NOW()');
    vals.push(id);
    const { rows } = await this.pool.query(`UPDATE beats SET ${sets.join(', ')} WHERE id = $${idx} RETURNING *`, vals);
    return rows[0];
  }

  async delete(id: number) {
    await this.pool.query(`DELETE FROM beats WHERE id = $1`, [id]);
  }

  async adminFindAll() {
    const { rows } = await this.pool.query(
      `SELECT b.*, u.email as seller_email, p.display_name as seller_name
       FROM beats b
       LEFT JOIN users u ON u.id = b.seller_id
       LEFT JOIN profiles p ON p.user_id = b.seller_id
       ORDER BY b.created_at DESC`,
    );
    return rows;
  }

  async adminSetStatus(id: number, status: string, reason?: string) {
    await this.pool.query(
      `UPDATE beats SET status = $1, updated_at = NOW() WHERE id = $2`,
      [status, id],
    );
    if (reason) {
      // Notify seller about rejection
      const beat = await this.findById(id);
      if (beat) {
        await this.pool.query(
          `INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, 'warning')`,
          [beat.seller_id, 'Бит отклонён', `Ваш бит "${beat.title}" отклонён. Причина: ${reason}`],
        );
      }
    }
  }

  async incrementPlays(id: number) {
    await this.pool.query(`UPDATE beats SET plays = plays + 1 WHERE id = $1`, [id]);
  }

  async toggleLike(beatId: number, userId: number): Promise<boolean> {
    const { rows } = await this.pool.query(`SELECT 1 FROM beat_likes WHERE beat_id = $1 AND user_id = $2`, [beatId, userId]);
    if (rows.length > 0) {
      await this.pool.query(`DELETE FROM beat_likes WHERE beat_id = $1 AND user_id = $2`, [beatId, userId]);
      await this.pool.query(`UPDATE beats SET likes = GREATEST(likes - 1, 0) WHERE id = $1`, [beatId]);
      return false;
    }
    await this.pool.query(`INSERT INTO beat_likes (beat_id, user_id) VALUES ($1, $2)`, [beatId, userId]);
    await this.pool.query(`UPDATE beats SET likes = likes + 1 WHERE id = $1`, [beatId]);
    return true;
  }

  async purchase(beatId: number, buyerId: number, licenseType: string) {
    const beat = await this.findById(beatId);
    if (!beat) throw new Error('Beat not found');
    if (beat.seller_id === buyerId) throw new Error('Cannot buy your own beat');
    if (beat.status !== 'active') throw new Error('Beat is not available for purchase');
    if (beat.is_sold_exclusive) throw new Error('Beat already sold exclusively');

    const price = licenseType === 'exclusive' ? beat.price_exclusive
      : licenseType === 'unlimited' ? beat.price_unlimited
      : beat.price_lease;

    if (price <= 0 && !beat.is_free) throw new Error('Invalid beat price');

    const platformFee = Math.round(price * 0.15); // 15% platform fee
    const sellerRevenue = price - platformFee;

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Deduct credits from buyer (beats are purchased with credits)
      if (price > 0) {
        const { rows: balRows } = await client.query(
          `SELECT credits FROM user_balance WHERE user_id = $1 FOR UPDATE`,
          [buyerId],
        );
        const buyerCredits = balRows[0]?.credits ?? 0;
        if (buyerCredits < price) {
          await client.query('ROLLBACK');
          throw new Error(`Недостаточно кредитов. Нужно: ${price}, у вас: ${buyerCredits}`);
        }
        await client.query(
          `UPDATE user_balance SET credits = credits - $2, updated_at = now() WHERE user_id = $1`,
          [buyerId, price],
        );
      }

      // Create purchase record
      const { rows } = await client.query(
        `INSERT INTO beat_purchases (beat_id, buyer_id, seller_id, license_type, price, platform_fee, seller_revenue)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [beatId, buyerId, beat.seller_id, licenseType, price, platformFee, sellerRevenue],
      );

      // Add revenue to seller balance
      await client.query(
        `INSERT INTO user_balance (user_id, credits, revenue, total_earned)
         VALUES ($1, 0, $2, $2)
         ON CONFLICT (user_id) DO UPDATE SET revenue = user_balance.revenue + $2, total_earned = user_balance.total_earned + $2`,
        [beat.seller_id, sellerRevenue],
      );

      // Update beat stats
      await client.query(`UPDATE beats SET purchases = purchases + 1 WHERE id = $1`, [beatId]);

      // If exclusive — mark as sold
      if (licenseType === 'exclusive') {
        await client.query(`UPDATE beats SET is_sold_exclusive = true, status = 'sold' WHERE id = $1`, [beatId]);
      }

      // Notify seller
      await client.query(
        `INSERT INTO notifications (user_id, title, message, type, meta) VALUES ($1, $2, $3, 'success', $4)`,
        [beat.seller_id, 'Продажа бита!', `Ваш бит "${beat.title}" куплен (${licenseType}). Заработано: ${sellerRevenue}₽`, JSON.stringify({ beat_id: beatId, license: licenseType, revenue: sellerRevenue })],
      );

      await client.query('COMMIT');

      this.log.log(`Beat ${beatId} purchased by user ${buyerId} (${licenseType}) — seller ${beat.seller_id} earned ${sellerRevenue}₽`);

      // Referral reward (10% passive income to referrer, beat price in rubles → convert to kopecks)
      this.referral.processReferralReward(
        buyerId,
        price * 100,
        'beat_purchase',
        String(rows[0].id),
      ).catch(e => this.log.warn(`Referral reward failed: ${e.message}`));

      return rows[0];
    } catch (e) {
      await client.query('ROLLBACK');
      throw e;
    } finally {
      client.release();
    }
  }
}
