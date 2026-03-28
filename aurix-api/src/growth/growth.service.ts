import { Injectable, Inject, Logger, OnModuleInit } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';

interface LevelConfig {
  level: number;
  name: string;
  min_xp: number;
  color_key: string;
}

@Injectable()
export class GrowthService implements OnModuleInit {
  private readonly log = new Logger('Growth');
  private levels: LevelConfig[] = [];

  constructor(@Inject(PG_POOL) private readonly pool: Pool) {}

  async onModuleInit() {
    await this.loadLevels();
  }

  async loadLevels() {
    try {
      const { rows } = await this.pool.query('SELECT * FROM level_config ORDER BY level');
      this.levels = rows;
      this.log.log(`Loaded ${this.levels.length} level configs`);
    } catch (e) {
      this.log.warn(`Failed to load levels: ${e}`);
      // Fallback
      this.levels = [
        { level: 1, name: 'Rookie', min_xp: 0, color_key: 'gray' },
        { level: 2, name: 'Beginner', min_xp: 100, color_key: 'green' },
        { level: 3, name: 'Rising', min_xp: 300, color_key: 'green' },
        { level: 5, name: 'Pro', min_xp: 1000, color_key: 'blue' },
        { level: 10, name: 'Elite', min_xp: 5000, color_key: 'gold' },
      ];
    }
  }

  private computeLevel(xp: number): { level: number; name: string } {
    let result = this.levels[0] || { level: 1, name: 'Rookie' };
    for (const l of this.levels) {
      if (xp >= l.min_xp) result = l;
    }
    return { level: result.level, name: result.name };
  }

  // ── XP ───────────────────────────────────────────────────

  /** Add XP to a user and update level. Returns new state. */
  async addXp(userId: number, amount: number, reason: string, source = 'action'): Promise<{ xp: number; level: number; levelName: string; leveledUp: boolean }> {
    // Ensure row
    await this.pool.query(
      'INSERT INTO user_xp (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId],
    );

    // Add XP
    const { rows } = await this.pool.query(
      'UPDATE user_xp SET xp = xp + $2, updated_at = now() WHERE user_id = $1 RETURNING xp, level AS old_level',
      [userId, amount],
    );
    const newXp = rows[0].xp;
    const oldLevel = rows[0].old_level;
    const computed = this.computeLevel(newXp);
    const leveledUp = computed.level > oldLevel;

    // Update level
    if (leveledUp) {
      await this.pool.query(
        'UPDATE user_xp SET level = $2, level_name = $3 WHERE user_id = $1',
        [userId, computed.level, computed.name],
      );
    }

    // Log
    await this.pool.query(
      'INSERT INTO xp_log (user_id, amount, reason, source) VALUES ($1,$2,$3,$4)',
      [userId, amount, reason, source],
    );

    this.log.log(`User ${userId}: +${amount}xp (${reason}), total=${newXp}, level=${computed.level}`);
    return { xp: newXp, level: computed.level, levelName: computed.name, leveledUp };
  }

  /** Get XP state for user. */
  async getXpState(userId: number) {
    await this.pool.query(
      'INSERT INTO user_xp (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId],
    );
    const { rows } = await this.pool.query('SELECT * FROM user_xp WHERE user_id = $1', [userId]);
    const state = rows[0];
    const currentLevel = this.levels.find(l => l.level === state.level) || this.levels[0];
    const nextLevel = this.levels.find(l => l.level > state.level);
    return {
      xp: state.xp,
      level: state.level,
      level_name: state.level_name,
      xp_to_next: nextLevel ? nextLevel.min_xp - state.xp : 0,
      next_level_xp: nextLevel?.min_xp ?? state.xp,
      current_level_xp: currentLevel?.min_xp ?? 0,
      progress: nextLevel ? Math.max(0, Math.min(1, (state.xp - (currentLevel?.min_xp ?? 0)) / ((nextLevel.min_xp) - (currentLevel?.min_xp ?? 0)))) : 1,
    };
  }

