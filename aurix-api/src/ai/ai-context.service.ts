import { Inject, Injectable, Logger } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { AiProfileService } from './ai-profile.service';

export type ContextMode = 'full' | 'no_dnk' | 'clean';

export interface AiUserContext {
  artist?: {
    name: string;
    artist_name: string;
    city: string;
    bio: string;
    plan: string;
  };
  ai_profile?: string; // AI profile prompt block
  tracks?: Array<{
    title: string;
    genre: string;
    release_type: string;
    status: string;
    plays: number;
    release_date: string;
  }>;
  current_track?: {
    title: string;
    genre: string;
    release_type: string;
    status: string;
    release_date: string;
  };
  dnk?: Record<string, unknown> | null;
  stats?: {
    total_releases: number;
    live_releases: number;
    total_clicks: number;
    total_views: number;
  };
}

@Injectable()
export class AiContextService {
  private readonly logger = new Logger(AiContextService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly profileSvc: AiProfileService,
  ) {}

  /**
   * Collect all available context for a user.
   */
  async buildContext(
    userId: string,
    mode: ContextMode = 'full',
    trackId?: string,
  ): Promise<AiUserContext> {
    if (mode === 'clean') return {};

    const ctx: AiUserContext = {};

    try {
      // 1. Profile (profiles.id = auth.users.id = UUID)
      const { rows: profileRows } = await this.pool.query(
        `SELECT name, display_name, artist_name, city, bio, plan
         FROM profiles WHERE user_id = $1 LIMIT 1`,
        [userId],
      );
      if (profileRows[0]) {
        const p = profileRows[0];
        ctx.artist = {
          name: p.display_name || p.name || '',
          artist_name: p.artist_name || '',
          city: p.city || '',
          bio: p.bio || '',
          plan: p.plan || 'none',
        };
      }

      // 1b. AI Profile (optional artist identity for AI personalization)
      try {
        const aiProfile = await this.profileSvc.get(Number(userId));
        const aiBlock = this.profileSvc.toPrompt(aiProfile);
        if (aiBlock) ctx.ai_profile = aiBlock;
      } catch {
        // user_ai_profiles table may not exist yet — ignore
      }

      // 2. Releases + Tracks (releases.owner_id = profiles.id = user UUID)
      const { rows: releases } = await this.pool.query(
        `SELECT r.id, r.title, r.release_type, r.status,
                r.genre, r.release_date,
                COALESCE(c.cnt, 0) AS clicks,
                COALESCE(v.cnt, 0) AS views
         FROM releases r
         LEFT JOIN (
           SELECT release_id, COUNT(*) AS cnt FROM release_clicks GROUP BY release_id
         ) c ON c.release_id = r.id
         LEFT JOIN (
           SELECT release_id, COUNT(*) AS cnt FROM release_page_views GROUP BY release_id
         ) v ON v.release_id = r.id
         JOIN artists a ON a.id = r.artist_id
         WHERE a.user_id = $1
         ORDER BY r.created_at DESC
         LIMIT 20`,
        [userId],
      );

      if (releases.length > 0) {
        ctx.tracks = releases.map((r) => ({
          title: r.title || '',
          genre: r.genre || '',
          release_type: r.release_type || 'single',
          status: r.status || 'draft',
          plays: Number(r.clicks) + Number(r.views),
          release_date: r.release_date
            ? new Date(r.release_date).toISOString().slice(0, 10)
            : '',
        }));

        ctx.stats = {
          total_releases: releases.length,
          live_releases: releases.filter((r) => r.status === 'live').length,
          total_clicks: releases.reduce((s, r) => s + Number(r.clicks), 0),
          total_views: releases.reduce((s, r) => s + Number(r.views), 0),
        };
      }

      // 3. Specific track context (scoped to user's releases only)
      if (trackId) {
        const { rows: trackRows } = await this.pool.query(
          `SELECT r.title, r.genre, r.release_type, r.status, r.release_date
           FROM releases r
           JOIN artists a ON a.id = r.artist_id
           WHERE r.id = $1 AND a.user_id = $2
           LIMIT 1`,
          [trackId, userId],
        );
        if (trackRows[0]) {
          const t = trackRows[0];
          ctx.current_track = {
            title: t.title || '',
            genre: t.genre || '',
            release_type: t.release_type || 'single',
            status: t.status || 'draft',
            release_date: t.release_date
              ? new Date(t.release_date).toISOString().slice(0, 10)
              : '',
          };
        }
      }

      // 4. DNK results (only in 'full' mode)
      if (mode === 'full') {
        try {
          // Main DNK profile — join through dnk_sessions to filter by user
          const { rows: dnkRows } = await this.pool.query(
            `SELECT dr.* FROM dnk_results dr
             JOIN dnk_sessions ds ON dr.session_id = ds.id
             WHERE ds.user_id = $1 AND ds.status = 'finished'
             ORDER BY dr.created_at DESC LIMIT 1`,
            [userId],
          );
          if (dnkRows[0]) {
            ctx.dnk = this.parseDnk(dnkRows[0]);
          }

          // Professional DNK tests (6 tests) — add completed test results
          const { rows: testRows } = await this.pool.query(
            `SELECT dtr.test_slug, dtr.score_axes, dtr.summary,
                    dtr.strengths, dtr.risks, dtr.actions_7_days
             FROM dnk_test_results dtr
             JOIN dnk_test_sessions dts ON dtr.session_id = dts.id
             WHERE dts.user_id = $1 AND dts.status = 'finished'
             ORDER BY dtr.created_at DESC`,
            [userId],
          );
          if (testRows.length > 0) {
            // Deduplicate: keep latest result per test_slug
            const seen = new Set<string>();
            const tests: Record<string, unknown>[] = [];
            for (const row of testRows) {
              if (!seen.has(row.test_slug)) {
                seen.add(row.test_slug);
                tests.push({
                  test: row.test_slug,
                  scores: row.score_axes,
                  summary: row.summary,
                  strengths: row.strengths,
                  risks: row.risks,
                  actions: row.actions_7_days,
                });
              }
            }
            if (!ctx.dnk) ctx.dnk = {};
            (ctx.dnk as Record<string, unknown>).professional_tests = tests;
          }
        } catch (e) {
          // dnk tables may not exist — ignore
          this.logger.debug('DNK results not available');
        }
      }
    } catch (e) {
      this.logger.error('Failed to build AI context', e);
    }

    return ctx;
  }

