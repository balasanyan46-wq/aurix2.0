import { Injectable, Inject } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { AiGatewayService } from '../ai/ai-gateway.service';
import { AiContextService } from '../ai/ai-context.service';

@Injectable()
export class BrainService {
  constructor(
    @Inject(PG_POOL) private pool: Pool,
    private ai: AiGatewayService,
    private aiContext: AiContextService,
  ) {}

  /** Build/update behavioral profile from events */
  async buildProfile(userId: number) {
    // Count events in windows
    const counts = await this.pool.query(
      `SELECT
        COUNT(*) FILTER (WHERE created_at >= now() - interval '7 days')::int  AS events_7d,
        COUNT(*) FILTER (WHERE created_at >= now() - interval '30 days')::int AS events_30d,
        COUNT(*) FILTER (WHERE event ILIKE '%promo%'
                           AND created_at >= now() - interval '30 days')::int AS promo_count,
        COUNT(*) FILTER (WHERE (event ILIKE '%ai%' OR event ILIKE '%cover%' OR event ILIKE '%generate%')
                           AND created_at >= now() - interval '30 days')::int AS ai_count,
        COUNT(*) FILTER (WHERE event ILIKE '%release%'
                           AND created_at >= now() - interval '30 days')::int AS release_count,
        COUNT(*) FILTER (WHERE (event ILIKE '%track%' OR event ILIKE '%upload%')
                           AND created_at >= now() - interval '30 days')::int AS content_count
      FROM user_events
      WHERE user_id = $1`,
      [userId],
    );

    const c = counts.rows[0] || {};
    const events7d = c.events_7d || 0;
    const events30d = c.events_30d || 0;

    // Top events
    const topRes = await this.pool.query(
      `SELECT event, COUNT(*)::int AS cnt
       FROM user_events
       WHERE user_id = $1 AND created_at >= now() - interval '30 days'
       GROUP BY event
       ORDER BY cnt DESC
       LIMIT 5`,
      [userId],
    );
    const topEvents = topRes.rows.map((r) => r.event);

    // Last release date
    const lastRelease = await this.pool.query(
      `SELECT created_at FROM releases
       WHERE artist_id = $1
       ORDER BY created_at DESC LIMIT 1`,
      [userId],
    );
    const lastReleaseDays = lastRelease.rows[0]
      ? Math.floor(
          (Date.now() - new Date(lastRelease.rows[0].created_at).getTime()) /
            86400000,
        )
      : null;

    // Determine levels
    const activityLevel =
      events7d >= 20 ? 'high' : events7d >= 7 ? 'medium' : 'low';
    const promoUsage = (c.promo_count || 0) > 0;
    const aiUsage = (c.ai_count || 0) > 0;

    // Content focus
    let contentFocus = 'none';
    if ((c.content_count || 0) > 0 && (c.release_count || 0) === 0)
      contentFocus = 'creation_only';
    else if ((c.release_count || 0) > 0 && (c.content_count || 0) === 0)
      contentFocus = 'release_only';
    else if ((c.content_count || 0) > 0 && (c.release_count || 0) > 0)
      contentFocus = 'balanced';

    // Growth status
    let growthStatus = 'new';
    if (events30d === 0) growthStatus = 'inactive';
    else if (lastReleaseDays !== null && lastReleaseDays > 60)
      growthStatus = 'stagnation';
    else if (activityLevel === 'high' && contentFocus === 'balanced')
      growthStatus = 'growing';
    else if (activityLevel === 'medium') growthStatus = 'active';
    else if (events30d > 0) growthStatus = 'exploring';

    // Upsert profile
    await this.pool.query(
      `INSERT INTO user_brain_profiles
        (user_id, activity_level, content_focus, promo_usage, ai_usage,
         last_release_days, growth_status, top_events, events_7d, events_30d, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, now())
       ON CONFLICT (user_id) DO UPDATE SET
         activity_level   = EXCLUDED.activity_level,
         content_focus    = EXCLUDED.content_focus,
         promo_usage      = EXCLUDED.promo_usage,
         ai_usage         = EXCLUDED.ai_usage,
         last_release_days = EXCLUDED.last_release_days,
         growth_status    = EXCLUDED.growth_status,
         top_events       = EXCLUDED.top_events,
         events_7d        = EXCLUDED.events_7d,
         events_30d       = EXCLUDED.events_30d,
         updated_at       = now()`,
      [
        userId,
        activityLevel,
        contentFocus,
        promoUsage,
        aiUsage,
        lastReleaseDays,
        growthStatus,
        topEvents,
        events7d,
        events30d,
      ],
    );

    return {
      activity_level: activityLevel,
      content_focus: contentFocus,
      promo_usage: promoUsage,
      ai_usage: aiUsage,
      last_release_days: lastReleaseDays,
      growth_status: growthStatus,
      top_events: topEvents,
      events_7d: events7d,
      events_30d: events30d,
    };
  }