  /** Get XP log. */
  async getXpLog(userId: number, limit = 30) {
    const { rows } = await this.pool.query(
      'SELECT * FROM xp_log WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2',
      [userId, limit],
    );
    return rows;
  }

  // ── STREAKS ──────────────────────────────────────────────

  /** Update daily streak. Call on login / any activity. */
  async updateStreak(userId: number): Promise<{ current: number; longest: number; isNew: boolean }> {
    await this.pool.query(
      'INSERT INTO user_streaks (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId],
    );

    const { rows } = await this.pool.query('SELECT * FROM user_streaks WHERE user_id = $1', [userId]);
    const streak = rows[0];
    const today = new Date().toISOString().slice(0, 10);
    const lastActive = streak.last_active_date?.toISOString?.()?.slice(0, 10) ?? today;

    if (lastActive === today) {
      return { current: streak.current_streak, longest: streak.longest_streak, isNew: false };
    }

    const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    let newStreak: number;

    if (lastActive === yesterday) {
      newStreak = streak.current_streak + 1;
    } else {
      newStreak = 1; // Streak broken
    }

    const newLongest = Math.max(newStreak, streak.longest_streak);

    await this.pool.query(
      `UPDATE user_streaks SET current_streak = $2, longest_streak = $3, last_active_date = $4, updated_at = now()
       WHERE user_id = $1`,
      [userId, newStreak, newLongest, today],
    );

    return { current: newStreak, longest: newLongest, isNew: true };
  }

  async getStreak(userId: number) {
    await this.pool.query('INSERT INTO user_streaks (user_id) VALUES ($1) ON CONFLICT DO NOTHING', [userId]);
    const { rows } = await this.pool.query('SELECT * FROM user_streaks WHERE user_id = $1', [userId]);
    return rows[0];
  }

  // ── GOALS ────────────────────────────────────────────────

