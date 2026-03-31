import { Injectable, Logger } from '@nestjs/common';
import * as crypto from 'crypto';
import { EdenAiService } from '../ai/eden-ai.service';

// ── System prompts ────────

const GROWTH_PLAN_SYSTEM = `Ты — персональный AI-стратег музыкального маркетинга сервиса Aurix.
ВАЖНО: Каждый ответ должен быть УНИКАЛЬНЫМ и ПЕРСОНАЛЬНЫМ для конкретного артиста.
Ты получишь полный профиль артиста, данные релиза, треклист и каталог. Используй ВСЮ эту информацию.
Ответ СТРОГО в JSON:
{
  "summary": "персональная стратегия для артиста",
  "positioning": {"one_liner": "...", "angle": "...", "audience": "..."},
  "risks": ["..."],
  "levers": ["..."],
  "content_angles": ["..."],
  "quick_wins_48h": ["..."],
  "weekly_focus": [{"week":1,"focus":"..."},{"week":2,"focus":"..."},{"week":3,"focus":"..."},{"week":4,"focus":"..."}],
  "days": [{"day":0,"title":"...","tasks":["..."],"outputs":["..."],"time_min":45}],
  "checkpoints": [{"day":7,"kpi":["..."],"actions":["..."]}]
}
Пиши на русском.`;

const BUDGET_PLAN_SYSTEM = `Ты — персональный AI-финансовый стратег Aurix для музыкантов.
ВАЖНО: Бюджет-план должен быть ПЕРСОНАЛЬНЫМ — учитывай артиста, его город, жанр, опыт.
Ответ СТРОГО в JSON:
{
  "summary": "персональная бюджетная стратегия",
  "risks": ["..."],
  "must_do": ["..."],
  "anti_waste": ["..."],
  "cheapest_strategy": "...",
  "allocation": [{"category":"...","amount":0,"percent":0,"notes":"...","currency":"₽"}],
  "dont_spend_on": ["..."],
  "must_spend_on": ["..."],
  "next_steps": ["..."]
}
Пиши на русском.`;

const PACKAGING_SYSTEM = `Ты — персональный AI-копирайтер и маркетолог Aurix. Создаёшь УНИКАЛЬНУЮ упаковку для конкретного релиза.
Ответ СТРОГО в JSON:
{
  "title_variants": ["..."],
  "description_platforms": {"yandex": "...", "vk": "...", "spotify": "...", "apple": "..."},
  "storytelling": "...",
  "hooks": ["..."],
  "cta_variants": ["..."]
}
Пиши на русском.`;

const CONTENT_PLAN_SYSTEM = `Ты — персональный AI-контент-стратег Aurix. Создаёшь 14-дневный контент-план для продвижения конкретного релиза.
Ответ СТРОГО в JSON:
{
  "strategy": "...",
  "days": [{"day": 1, "format": "...", "hook": "...", "script": "...", "shotlist": ["..."], "cta": "..."}]
}
Пиши на русском.`;

const PITCH_PACK_SYSTEM = `Ты — персональный AI-PR стратег Aurix. Создаёшь питч-пакет для плейлист-кураторов и журналистов.
Ответ СТРОГО в JSON:
{
  "short_pitch": "...",
  "long_pitch": "...",
  "email_subjects": ["..."],
  "press_lines": ["..."],
  "artist_bio": "..."
}
Пиши на русском.`;

const DNK_CONTENT_BRIDGE_SYSTEM = `Ты — DNK→Content Bridge.
Преобразуй DNK-результат в практичный 14-дневный контент-план.
Ответ СТРОГО в JSON:
{
  "summary":"...",
  "content_pillars":["..."],
  "tone_rules":["..."],
  "hooks":["..."],
  "days":[{"day":1,"format":"...","idea":"...","cta":"..."}]
}`;

const TOOL_PROMPTS: Record<string, string> = {
  'release-growth-plan': GROWTH_PLAN_SYSTEM,
  'growth-plan': GROWTH_PLAN_SYSTEM,
  'release-budget-plan': BUDGET_PLAN_SYSTEM,
  'budget-plan': BUDGET_PLAN_SYSTEM,
  'release-packaging': PACKAGING_SYSTEM,
  'content-plan-14': CONTENT_PLAN_SYSTEM,
  'playlist-pitch-pack': PITCH_PACK_SYSTEM,
  'dnk-content-bridge': DNK_CONTENT_BRIDGE_SYSTEM,
};

// ── In-memory cache ────────────────

interface CacheEntry {
  data: object;
  expiresAt: number;
}