  /** Get cached profile or build fresh */
  async getProfile(userId: number) {
    const res = await this.pool.query(
      `SELECT * FROM user_brain_profiles WHERE user_id = $1`,
      [userId],
    );
    if (
      res.rows[0] &&
      Date.now() - new Date(res.rows[0].updated_at).getTime() < 3600000
    ) {
      return res.rows[0];
    }
    return this.buildProfile(userId);
  }

  /** Generate personalized AI strategy */
  async generateStrategy(userId: number) {
    const profile = await this.buildProfile(userId);

    // Get recent events summary
    const eventsRes = await this.pool.query(
      `SELECT event, COUNT(*)::int AS cnt,
              MAX(created_at) AS last_at
       FROM user_events
       WHERE user_id = $1 AND created_at >= now() - interval '14 days'
       GROUP BY event
       ORDER BY cnt DESC
       LIMIT 15`,
      [userId],
    );

    const eventsSummary = eventsRes.rows
      .map(
        (r) =>
          `${r.event}: ${r.cnt} times (last: ${new Date(r.last_at).toLocaleDateString()})`,
      )
      .join('\n');

    // Get user context
    let contextPrompt = '';
    try {
      const ctx = await this.aiContext.buildContext(String(userId), 'full');
      contextPrompt = this.aiContext.contextToPrompt(ctx);
    } catch {
      // Context may fail if no data
    }

    const prompt = `You are a music producer and growth strategist for the AURIX platform.

User profile:
- Activity level: ${profile.activity_level}
- Content focus: ${profile.content_focus}
- Uses promo tools: ${profile.promo_usage}
- Uses AI tools: ${profile.ai_usage}
- Days since last release: ${profile.last_release_days ?? 'never released'}
- Growth status: ${profile.growth_status}
- Events last 7 days: ${profile.events_7d}
- Events last 30 days: ${profile.events_30d}
- Top actions: ${profile.top_events.join(', ') || 'none'}

User behavior (last 14 days):
${eventsSummary || 'No activity recorded'}

${contextPrompt ? `Artist context:\n${contextPrompt}` : ''}

Tasks:
1. Identify the main problem holding this artist back
2. Identify the biggest growth opportunity right now
3. Select the best strategy focus (one of: content / release / analytics / promo)
4. Generate 3 specific tasks for today
5. Generate a 7-day plan (one task per day)
6. Give 3 quick actions that can be done in under 5 minutes

IMPORTANT: Respond in Russian. Be specific, actionable, and personal.

Return ONLY valid JSON (no markdown, no code blocks):
{
  "problem": "main problem description",
  "opportunity": "growth opportunity",
  "strategy": "content|release|analytics|promo",
  "today_tasks": [
    {"title": "task title", "description": "what to do", "category": "content|release|analytics|promo"}
  ],
  "week_plan": [
    {"day": 1, "task": "task description", "category": "content|release|analytics|promo"}
  ],
  "quick_actions": [
    {"title": "action title", "description": "quick description"}
  ]
}`;

    const response = await this.ai.chat({
      message: prompt,
      mode: 'chat',
    });

    // Extract JSON from response
    let parsed: any;
    try {
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      parsed = jsonMatch ? JSON.parse(jsonMatch[0]) : null;
    } catch {
      parsed = null;
    }

    if (!parsed) {
      return {
        problem: 'Не удалось сгенерировать стратегию',
        opportunity: '',
        strategy: 'content',
        today_tasks: [],
        week_plan: [],
        quick_actions: [],
        raw: response,
      };
    }

    // Cache the strategy
    await this.pool
      .query(
        `INSERT INTO user_brain_strategies (user_id, strategy_json, created_at)
         VALUES ($1, $2, now())
         ON CONFLICT (user_id) DO UPDATE SET
           strategy_json = EXCLUDED.strategy_json,
           created_at = now()`,
        [userId, JSON.stringify(parsed)],
      )
      .catch(() => {});

    return parsed;
  }