  async createGoal(userId: number, data: { title: string; description?: string; target?: number; xp_reward?: number }) {
    const { rows } = await this.pool.query(
      `INSERT INTO user_goals (user_id, title, description, target, xp_reward)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [userId, data.title, data.description || null, data.target || 1, data.xp_reward || 50],
    );
    return rows[0];
  }

  async updateGoalProgress(goalId: number, userId: number, increment = 1) {
    const { rows } = await this.pool.query(
      `UPDATE user_goals SET progress = LEAST(progress + $3, target)
       WHERE id = $1 AND user_id = $2 RETURNING *`,
      [goalId, userId, increment],
    );
    if (!rows.length) return null;

    const goal = rows[0];
    if (goal.progress >= goal.target && !goal.is_completed) {
      await this.pool.query(
        'UPDATE user_goals SET is_completed = true, completed_at = now() WHERE id = $1',
        [goalId],
      );
      goal.is_completed = true;
      // Grant XP
      await this.addXp(userId, goal.xp_reward, `Цель: ${goal.title}`, 'goal');
    }
    return goal;
  }

  async getUserGoals(userId: number) {
    const { rows } = await this.pool.query(
      'SELECT * FROM user_goals WHERE user_id = $1 ORDER BY is_completed, created_at DESC', [userId],
    );
    return rows;
  }

  // ── ACHIEVEMENTS ─────────────────────────────────────────

  /** Unlock an achievement (idempotent). */
  async unlock(userId: number, achievementId: string): Promise<{ unlocked: boolean; xpGranted: number }> {
    // Check if already unlocked
    const { rows: existing } = await this.pool.query(
      'SELECT 1 FROM user_achievements WHERE user_id = $1 AND achievement_id = $2', [userId, achievementId],
    );
    if (existing.length) return { unlocked: false, xpGranted: 0 };

    // Get achievement
    const { rows: achRows } = await this.pool.query(
      'SELECT * FROM achievements WHERE id = $1', [achievementId],
    );
    if (!achRows.length) return { unlocked: false, xpGranted: 0 };

    const ach = achRows[0];

    // Unlock
    await this.pool.query(
      'INSERT INTO user_achievements (user_id, achievement_id) VALUES ($1,$2) ON CONFLICT DO NOTHING',
      [userId, achievementId],
    );

    // Grant XP
    await this.addXp(userId, ach.xp_reward, `Достижение: ${ach.name}`, 'achievement');

    this.log.log(`User ${userId} unlocked: ${achievementId} (+${ach.xp_reward}xp)`);
    return { unlocked: true, xpGranted: ach.xp_reward };
  }

  /** Check and unlock achievements based on user stats. */
  async checkAchievements(userId: number, event?: string) {
    const unlocked: string[] = [];

    // Count-based checks
    const [releasesCount, tracksCount, aiCount, eventsCount] = await Promise.all([
      this.pool.query('SELECT count(*)::int AS c FROM releases r JOIN artists a ON a.id = r.artist_id WHERE a.user_id = $1', [userId]),
      this.pool.query('SELECT count(*)::int AS c FROM tracks WHERE release_id IN (SELECT r.id FROM releases r JOIN artists a ON a.id = r.artist_id WHERE a.user_id = $1)', [userId]),
      this.pool.query("SELECT count(*)::int AS c FROM credit_transactions WHERE user_id = $1 AND reason LIKE '%ai%'", [userId]).catch(() => ({ rows: [{ c: 0 }] })),
      this.pool.query('SELECT count(*)::int AS c FROM user_events WHERE user_id = $1', [userId]),
    ]);

    const releases = releasesCount.rows[0].c;
    const ai = aiCount.rows[0].c;

    // Event-triggered
    if (event === 'login' || event === 'register') {
      const r = await this.unlock(userId, 'first_login');
      if (r.unlocked) unlocked.push('first_login');
    }

    if (releases >= 1) {
      const r = await this.unlock(userId, 'first_release');
      if (r.unlocked) unlocked.push('first_release');
    }
    if (releases >= 3) {
      const r = await this.unlock(userId, 'releases_3');
      if (r.unlocked) unlocked.push('releases_3');
    }
    if (releases >= 10) {
      const r = await this.unlock(userId, 'releases_10');
      if (r.unlocked) unlocked.push('releases_10');
    }

    if (ai >= 10) {
      const r = await this.unlock(userId, 'ai_10');
      if (r.unlocked) unlocked.push('ai_10');
    }
    if (ai >= 50) {
      const r = await this.unlock(userId, 'ai_50');
      if (r.unlocked) unlocked.push('ai_50');
    }

    // Streak
    const streak = await this.getStreak(userId);
    if (streak.current_streak >= 7) {
      const r = await this.unlock(userId, 'streak_7');
      if (r.unlocked) unlocked.push('streak_7');
    }
    if (streak.current_streak >= 30) {
      const r = await this.unlock(userId, 'streak_30');
      if (r.unlocked) unlocked.push('streak_30');
    }

    // Event-specific
    if (event === 'release_submitted') {
      const r = await this.unlock(userId, 'first_submit');
      if (r.unlocked) unlocked.push('first_submit');
    }
    if (event === 'cover_generated') {
      const r = await this.unlock(userId, 'first_cover');
      if (r.unlocked) unlocked.push('first_cover');
    }
    if (event === 'track_uploaded') {
      const r = await this.unlock(userId, 'first_track');
      if (r.unlocked) unlocked.push('first_track');
    }
    if (event === 'subscription_changed') {
      const r = await this.unlock(userId, 'subscriber');
      if (r.unlocked) unlocked.push('subscriber');
    }
    if (event === 'share') {
      const r = await this.unlock(userId, 'share_first');
      if (r.unlocked) unlocked.push('share_first');
    }

    return unlocked;
  }

  async getUserAchievements(userId: number) {
    const { rows } = await this.pool.query(`
      SELECT a.*, ua.unlocked_at
      FROM achievements a
      LEFT JOIN user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = $1
      ORDER BY a.sort_order
    `, [userId]);
    return rows;
  }

  async getAllAchievements() {
    const { rows } = await this.pool.query('SELECT * FROM achievements ORDER BY sort_order');
    return rows;
  }

  // ── PUBLIC PROFILES ──────────────────────────────────────

  async getPublicProfile(slug: string) {
    const { rows } = await this.pool.query(
      'SELECT * FROM public_profiles WHERE slug = $1 AND is_public = true', [slug],
    );
    if (!rows.length) return null;

    // Increment views
    await this.pool.query('UPDATE public_profiles SET views = views + 1 WHERE slug = $1', [slug]);

    // Get releases
    const profile = rows[0];
    const { rows: releases } = await this.pool.query(
      `SELECT r.id, r.title, r.cover_url, r.status FROM releases r
       JOIN artists a ON a.id = r.artist_id
       WHERE a.user_id = $1 AND r.status = 'live' ORDER BY r.created_at DESC LIMIT 20`,
      [profile.user_id],
    );

    // Get achievements
    const { rows: achievements } = await this.pool.query(`
      SELECT a.name, a.icon, a.category FROM user_achievements ua
      JOIN achievements a ON a.id = ua.achievement_id
      WHERE ua.user_id = $1 ORDER BY ua.unlocked_at DESC LIMIT 10
    `, [profile.user_id]);

    // Get XP
    const { rows: xp } = await this.pool.query('SELECT level, level_name, xp FROM user_xp WHERE user_id = $1', [profile.user_id]);

    return { ...profile, releases, achievements, xp: xp[0] || { level: 1, level_name: 'Rookie', xp: 0 } };
  }

  async upsertPublicProfile(userId: number, data: Record<string, any>) {
    const { rows: existing } = await this.pool.query(
      'SELECT user_id FROM public_profiles WHERE user_id = $1', [userId],
    );

    if (existing.length) {
      const sets: string[] = [];
      const vals: any[] = [];
      let i = 1;
      for (const [k, v] of Object.entries(data)) {
        if (['slug', 'display_name', 'bio', 'genre', 'avatar_url', 'cover_url', 'links', 'is_public'].includes(k)) {
          sets.push(`${k} = $${i++}`);
          vals.push(k === 'links' ? JSON.stringify(v) : v);
        }
      }
      if (!sets.length) return existing[0];
      sets.push(`updated_at = now()`);
      vals.push(userId);
      const { rows } = await this.pool.query(
        `UPDATE public_profiles SET ${sets.join(', ')} WHERE user_id = $${i} RETURNING *`, vals,
      );
      return rows[0];
    } else {
      const { rows } = await this.pool.query(
        `INSERT INTO public_profiles (user_id, slug, display_name, bio, genre, avatar_url, cover_url, is_public)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
        [userId, data.slug || null, data.display_name || null, data.bio || null, data.genre || null, data.avatar_url || null, data.cover_url || null, data.is_public || false],
      );
      return rows[0];
    }
  }

  // ── LEVELS CONFIG ────────────────────────────────────────

  async getLevelConfigs() {
    const { rows } = await this.pool.query('SELECT * FROM level_config ORDER BY level');
    return rows;
  }

  // ── XP REWARDS CONFIG ─────────────────────────────────────

  /** Standard XP rewards for common actions. */
  static XP_REWARDS: Record<string, number> = {
    login: 5,
    daily_login: 10,
    release_created: 20,
    track_uploaded: 15,
    release_submitted: 30,
    cover_generated: 10,
    ai_chat: 3,
    share: 10,
    profile_setup: 20,
  };

  /** Grant XP for a standard action. */
  async grantActionXp(userId: number, action: string) {
    const amount = GrowthService.XP_REWARDS[action];
    if (!amount) return null;
    return this.addXp(userId, amount, action, 'action');
  }
}