const CACHE_TTL_MS = 12 * 60 * 60 * 1000; // 12 hours
const cache = new Map<string, CacheEntry>();

function cacheCleanup() {
  const now = Date.now();
  for (const [k, v] of cache) {
    if (v.expiresAt < now) cache.delete(k);
  }
}

// ── Service ─────────────────────────────────────────────────

@Injectable()
export class StudioToolsService {
  private readonly logger = new Logger(StudioToolsService.name);

  constructor(private readonly ai: EdenAiService) {}

  private buildUserPrompt(inputs: Record<string, any>): string {
    const parts: string[] = [];

    const ctx = inputs.context ?? {};

    // Artist info
    const artist = ctx.artist ?? {};
    if (artist.name) {
      const artistParts = [`Артист: ${artist.name}`];
      if (artist.real_name && artist.real_name !== artist.name) artistParts.push(`Настоящее имя: ${artist.real_name}`);
      if (artist.city) artistParts.push(`Город: ${artist.city}`);
      if (artist.bio) artistParts.push(`Био: ${artist.bio}`);
      parts.push(artistParts.join('\n'));
    }

    // Release info
    const release = ctx.release ?? {};
    if (release.title) {
      const relParts = [
        `Релиз: «${release.title}»`,
        `Исполнитель: ${release.artist ?? '—'}`,
        `Жанр: ${release.genre ?? 'не указан'}`,
        `Тип: ${release.release_type ?? 'single'}`,
      ];
      if (release.language) relParts.push(`Язык: ${release.language}`);
      if (release.release_date) relParts.push(`Дата релиза: ${release.release_date}`);
      parts.push(relParts.join('\n'));
    }

    // Tracks
    const tracks = ctx.tracks ?? [];
    if (tracks.length > 0) {
      const trackLines = tracks.map((t: any, i: number) =>
        `  ${i + 1}. «${t.title || 'Без названия'}»${t.isrc ? ` [ISRC: ${t.isrc}]` : ''}`,
      );
      parts.push('Треки:\n' + trackLines.join('\n'));
    }

    // Catalog
    const catalog = ctx.catalog ?? [];
    if (catalog.length > 0) {
      parts.push('Другие релизы:\n' + catalog.map((r: any) => `  — ${r}`).join('\n'));
    }

    // Answers (form inputs from the user)
    const answers = inputs.answers ?? {};
    if (Object.keys(answers).length > 0) {
      parts.push('Ответы пользователя:\n' + JSON.stringify(answers, null, 2));
    }

    // AI summary
    if (inputs.ai_summary) {
      parts.push(`AI резюме: ${inputs.ai_summary}`);
    }

    return parts.join('\n\n') || 'Нет данных';
  }

  private getCacheKey(toolName: string, inputs: Record<string, any>): string {
    const seed = JSON.stringify({ tool: toolName, inputs });
    return `tool:${toolName}:${crypto.createHash('sha256').update(seed).digest('hex')}`;
  }

  async generate(
    toolName: string,
    releaseId: string,
    inputs: Record<string, any>,
  ): Promise<{ ok: boolean; data?: any; error?: string; is_demo?: boolean }> {
    const systemPrompt = TOOL_PROMPTS[toolName];
    if (!systemPrompt) {
      return { ok: false, error: `Unknown tool: ${toolName}` };
    }

    // Check cache
    const cacheKey = this.getCacheKey(toolName, inputs);
    const now = Date.now();
    const cached = cache.get(cacheKey);
    if (cached && cached.expiresAt > now) {
      this.logger.log(`Cache hit for ${toolName}`);
      return { ok: true, data: cached.data };
    }

    // Cleanup old entries periodically
    if (cache.size > 500) cacheCleanup();

    const userPrompt = this.buildUserPrompt(inputs);

    try {
      const raw = await this.ai.simpleChat(systemPrompt, userPrompt, {
        maxTokens: 3800,
        temperature: 0.85,
        timeout: 60_000,
      });

      let parsed: any;
      try {
        const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
        parsed = JSON.parse(fenceMatch ? fenceMatch[1].trim() : raw.trim());
      } catch {
        parsed = { _raw_text: raw };
      }

      // Cache the result
      cache.set(cacheKey, { data: parsed, expiresAt: now + CACHE_TTL_MS });

      return { ok: true, data: parsed };
    } catch (err: any) {
      this.logger.error(`Tool ${toolName} AI error: ${err.message}`);
      return { ok: false, error: err.message ?? 'AI generation failed' };
    }
  }
}