  /** Get cached strategy or generate new one */
  async getStrategy(userId: number) {
    const res = await this.pool.query(
      `SELECT strategy_json, created_at FROM user_brain_strategies WHERE user_id = $1`,
      [userId],
    );
    // Return cached if less than 6 hours old
    if (
      res.rows[0] &&
      Date.now() - new Date(res.rows[0].created_at).getTime() < 21600000
    ) {
      return res.rows[0].strategy_json;
    }

    // Return stale cache if exists (while regenerating in background)
    if (res.rows[0]) {
      // Fire-and-forget regeneration
      this.generateStrategy(userId).catch(() => {});
      return res.rows[0].strategy_json;
    }

    // No cache at all — try AI, fallback to static recommendations
    try {
      return await this.generateStrategy(userId);
    } catch {
      return this.buildFallbackStrategy(userId);
    }
  }

  /** Fallback strategy when AI is unavailable */
  private async buildFallbackStrategy(userId: number) {
    const relCount = await this.pool.query(
      `SELECT COUNT(*)::int AS cnt FROM releases WHERE user_id = $1`, [userId],
    ).then(r => r.rows[0]?.cnt || 0).catch(() => 0);

    const tasks: Array<{ title: string; description: string; category: string }> = [];
    if (relCount === 0) {
      tasks.push({ title: 'Создай первый релиз', description: 'Загрузи трек и обложку в разделе Релизы', category: 'release' });
      tasks.push({ title: 'Настрой профиль артиста', description: 'Заполни имя, жанр и цели в разделе Артист', category: 'content' });
      tasks.push({ title: 'Попробуй AI Studio', description: 'Сгенерируй текст или обложку с помощью AI', category: 'content' });
    } else {
      tasks.push({ title: 'Продвигай свою музыку', description: 'Открой раздел Промо и создай кампанию', category: 'promo' });
      tasks.push({ title: 'Сгенерируй обложку', description: 'AI создаст обложку под твой стиль', category: 'content' });
      tasks.push({ title: 'Проверь статистику', description: 'Загрузи отчёты платформ в разделе Статистика', category: 'analytics' });
    }

    return {
      problem: relCount === 0 ? 'У тебя пока нет релизов' : 'Продвижение поможет вырасти',
      opportunity: relCount === 0 ? 'Начни с первого трека — платформы ждут' : 'Используй промо-инструменты для роста стримов',
      strategy: relCount === 0 ? 'release' : 'promo',
      today_tasks: tasks,
      week_plan: [
        { day: 1, task: tasks[0]?.description || 'Работай над музыкой', category: tasks[0]?.category || 'content' },
        { day: 2, task: 'Работай над обложкой релиза', category: 'content' },
        { day: 3, task: 'Изучи AI Studio — попробуй генерацию', category: 'content' },
        { day: 4, task: 'Подготовь метаданные релиза', category: 'release' },
        { day: 5, task: 'Опубликуй в соцсетях', category: 'promo' },
        { day: 6, task: 'Проверь аналитику', category: 'analytics' },
        { day: 7, task: 'Спланируй следующую неделю', category: 'content' },
      ],
      quick_actions: [
        { title: 'AI Studio', description: 'Открой AI-ассистента' },
        { title: 'Релизы', description: 'Проверь статус релизов' },
        { title: 'Промо', description: 'Запусти продвижение' },
      ],
      _fallback: true,
    };
  }
}