  /**
   * Convert context into a system prompt section.
   */
  contextToPrompt(ctx: AiUserContext): string {
    if (!ctx.artist && !ctx.tracks && !ctx.dnk && !ctx.ai_profile) return '';

    const parts: string[] = [];
    parts.push('## КОНТЕКСТ АРТИСТА (используй для персонализации ответов)\n');

    // AI profile (genre, mood, goals, references from Studio)
    if (ctx.ai_profile) {
      parts.push(ctx.ai_profile);
      parts.push('');
    }

    if (ctx.artist) {
      const a = ctx.artist;
      parts.push(`Имя: ${a.artist_name || a.name}`);
      if (a.city) parts.push(`Город: ${a.city}`);
      if (a.bio) parts.push(`Bio: ${a.bio}`);
      parts.push(`План: ${a.plan}`);
      parts.push('');
    }

    if (ctx.current_track) {
      const t = ctx.current_track;
      parts.push(`ТЕКУЩИЙ ТРЕК (артист спрашивает именно про него):`);
      parts.push(`— "${t.title}" (${t.genre || 'жанр не указан'}, ${t.release_type})`);
      parts.push(`— Статус: ${t.status}`);
      if (t.release_date) parts.push(`— Дата релиза: ${t.release_date}`);
      parts.push('');
    }

    if (ctx.tracks && ctx.tracks.length > 0) {
      parts.push(`Каталог (${ctx.tracks.length} релизов):`);
      for (const t of ctx.tracks.slice(0, 10)) {
        parts.push(
          `— "${t.title}" (${t.genre || '?'}, ${t.status}, ${t.plays} взаимодействий)`,
        );
      }
      parts.push('');
    }

    if (ctx.stats) {
      const s = ctx.stats;
      parts.push(
        `Статистика: ${s.live_releases} live из ${s.total_releases}, ${s.total_clicks} кликов, ${s.total_views} просмотров`,
      );
      parts.push('');
    }

    if (ctx.dnk) {
      const dnk = ctx.dnk as Record<string, unknown>;
      const profTests = dnk.professional_tests;

      parts.push('═══ DNK ПРОФИЛЬ АРТИСТА (его уникальная ДНК — используй АКТИВНО) ═══');
      parts.push('');

      // Main DNK axes — human readable
      const axes = dnk.axes as Record<string, number> | undefined;
      if (axes && typeof axes === 'object') {
        const axisLabels: Record<string, [string, string, string]> = {
          energy: ['Энергия', 'спокойный', 'взрывной'],
          novelty: ['Новизна', 'традиционный', 'экспериментатор'],
          darkness: ['Темнота', 'светлый', 'тёмный/драматичный'],
          lyric_focus: ['Лирика', 'подача/флоу', 'глубокий смысл'],
          structure: ['Структура', 'импульс/поток', 'план/контроль'],
          conflict_style: ['Конфликт', 'дипломат', 'прямой/резкий'],
          publicness: ['Публичность', 'закрытый', 'открытый'],
          commercial_focus: ['Коммерция', 'чистый арт', 'рынок'],
        };
        parts.push('ХАРАКТЕР (0-100):');
        for (const [key, val] of Object.entries(axes)) {
          const v = typeof val === 'number' ? val : 0;
          const info = axisLabels[key];
          if (info) {
            const [label, low, high] = info;
            const desc = v >= 70 ? high : v <= 30 ? low : `между ${low} и ${high}`;
            parts.push(`  ${label}: ${v}/100 → ${desc}`);
          } else {
            parts.push(`  ${key}: ${v}/100`);
          }
        }
        parts.push('');
      }

      // Social axes
      const socialAxes = dnk.social_axes as Record<string, number> | undefined;
      if (socialAxes && typeof socialAxes === 'object') {
        parts.push('СОЦИАЛЬНЫЙ ПРОФИЛЬ:');
        const socialLabels: Record<string, string> = {
          warmth: 'Теплота', power: 'Власть/авторитет', edge: 'Провокативность', clarity: 'Прозрачность',
        };
        for (const [key, val] of Object.entries(socialAxes)) {
          parts.push(`  ${socialLabels[key] || key}: ${val}/100`);
        }
        parts.push('');
      }

      // Passport hero
      const passport = dnk.passport as Record<string, unknown> | undefined;
      if (passport) {
        if (passport.hook) parts.push(`СУТЬ АРТИСТА: ${passport.hook}`);
        if (passport.how_people_feel_you) parts.push(`КАК ВОСПРИНИМАЮТ: ${passport.how_people_feel_you}`);
        if (Array.isArray(passport.magnet) && passport.magnet.length > 0) {
          parts.push(`ПРИТЯГИВАЕТ: ${passport.magnet.join(', ')}`);
        }
        if (passport.shadow) parts.push(`ТЕНЬ (слабое место): ${passport.shadow}`);
        parts.push('');
      }

      // Recommendations
      const recs = dnk.recommendations as Record<string, unknown> | undefined;
      if (recs && typeof recs === 'object') {
        parts.push('РЕКОМЕНДАЦИИ ИЗ DNK:');
        for (const [area, content] of Object.entries(recs)) {
          if (typeof content === 'string') {
            parts.push(`  ${area}: ${content}`);
          } else if (content && typeof content === 'object') {
            parts.push(`  ${area}: ${JSON.stringify(content)}`);
          }
        }
        parts.push('');
      }

      // Professional tests — readable format
      if (Array.isArray(profTests) && profTests.length > 0) {
        parts.push(`ПРОЙДЕННЫЕ ТЕСТЫ DNK (${profTests.length}/6):`);
        const testNames: Record<string, string> = {
          artist_archetype: 'Архетип артиста',
          tone_communication: 'Тон коммуникации',
          story_core: 'Сюжетное ядро',
          growth_profile: 'Профиль роста',
          discipline_index: 'Индекс дисциплины',
          career_risk: 'Риск-профиль',
        };
        for (const t of profTests as Array<Record<string, unknown>>) {
          const name = testNames[t.test as string] || t.test;
          parts.push(`\n▸ ${name}`);
          if (t.summary) parts.push(`  Вывод: ${t.summary}`);
          if (Array.isArray(t.strengths) && t.strengths.length > 0) {
            parts.push(`  Сильные стороны: ${(t.strengths as string[]).join('; ')}`);
          }
          if (Array.isArray(t.risks) && t.risks.length > 0) {
            parts.push(`  Зоны риска: ${(t.risks as string[]).join('; ')}`);
          }
        }
        parts.push('');
      }

      parts.push('ВАЖНО: Ты ЗНАЕШЬ этого артиста через его DNK. Обращайся к его сильным сторонам, учитывай слабые. Не давай generic советы — всё должно быть через призму его уникального профиля. Если артист спрашивает совет — привязывай к его осям и архетипу.');
    }

    return parts.join('\n');
  }

  private parseDnk(raw: Record<string, unknown>): Record<string, unknown> {
    // Try to extract meaningful fields from DNK result
    const result: Record<string, unknown> = {};

    // Common fields that might be in the result
    const keys = [
      'axes', 'social_summary', 'passport', 'recommendations',
      'prompts', 'social_axes', 'social_scripts',
    ];

    for (const key of keys) {
      if (raw[key]) {
        result[key] = raw[key];
      }
    }

    // If the result itself is the data (JSONB column)
    if (raw.result && typeof raw.result === 'object') {
      return raw.result as Record<string, unknown>;
    }

    if (Object.keys(result).length === 0) {
      // Return all non-system fields
      const { id, user_id, created_at, updated_at, ...rest } = raw;
      return rest;
    }

    return result;
  }
}
