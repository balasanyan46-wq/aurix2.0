import {
  handleDnkStart,
  handleDnkAnswer,
  handleDnkFinish,
  handleDnkGetResult,
  handleDnkOptions,
} from "./dnk/handlers";
import type { DnkEnv } from "./dnk/types";
import {
  handleDnkTestsCatalog,
  handleDnkTestsProgress,
  handleDnkTestsStart,
  handleDnkTestsAnswer,
  handleDnkTestsFinish,
  handleDnkTestsGetResult,
  handleDnkTestsOptions,
} from "./dnk_tests/handlers";
import type { DnkTestsEnv } from "./dnk_tests/types";
import {
  handleSmartLink,
  handleVisit,
  handleClick,
  handleTop10,
  handleTopPage,
  type AaiEnv,
} from "./aai/handlers";
import {
  buildCorsHeaders as sharedBuildCorsHeaders,
  corsOptionsResponse,
} from "./cors";

interface Env {
  OPENAI_API_KEY: string;
  AI_API_KEY?: string;
  AI_BASE_URL?: string;
  AURIX_INTERNAL_KEY: string;
  AURIX_CACHE: KVNamespace;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
  ALLOWED_ORIGINS?: string;
  ENV?: string;
}

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

type StudioToolId =
  | "growth_plan"
  | "budget_plan"
  | "packaging"
  | "content_plan"
  | "pitch_pack";

type LegacyToolName =
  | "growth-plan"
  | "budget-plan"
  | "release-packaging"
  | "content-plan-14"
  | "playlist-pitch-pack";

type UnifiedStudioRequest = {
  tool_id: StudioToolId;
  context: Record<string, unknown>;
  answers: Record<string, unknown>;
  ai_summary: string;
  locale: string;
  output_format: "json";
  output_version: string;
};

const RATE_LIMIT = 30;
const RATE_WINDOW_MS = 60_000;
const rateMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip);
  if (!entry || now >= entry.resetAt) {
    rateMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  if (entry.count >= RATE_LIMIT) return false;
  entry.count++;
  // Cleanup expired entries
  if (rateMap.size > 1000) {
    const now2 = Date.now();
    for (const [k, v] of rateMap) {
      if (v.resetAt < now2) rateMap.delete(k);
    }
  }
  return true;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, X-AURIX-INTERNAL-KEY",
  "Access-Control-Max-Age": "86400",
};

function jsonResp(body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

function buildCorsHeaders(request: Request, env: Env): Record<string, string> {
  return sharedBuildCorsHeaders(request, env);
}

function jsonRespWithCors(request: Request, env: Env, body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...buildCorsHeaders(request, env),
    },
  });
}

function weekRangeUtc(now: Date): { start: string; end: string } {
  const day = now.getUTCDay() || 7;
  const start = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - (day - 1)));
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 6);
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
  };
}

async function upsertAdminWeeklyDigest(env: Env, digest: any): Promise<void> {
  try {
    const now = new Date();
    const wr = weekRangeUtc(now);
    await fetch(`${env.SUPABASE_URL}/rest/v1/weekly_digests`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        Prefer: "return=minimal",
      },
      body: JSON.stringify([
        {
          scope: "admin",
          user_id: null,
          week_start: wr.start,
          week_end: wr.end,
          title: String(digest?.title ?? "Weekly Executive Digest"),
          summary: String(digest?.summary ?? "No summary"),
          metrics: digest?.metrics ?? {},
          priorities: digest?.priorities ?? [],
        },
      ]),
    });
  } catch (e) {
    console.error("[upsertAdminWeeklyDigest] error:", e);
  }
}

async function scanAndLogSlaOverdue(env: Env): Promise<void> {
  try {
    const nowIso = new Date().toISOString();
    const q = new URL(`${env.SUPABASE_URL}/rest/v1/production_order_items`);
    q.searchParams.set("select", "id,order_id,user_id,status,deadline_at");
    q.searchParams.set("deadline_at", `lt.${nowIso}`);
    q.searchParams.set("status", "in.(not_started,waiting_artist,in_progress,review)");

    const res = await fetch(q.toString(), {
      headers: {
        apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
      },
    });
    if (!res.ok) return;
    const rows = (await res.json()) as any[];
    if (!Array.isArray(rows) || rows.length === 0) return;

    await fetch(`${env.SUPABASE_URL}/rest/v1/production_sla_events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,
        Prefer: "return=minimal",
      },
      body: JSON.stringify(
        rows.map((row) => ({
          order_item_id: row.id,
          order_id: row.order_id,
          user_id: row.user_id,
          event_type: "sla_overdue",
          severity: "critical",
          payload: {
            status: row.status,
            deadline_at: row.deadline_at,
            source: "worker_cron",
          },
        })),
      ),
    });
  } catch (e) {
    console.error("[scanAndLogSlaOverdue] error:", e);
  }
}

async function sha256(data: string): Promise<string> {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(data));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function cachedAI(
  env: Env,
  cacheKey: string,
  systemPrompt: string,
  userPrompt: string,
  maxTokens = 2500
): Promise<object> {
  const cached = await env.AURIX_CACHE.get(cacheKey, "json");
  if (cached) return cached as object;

  const apiKey = (env.AI_API_KEY ?? env.OPENAI_API_KEY ?? "").trim();
  if (!apiKey) throw new Error("Missing AI API key");
  const aiBaseUrl = (env.AI_BASE_URL ?? "https://api.openai.com").replace(/\/+$/, "");
  const res = await fetch(`${aiBaseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      max_tokens: maxTokens,
      temperature: 0.85,
      response_format: { type: "json_object" },
    }),
  });

  const rawBody = await res.text();
  let data: any = null;
  try {
    data = JSON.parse(rawBody);
  } catch {
    data = null;
  }
  if (!res.ok) {
    console.error(`[cachedAI] upstream_error status=${res.status} body=${rawBody.slice(0, 1000)}`);
    throw new Error(data?.error?.message ?? `OpenAI error ${res.status}`);
  }

  const raw = data?.choices?.[0]?.message?.content?.trim() ?? "{}";
  const parsed = parseJsonSafe(raw) ?? { _raw_text: raw };

  await env.AURIX_CACHE.put(cacheKey, JSON.stringify(parsed), { expirationTtl: 43200 });
  return parsed;
}

// ─── HELPERS ────────────────────────────────────────────────────────────

function artistBlock(body: any): string {
  const p = body.profile ?? {};
  const parts: string[] = [];
  if (p.artist_name) parts.push(`Артист: ${p.artist_name}`);
  if (p.real_name && p.real_name !== p.artist_name) parts.push(`Настоящее имя: ${p.real_name}`);
  if (p.city) parts.push(`Город: ${p.city}`);
  if (p.bio) parts.push(`Био: ${p.bio}`);
  return parts.length > 0 ? parts.join("\n") : "Информация об артисте не заполнена";
}

function tracksBlock(body: any): string {
  const tracks = body.tracks ?? [];
  if (!tracks.length) return "Треки: не добавлены";
  return "Треки:\n" + tracks.map((t: any, i: number) =>
    `  ${i + 1}. «${t.title || "Без названия"}»${t.isrc ? ` [ISRC: ${t.isrc}]` : ""}${t.version && t.version !== "original" ? ` (${t.version})` : ""}${t.explicit ? " [E]" : ""}`
  ).join("\n");
}

function catalogBlock(body: any): string {
  const cat = body.catalog ?? [];
  if (!cat.length) return "";
  return "\nДругие релизы артиста:\n" + cat.map((r: any) =>
    `  — «${r.title}» (${r.release_type}, ${r.genre || "?"}, статус: ${r.status})`
  ).join("\n");
}

function releaseBlock(body: any): string {
  const r = body.release ?? {};
  const parts = [
    `Релиз: «${r.title ?? "—"}»`,
    `Исполнитель: ${r.artist ?? "—"}`,
    `Жанр: ${r.genre ?? "не указан"}`,
    `Тип: ${r.release_type ?? "single"}`,
  ];
  if (r.language) parts.push(`Язык: ${r.language}`);
  if (r.label) parts.push(`Лейбл: ${r.label}`);
  if (r.release_date) parts.push(`Дата релиза: ${r.release_date}`);
  if (r.explicit) parts.push("Explicit: да");
  return parts.join("\n");
}

// ─── TOOL SYSTEM PROMPTS ──────────────────────────────────────────────

const GROWTH_PLAN_SYSTEM = `Ты — персональный AI-стратег музыкального маркетинга сервиса Aurix.

ВАЖНО: Каждый ответ должен быть УНИКАЛЬНЫМ и ПЕРСОНАЛЬНЫМ для конкретного артиста.
Ты получишь полный профиль артиста, данные релиза, треклист и каталог. Используй ВСЮ эту информацию:
- Называй артиста по имени
- Учитывай его город (локальные площадки, сцена, СМИ)
- Учитывай его каталог и опыт (новичок vs опытный)
- Адаптируй стратегию под конкретный трек/альбом
- Если артист из Армении — упоминай армянские площадки, паблики, радиостанции
- Если из маленького города — учитывай локальный контекст

Ответ СТРОГО в JSON:
{
  "summary": "персональная стратегия для [имя артиста] с учётом его ситуации",
  "positioning": {"one_liner": "уникальный one-liner именно для этого трека/артиста", "angle": "конкретный маркетинговый угол", "audience": "конкретная ЦА с учётом жанра, города, языка"},
  "risks": ["конкретный риск для ЭТОГО артиста", ...],
  "levers": ["конкретный рычаг для ЭТОГО артиста", ...],
  "content_angles": ["угол 1 — привязанный к содержанию трека", ...],
  "quick_wins_48h": ["конкретное действие с названиями площадок/пабликов", ...],
  "weekly_focus": [{"week":1,"focus":"..."},{"week":2,"focus":"..."},{"week":3,"focus":"..."},{"week":4,"focus":"..."}],
  "days": [{"day":0,"title":"...","tasks":["конкретная задача, не шаблон"],"outputs":["конкретный результат"],"time_min":45}, ... до day 30],
  "checkpoints": [{"day":7,"kpi":["измеримый KPI"],"actions":["конкретное действие если KPI не достигнут"]},{"day":14,...},{"day":30,...}]
}

ПРАВИЛА:
- Давай КОНКРЕТНЫЕ названия пабликов, каналов, плейлистов (с учётом жанра и региона)
- Указывай реальные цифры KPI (не "увеличить стримы", а "достичь 5000 стримов за неделю")
- Каждый день плана должен быть УНИКАЛЬНЫМ — без повторов "выложить сторис"
- Задачи должны быть ДЕЙСТВИЯМИ, а не пожеланиями
- Пиши на русском`;

const BUDGET_PLAN_SYSTEM = `Ты — персональный AI-финансовый стратег Aurix для музыкантов.

ВАЖНО: Бюджет-план должен быть ПЕРСОНАЛЬНЫМ — учитывай артиста, его город, жанр, опыт.

Ты получишь профиль артиста, каталог релизов, треки. Используй эту информацию:
- Если артист из маленького города — рекомендуй бюджетные локальные каналы
- Если артист новичок (1-2 релиза) — акцент на органику и микробюджеты
- Если много релизов — можно советовать масштабирование
- Называй конкретные суммы за рекламу на конкретных площадках
- Суммы ОБЯЗАНЫ сходиться с общим бюджетом

Ответ СТРОГО в JSON:
{
  "summary": "персональная бюджетная стратегия для [артист]",
  "risks": ["конкретный риск слива денег для этого артиста", ...],
  "must_do": ["обязательное действие с конкретной суммой", ...],
  "anti_waste": ["на что конкретно НЕ тратить и почему", ...],
  "cheapest_strategy": "что делать если бюджет минимальный — конкретные шаги",
  "allocation": [{"category":"название статьи","amount":0,"percent":0,"notes":"почему именно столько","currency":"₽"}, ...],
  "dont_spend_on": ["конкретная позиция и почему она не сработает для этого артиста"],
  "must_spend_on": ["позиция и ROI-обоснование"],
  "next_steps": ["конкретный шаг с дедлайном"]
}
Пиши на русском.`;

const PACKAGING_SYSTEM = `Ты — персональный AI-копирайтер и маркетолог Aurix. Создаёшь УНИКАЛЬНУЮ упаковку для конкретного релиза.

ВАЖНО: Ты получишь профиль артиста, информацию о треке, его настроение и содержание.
Каждое описание, хук и CTA должно быть УНИКАЛЬНЫМ и привязанным к:
- Конкретному настроению и содержанию трека
- Имени артиста
- Его стилю и референсам
- Языку трека

НЕ ИСПОЛЬЗУЙ шаблонные фразы типа "новый трек от талантливого артиста" или "послушайте прямо сейчас".
Каждый хук должен вызывать ЭМОЦИЮ, связанную с содержанием трека.

Ответ СТРОГО в JSON:
{
  "title_variants": ["вариант с игрой слов, привязанный к содержанию", ... до 5],
  "description_platforms": {
    "yandex": "описание для Яндекс Музыки — тёплое, с нарративом, до 500 символов, на русском",
    "vk": "описание для VK — живое, неформальное, с эмодзи",
    "spotify": "Spotify description — English, professional, catchy",
    "apple": "Apple Music — English, editorial style, storytelling"
  },
  "storytelling": "история/нарратив: не пересказ трека, а атмосферная зарисовка для слушателя (3-5 предложений)",
  "hooks": ["хук — провокация или вопрос, привязанный к теме трека", ... 10-15],
  "cta_variants": ["призыв, привязанный к эмоции трека", ... 5-10]
}

ПРАВИЛА:
- Хуки — 5-10 слов, цепляющие, уникальные, без клише
- Описания для EN-платформ пиши на английском
- Storytelling — НЕ "артист выпустил новый трек", а атмосферная история
- Если трек explicit — отражай это в тоне`;

const CONTENT_PLAN_SYSTEM = `Ты — персональный AI-контент-стратег Aurix. Создаёшь 14-дневный контент-план для продвижения конкретного релиза.

ВАЖНО: План должен быть УНИКАЛЬНЫМ для конкретного артиста и трека.
Ты получишь профиль, данные трека и треклист. Используй ВСЁ:
- Называй артиста по имени в сценариях
- Привязывай контент к тексту/настроению трека
- Учитывай город артиста (локации для съёмок)
- Адаптируй формат под жанр (рэп = другой тип контента, чем инди)
- Каждый день УНИКАЛЬНЫЙ — никогда не повторяй "выложите тизер" два раза

Ответ СТРОГО в JSON:
{
  "strategy": "персональная стратегия для [артист] с акцентом на его сильные стороны (2-3 предложения)",
  "days": [
    {
      "day": 1,
      "format": "Reels / TikTok / YouTube Shorts / Stories / Carousel",
      "hook": "конкретный хук первых 2 секунд — привязанный к треку",
      "script": "детальный сценарий 3-5 предложений: что делает артист, что говорит, какие кадры, какая музыка на фоне",
      "shotlist": ["конкретный кадр с локацией: крупный план лица на фоне [город/место]", "средний план — артист идёт по [локация]", ...],
      "cta": "конкретный призыв, привязанный к содержанию видео"
    },
    ... до day 14
  ]
}

ПРАВИЛА:
- Сценарии детальные: не "снимите видео", а конкретный сценарий с действиями
- Шотлист конкретный: не "красивый кадр", а "крупный план рук на фортепиано при тёплом свете"
- Хуки разнообразные: вопросы, провокации, загадки, цитаты из текста, behind-the-scenes
- Миксуй форматы: Reels, TikTok, Shorts, Stories, Carousel, Live-фрагменты
- Пиши на русском`;

const PITCH_PACK_SYSTEM = `Ты — персональный AI-PR стратег Aurix. Создаёшь питч-пакет для плейлист-кураторов и журналистов.

ВАЖНО: Питч должен быть ПЕРСОНАЛЬНЫМ — написанным от лица конкретного артиста.
Ты получишь полный профиль, данные трека, каталог. Используй ВСЁ:
- Артист и его имя в каждом питче
- Его город, историю, биографию
- Количество и качество предыдущих релизов
- Жанровую нишу и отличие от конкурентов
- Конкретный трек и его содержание

Ответ СТРОГО в JSON:
{
  "short_pitch": "2-3 предложения на английском: [Artist Name] is... / His/Her new [single/album] «[Title]»... — для международных кураторов",
  "long_pitch": "5-8 предложений на русском: развёрнутый питч с историей артиста, уникальностью релиза, достижениями",
  "email_subjects": ["тема 1 — интригующая, с именем артиста и названием трека", ... до 5],
  "press_lines": ["цитата артиста о создании трека", "факт о процессе записи", ... 5-8 строк],
  "artist_bio": "профессиональная биография: кто, откуда, чем уникален, главные достижения, дискография (3-5 предложений)"
}

ПРАВИЛА:
- Short pitch на АНГЛИЙСКОМ — для международных кураторов, профессионально
- Long pitch на РУССКОМ — для СНГ-кураторов
- Email subjects — интригующие, с именем артиста
- Press lines — цитатного формата, как будто артист говорит о треке
- Bio — профессионально, в третьем лице
- НИКОГДА не пиши "талантливый молодой артист" — это клише`;

const RELEASE_DOCTOR_SYSTEM = `Ты — AURIX Release Doctor. Проводишь профессиональный preflight-аудит релиза перед отправкой.
Ответ СТРОГО в JSON:
{
  "summary": "краткий диагноз релиза",
  "quality_score": 0,
  "priority_fixes": [{"id":"...","title":"...","reason":"...","impact":"high|medium|low","fix":"..."}],
  "checklist": {
    "metadata": {"ok": true, "notes": ["..."]},
    "cover": {"ok": true, "notes": ["..."]},
    "tracks": {"ok": true, "notes": ["..."]},
    "promo_readiness": {"ok": true, "notes": ["..."]}
  },
  "next_actions_24h": ["...", "..."]
}
ПРАВИЛА:
- quality_score от 0 до 100
- давай конкретные исправления, без абстракций
- избегай повторов`;

const PROMO_AUTOPILOT_SYSTEM = `Ты — Smart Promo Autopilot от AURIX.
Создай персональный 7-дневный автоплан продвижения релиза.
Ответ СТРОГО в JSON:
{
  "summary":"...",
  "strategy":"...",
  "steps":[
    {"day":1,"title":"...","type":"content|ads|community|playlist","task":"...","kpi":"..."},
    {"day":2,"title":"...","type":"...","task":"...","kpi":"..."}
  ],
  "risks":["..."],
  "fallbacks":["..."]
}
ПРАВИЛА:
- 7 уникальных шагов
- каждый шаг должен быть выполнимым действием
- учитывай жанр/город/аудиторию`;

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

const ARTIST_BRIEF_SYSTEM = `Ты — AI Brief Composer AURIX.
Собери one-tap artist brief для работы с командой.
Ответ СТРОГО в JSON:
{
  "title":"Artist Brief",
  "artist_snapshot":{"name":"...","city":"...","genre":"..."},
  "release_snapshot":{"title":"...","stage":"...","focus":"..."},
  "positioning":"...",
  "dnk_highlights":["..."],
  "promo_focus":["..."],
  "tasks_7_days":["..."],
  "deliverables":["..."]
}`;

const WEEKLY_DIGEST_SYSTEM = `Ты — Weekly Executive Digest генератор AURIX.
Собери digest в стиле CEO summary.
Ответ СТРОГО в JSON:
{
  "title":"...",
  "summary":"...",
  "metrics":{"streams_delta":"...","revenue_delta":"...","aai":"..."},
  "wins":["..."],
  "risks":["..."],
  "priorities":["..."]
}`;

const CHAT_SYSTEM = `Ты AI-помощник Aurix. Помогаешь артистам оформить релиз, заполнить форму, подготовить описание, теги, стратегию релиза. Отвечай кратко и по делу. Не выдумывай факты. Юр/фин вопросы — аккуратно, без обещаний. Не запрашивай и не выдавай персональные данные.`;

const STUDIO_BASE_RULES = `Ты работаешь как senior release strategist для RU/CIS рынка.
Пиши строго на русском.
Никакой воды, мотивационного коучинга и абстракций.
Никаких обещаний гарантированного успеха.
Учитывай Яндекс Музыку, VK, TikTok, YouTube, short-form механику, бюджет и цикл релиза.
Если данных не хватает — не фантазируй, фиксируй пробелы в quality_meta.missing_inputs и assumptions.
Верни только JSON-объект без markdown, без комментариев и без дополнительного текста.`;

const TOOL_SYSTEM_PROMPTS: Record<StudioToolId, string> = {
  growth_plan: `${STUDIO_BASE_RULES}
Сконцентрируйся на стратегии роста релиза: pre-release, release week, post-release.
Дай конкретные действия, KPI, риски и ограничения.
Верни строго поля growth_plan контракта v2.`,
  budget_plan: `${STUDIO_BASE_RULES}
Сконцентрируйся на распределении бюджета, anti-waste правилах и fallback при урезании бюджета.
Суммы и проценты должны быть внутренне согласованы.
Верни строго поля budget_plan контракта v2.`,
  packaging: `${STUDIO_BASE_RULES}
Сконцентрируйся на позиционировании и упаковке релиза под платформы.
Верни строго поля packaging контракта v2.`,
  content_plan: `${STUDIO_BASE_RULES}
Сконцентрируйся на рабочем 14-дневном short-form плане.
Каждый день должен иметь hook/idea/cta/purpose.
Верни строго поля content_plan контракта v2.`,
  pitch_pack: `${STUDIO_BASE_RULES}
Сконцентрируйся на плейлист-питче, редакторском и блогерском угле, почтовом пакете.
Верни строго поля pitch_pack контракта v2.`,
};

const UNIFIED_RESPONSE_SCHEMA = {
  summary: "string",
  priorities: ["string | {title, why, steps?}"],
  first_actions: ["string?"],
  risks: ["string | {risk,signal,fix}?"],
  alt_scenario: "string?",
  hero: { title: "string?", subtitle: "string?" },
};

function normalizeToolId(raw: string | undefined | null): StudioToolId | null {
  const value = String(raw ?? "").trim().toLowerCase();
  switch (value) {
    case "growth_plan":
      return "growth_plan";
    case "budget_plan":
    case "budget-plan":
    case "budget_manager":
    case "budget-manager":
      return "budget_plan";
    case "release_packaging":
    case "release-packaging":
    case "packaging":
      return "packaging";
    case "playlist_pitch":
    case "playlist-pitch-pack":
    case "pitch_pack":
      return "pitch_pack";
    case "content_plan":
    case "content-plan":
      return "content_plan";
    default:
      return null;
  }
}

function mapToolIdToLegacyName(toolId: StudioToolId): LegacyToolName {
  switch (toolId) {
    case "growth_plan":
      return "growth-plan";
    case "budget_plan":
      return "budget-plan";
    case "packaging":
      return "release-packaging";
    case "content_plan":
      return "content-plan-14";
    case "pitch_pack":
      return "playlist-pitch-pack";
  }
}

type ContractToolId =
  | "growth_plan"
  | "budget_plan"
  | "packaging"
  | "content_plan"
  | "pitch_pack";

function toContractToolId(toolId: StudioToolId): ContractToolId {
  switch (toolId) {
    case "growth_plan":
      return "growth_plan";
    case "budget_plan":
      return "budget_plan";
    case "packaging":
      return "packaging";
    case "content_plan":
      return "content_plan";
    case "pitch_pack":
      return "pitch_pack";
  }
}

function buildStudioOkEnvelope(toolId: StudioToolId, version: string, requestId: string, data: Record<string, unknown>) {
  return {
    status: "ok" as const,
    tool_id: toContractToolId(toolId),
    version,
    data,
    meta: {
      request_id: requestId,
      generated_at: new Date().toISOString(),
      model: "gpt-4o-mini",
    },
  };
}

function buildStudioErrorEnvelope(toolId: StudioToolId, version: string, requestId: string, errorCode: string, message: string, status = 422) {
  return {
    statusCode: status,
    body: {
      status: "error" as const,
      tool_id: toContractToolId(toolId),
      version,
      code: errorCode,
      message,
      meta: {
        request_id: requestId,
      },
    },
  };
}

function requiredStringField(obj: Record<string, unknown>, key: string): boolean {
  return typeof obj[key] === "string" && String(obj[key]).trim().length > 0;
}

function requiredArrayField(obj: Record<string, unknown>, key: string): boolean {
  return Array.isArray(obj[key]) && (obj[key] as unknown[]).length > 0;
}

function requiredObjectField(obj: Record<string, unknown>, key: string): boolean {
  return typeof obj[key] === "object" && obj[key] !== null && !Array.isArray(obj[key]);
}

function validateStrictToolData(toolId: StudioToolId, data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  if (!requiredObjectField(data, "hero")) errors.push("hero_missing");
  const hero = toObject(data.hero);
  if (!requiredStringField(hero, "title")) errors.push("hero.title_missing");
  const hasMinItems = (key: string, count: number) => Array.isArray(data[key]) && (data[key] as unknown[]).length >= count;

  switch (toolId) {
    case "growth_plan":
      if (!requiredObjectField(data, "summary")) errors.push("summary_missing");
      if (!requiredStringField(toObject(data.summary), "goal")) errors.push("summary.goal_missing");
      if (!hasMinItems("priorities", 1)) errors.push("priorities_missing");
      if (!hasMinItems("first_actions", 1)) errors.push("first_actions_missing");
      if (!hasMinItems("risks", 1)) errors.push("risks_missing");
      break;
    case "budget_plan":
      if (!requiredObjectField(data, "summary")) errors.push("summary_missing");
      if (!requiredStringField(toObject(data.summary), "budget_total")) errors.push("summary.budget_total_missing");
      if (!hasMinItems("allocations", 1)) errors.push("allocations_missing");
      if (!hasMinItems("anti_waste", 1)) errors.push("anti_waste_missing");
      if (!hasMinItems("fallback_plan", 1)) errors.push("fallback_plan_missing");
      break;
    case "packaging":
      if (!requiredStringField(data, "positioning")) errors.push("positioning_missing");
      if (!hasMinItems("hooks", 1)) errors.push("hooks_missing");
      if (!hasMinItems("cta", 1)) errors.push("cta_missing");
      if (!hasMinItems("content_angles", 1)) errors.push("content_angles_missing");
      break;
    case "content_plan":
      if (!requiredStringField(data, "strategy")) errors.push("strategy_missing");
      if (!hasMinItems("content_days", 3)) errors.push("content_days_missing");
      if (!hasMinItems("hooks_bank", 3)) errors.push("hooks_bank_missing");
      if (!hasMinItems("cta_bank", 3)) errors.push("cta_bank_missing");
      break;
    case "pitch_pack":
      if (!requiredStringField(data, "pitch_summary")) errors.push("pitch_summary_missing");
      if (!hasMinItems("email_subjects", 2)) errors.push("email_subjects_missing");
      if (!hasMinItems("pitch_angles", 2)) errors.push("pitch_angles_missing");
      if (!requiredStringField(data, "artist_bio_short")) errors.push("artist_bio_short_missing");
      break;
  }
  return errors;
}

function extractToolDataPayload(parsed: unknown): Record<string, unknown> | null {
  if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
    const obj = parsed as Record<string, unknown>;
    if (obj.data && typeof obj.data === "object" && !Array.isArray(obj.data)) {
      return obj.data as Record<string, unknown>;
    }
    return obj;
  }
  return null;
}

const CHAT_API_VERSION = "2";

type StudioSchemaConfig = {
  systemPrompt: string;
  jsonSchema: Record<string, unknown>;
  validate: (data: Record<string, unknown>) => string[];
};

function validatePriorityItem(item: unknown): boolean {
  if (typeof item === "string") return item.trim().length > 0;
  if (!item || typeof item !== "object" || Array.isArray(item)) return false;
  const obj = item as Record<string, unknown>;
  const title = typeof obj.title === "string" && obj.title.trim().length > 0;
  const why = typeof obj.why === "string" && obj.why.trim().length > 0;
  if (!title || !why) return false;
  if (obj.steps === undefined) return true;
  if (!Array.isArray(obj.steps)) return false;
  return (obj.steps as unknown[]).every((s) => typeof s === "string");
}

function validateRiskItem(item: unknown): boolean {
  if (typeof item === "string") return item.trim().length > 0;
  if (!item || typeof item !== "object" || Array.isArray(item)) return false;
  const obj = item as Record<string, unknown>;
  return (
    typeof obj.risk === "string" &&
    typeof obj.signal === "string" &&
    typeof obj.fix === "string" &&
    obj.risk.trim().length > 0 &&
    obj.signal.trim().length > 0 &&
    obj.fix.trim().length > 0
  );
}

function studioValidators(_toolId: StudioToolId, data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  const allowedKeys = new Set(["summary", "priorities", "first_actions", "risks", "alt_scenario", "hero"]);
  const extraKeys = Object.keys(data).filter((k) => !allowedKeys.has(k));
  if (extraKeys.length > 0) {
    errors.push("extra_keys_not_allowed");
  }

  const summary = data.summary;
  if (typeof summary !== "string" || summary.trim().length === 0) {
    errors.push("summary_missing");
  }

  const priorities = data.priorities;
  if (!Array.isArray(priorities) || priorities.length < 1) {
    errors.push("priorities_missing");
  } else if (!(priorities as unknown[]).every(validatePriorityItem)) {
    errors.push("priorities_invalid_item");
  }

  if (data.first_actions !== undefined) {
    if (!Array.isArray(data.first_actions)) {
      errors.push("first_actions_invalid");
    } else if (!(data.first_actions as unknown[]).every((v) => typeof v === "string")) {
      errors.push("first_actions_invalid_item");
    }
  }

  if (data.risks !== undefined) {
    if (!Array.isArray(data.risks)) {
      errors.push("risks_invalid");
    } else if (!(data.risks as unknown[]).every(validateRiskItem)) {
      errors.push("risks_invalid_item");
    }
  }

  if (data.alt_scenario !== undefined && typeof data.alt_scenario !== "string") {
    errors.push("alt_scenario_invalid");
  }

  if (data.hero !== undefined) {
    if (!data.hero || typeof data.hero !== "object" || Array.isArray(data.hero)) {
      errors.push("hero_invalid");
    } else {
      const hero = data.hero as Record<string, unknown>;
      if (hero.title !== undefined && typeof hero.title !== "string") errors.push("hero.title_invalid");
      if (hero.subtitle !== undefined && typeof hero.subtitle !== "string") errors.push("hero.subtitle_invalid");
    }
  }

  return errors;
}

function buildStudioMinimalSchema(): Record<string, unknown> {
  return {
    type: "object",
    additionalProperties: false,
    required: ["summary", "priorities"],
    properties: {
      summary: { type: "string", minLength: 1 },
      priorities: {
        type: "array",
        minItems: 1,
        items: {
          anyOf: [
            { type: "string", minLength: 1 },
            {
              type: "object",
              additionalProperties: false,
              required: ["title", "why"],
              properties: {
                title: { type: "string", minLength: 1 },
                why: { type: "string", minLength: 1 },
                steps: {
                  type: "array",
                  items: { type: "string" },
                },
              },
            },
          ],
        },
      },
      first_actions: {
        type: "array",
        items: { type: "string" },
      },
      risks: {
        type: "array",
        items: {
          anyOf: [
            { type: "string", minLength: 1 },
            {
              type: "object",
              additionalProperties: false,
              required: ["risk", "signal", "fix"],
              properties: {
                risk: { type: "string", minLength: 1 },
                signal: { type: "string", minLength: 1 },
                fix: { type: "string", minLength: 1 },
              },
            },
          ],
        },
      },
      alt_scenario: { type: "string" },
      hero: {
        type: "object",
        additionalProperties: false,
        properties: {
          title: { type: "string" },
          subtitle: { type: "string" },
        },
      },
    },
  };
}

const STUDIO_JSON_ONLY_SYSTEM_PROMPT = `You are a structured JSON generator for AURIX Studio tools.
Return ONLY valid JSON, no markdown, no code fences.
Do not add keys outside schema.
If uncertain, use empty arrays/empty strings.
`;

const STUDIO_SCHEMA_CONFIGS: Record<StudioToolId, StudioSchemaConfig> = {
  growth_plan: {
    systemPrompt: `${STUDIO_JSON_ONLY_SYSTEM_PROMPT}Tool: growth_plan.`,
    jsonSchema: buildStudioMinimalSchema(),
    validate: (d) => studioValidators("growth_plan", d),
  },
  budget_plan: {
    systemPrompt: `${STUDIO_JSON_ONLY_SYSTEM_PROMPT}Tool: budget_plan.`,
    jsonSchema: buildStudioMinimalSchema(),
    validate: (d) => studioValidators("budget_plan", d),
  },
  packaging: {
    systemPrompt: `${STUDIO_JSON_ONLY_SYSTEM_PROMPT}Tool: packaging.`,
    jsonSchema: buildStudioMinimalSchema(),
    validate: (d) => studioValidators("packaging", d),
  },
  content_plan: {
    systemPrompt: `${STUDIO_JSON_ONLY_SYSTEM_PROMPT}Tool: content_plan.`,
    jsonSchema: buildStudioMinimalSchema(),
    validate: (d) => studioValidators("content_plan", d),
  },
  pitch_pack: {
    systemPrompt: `${STUDIO_JSON_ONLY_SYSTEM_PROMPT}Tool: pitch_pack.`,
    jsonSchema: buildStudioMinimalSchema(),
    validate: (d) => studioValidators("pitch_pack", d),
  },
};

async function runStructuredJsonCompletion(
  env: Env,
  systemPrompt: string,
  userPrompt: string,
  temperature = 0.2,
): Promise<{ content: string; model: string }> {
  const apiKey = (env.AI_API_KEY ?? env.OPENAI_API_KEY ?? "").trim();
  if (!apiKey) throw new Error("Missing AI API key");
  const aiBaseUrl = (env.AI_BASE_URL ?? "https://api.openai.com").replace(/\/+$/, "");
  const res = await fetch(`${aiBaseUrl}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature,
      max_tokens: 2200,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      response_format: { type: "json_object" },
    }),
  });

  const rawBody = await res.text();
  let parsed: any = null;
  try {
    parsed = JSON.parse(rawBody);
  } catch {
    parsed = null;
  }
  if (!res.ok) {
    throw new Error(parsed?.error?.message ?? `OpenAI error ${res.status}`);
  }

  const content = String(parsed?.choices?.[0]?.message?.content ?? "").trim();
  const model = String(parsed?.model ?? "gpt-4o-mini");
  return { content, model };
}

function validateMinimal(data: Record<string, unknown>): boolean {
  return typeof data.summary === "string" && data.summary.toString().trim().length > 0 && Array.isArray(data.priorities);
}

function sanitizeStudioData(data: Record<string, unknown>): Record<string, unknown> {
  const summary = typeof data.summary === "string" ? data.summary.trim() : "";
  const priorities = Array.isArray(data.priorities)
    ? data.priorities
        .map((v) => {
          if (typeof v === "string") return v.trim();
          if (v && typeof v === "object" && !Array.isArray(v)) {
            const obj = v as Record<string, unknown>;
            const out: Record<string, unknown> = {
              title: String(obj.title ?? "").trim(),
              why: String(obj.why ?? "").trim(),
            };
            if (Array.isArray(obj.steps)) {
              out.steps = (obj.steps as unknown[]).map((s) => String(s ?? "").trim()).filter((s) => s.length > 0);
            }
            return out;
          }
          return "";
        })
        .filter((v) => (typeof v === "string" ? v.length > 0 : true))
    : [];

  return {
    summary,
    priorities,
  };
}

function toObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === "object" && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function adaptUnifiedStudioRequest(toolName: string, body: any): UnifiedStudioRequest {
  const candidate = toObject(body?.inputs?.tool_id ? body.inputs : body);
  const toolId = normalizeToolId(String(candidate.tool_id ?? "")) ?? normalizeToolId(toolName) ?? "growth_plan";

  const release = toObject(body?.release);
  const profile = toObject(body?.profile);
  const tracks = Array.isArray(body?.tracks) ? body.tracks : [];
  const catalog = Array.isArray(body?.catalog) ? body.catalog : [];

  const context = toObject(candidate.context);
  const mergedContext = {
    ...context,
    ...(Object.keys(context).length === 0
      ? {
          release_id: release.id ?? null,
          title: release.title ?? "",
          artist: release.artist ?? profile.artist_name ?? "",
          release_type: release.release_type ?? "single",
          release_date: release.release_date ?? null,
          genre: release.genre ?? "",
          language: release.language ?? "",
          explicit: Boolean(release.explicit ?? false),
          existing_metadata: {
            upc: release.upc ?? null,
            label: release.label ?? null,
          },
          tracks,
          catalog,
          profile,
        }
      : {}),
  };

  const answers = toObject(candidate.answers);
  const legacyInputs = toObject(body?.inputs);
  const mergedAnswers = Object.keys(answers).length > 0 ? answers : legacyInputs;

  return {
    tool_id: toolId,
    context: mergedContext,
    answers: mergedAnswers,
    ai_summary: String(candidate.ai_summary ?? ""),
    locale: String(candidate.locale ?? "ru"),
    output_format: "json",
    output_version: "v2",
  };
}

function buildToolSpecificSchemaNote(toolId: StudioToolId): string {
  return `required: summary:string, priorities:array( string OR {title,why,steps?} )
optional: first_actions:string[], risks:(string OR {risk,signal,fix})[], alt_scenario:string, hero:{title?,subtitle?}`;
}

function buildStudioRepairExample(toolId: StudioToolId): string {
  const titleByTool: Record<StudioToolId, string> = {
    growth_plan: "Growth Plan",
    budget_plan: "Budget Plan",
    packaging: "Packaging Plan",
    content_plan: "Content Plan",
    pitch_pack: "Pitch Pack",
  };
  return JSON.stringify(
    {
      hero: { title: titleByTool[toolId], subtitle: "v2" },
      summary: "Короткий структурированный вывод в 1-2 абзацах.",
      priorities: [
        {
          title: "Сфокусировать цель",
          why: "Без фокуса падает эффективность",
          steps: ["Определи KPI", "Сверь каналы", "Запусти измерение"],
        },
      ],
      first_actions: ["Подготовить бриф", "Собрать материалы"],
      risks: [{ risk: "Слабый оффер", signal: "Низкий CTR", fix: "Обновить хук" }],
      alt_scenario: "",
    },
    null,
    2,
  );
}

function buildStudioUserPrompt(data: UnifiedStudioRequest): string {
  return [
    "Входные данные в JSON:",
    JSON.stringify(
      {
        tool_id: data.tool_id,
        context: data.context,
        answers: data.answers,
        ai_summary: data.ai_summary,
        locale: data.locale,
        output_format: data.output_format,
        output_version: data.output_version,
      },
      null,
      2,
    ),
    "",
    "Целевой формат ответа:",
    JSON.stringify(UNIFIED_RESPONSE_SCHEMA, null, 2),
    "",
    "Tool-specific требования:",
    buildToolSpecificSchemaNote(data.tool_id),
    "",
    "Ограничения структуры:",
    "- Верни только JSON object, без markdown и текста вокруг",
    "- Не возвращай raw_text и не оборачивай JSON в строку",
    "- Схема должна строго соответствовать tool-specific контракту выше",
    "- Если не уверен, используй пустые массивы/пустые строки",
  ].join("\n");
}

function parseJsonSafe(raw: unknown): Record<string, unknown> | null {
  if (raw && typeof raw === "object" && !Array.isArray(raw)) return raw as Record<string, unknown>;
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  try {
    const parsed = JSON.parse(trimmed);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed as Record<string, unknown>;
  } catch (_) {}
  return repairJsonLikeText(trimmed);
}

function repairJsonLikeText(raw: string): Record<string, unknown> | null {
  const normalized = raw
    .replaceAll("```json", "")
    .replaceAll("```", "")
    .replaceAll("“", "\"")
    .replaceAll("”", "\"")
    .replaceAll("’", "'");

  const start = normalized.indexOf("{");
  const end = normalized.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  const candidate = normalized.slice(start, end + 1).trim();
  try {
    const parsed = JSON.parse(candidate);
    if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) return parsed as Record<string, unknown>;
  } catch (_) {}
  return null;
}

function arrStrings(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v ?? "").trim()).filter((v) => v.length > 0);
}

function textOr(value: unknown, fallback: string): string {
  const out = String(value ?? "").trim();
  return out.length > 0 ? out : fallback;
}

function pickListLength<T>(arr: T[], minLen: number, maxLen: number, factory: (idx: number) => T): T[] {
  const out = [...arr];
  while (out.length < minLen) out.push(factory(out.length));
  return out.slice(0, maxLen);
}

function buildFallbackResponse(toolId: StudioToolId, requestData: UnifiedStudioRequest): Record<string, unknown> {
  const title = String(requestData.context.title ?? "Релиз");
  const goal = String((requestData.answers.releaseGoal as string | undefined) ?? (requestData.answers.goal as string | undefined) ?? "рост релиза");
  const baseToolSpecific: Record<string, unknown> = {};
  const baseAssets: Record<string, unknown> = {};

  if (toolId === "growth_plan") {
    baseToolSpecific.timeline_30_days = [
      { phase: "pre-release", goal: "Подготовить запуск", actions: ["Собрать контент-пул", "Выделить ключевые каналы"], kpi: "Готовность 100%", risk: "Низкий темп" },
      { phase: "release week", goal: "Максимальный фокус", actions: ["Запуск по priority-платформам", "Контроль KPI ежедневно"], kpi: "Рост охвата", risk: "Распыление" },
      { phase: "post-release", goal: "Удержание инерции", actions: ["Ретаргет лучших форматов", "Усилить органику"], kpi: "Стабильный retention", risk: "Потеря фокуса" },
    ];
    baseToolSpecific.platform_focus = [{ platform: "yandex", why: "релевантно RU/CIS", action: "добавить приоритетный трафик" }];
    baseToolSpecific.growth_levers = [{ lever: "short-form hooks", expected_effect: "рост досмотров", caution: "не уходить в кликбейт" }];
    baseAssets.positioning_angle = `Сфокусировать "${title}" на понятном эмоциональном угле`;
    baseAssets.promo_hooks = ["Ключевая цитата из трека", "Контрастная эмоция и визуал"];
    baseAssets.short_cta = ["Сохрани трек", "Добавь в плейлист"];
    baseAssets.launch_focus = "Первые 72 часа";
  } else if (toolId === "budget_plan") {
    baseToolSpecific.budget_split = [{ bucket: "performance", percent: 40, amount: 0, why: "управляемый рост" }];
    baseToolSpecific.anti_waste_rules = ["Не масштабировать каналы без метрик", "Не покупать ботов и фанпейджи"];
    baseToolSpecific.fallback_budget_split = [{ bucket: "organic", percent: 70, amount: 0, why: "если бюджет урезали" }];
    baseToolSpecific.spend_priority_order = ["Контент", "Посевы", "Реклама"];
    baseAssets.team_recommendation = ["1 контент-мейкер + 1 монтажер по необходимости"];
    baseAssets.what_not_to_buy = ["Накрутка", "Серые плейлист-пакеты"];
    baseAssets.min_viable_budget_note = "Минимально жизнеспособный запуск возможен при фокусе на органике.";
  } else if (toolId === "packaging") {
    baseToolSpecific.packaging_core = "Четкий эмоциональный фокус релиза";
    baseToolSpecific.audience_angle = "Слушатель, который узнает себя в истории";
    baseToolSpecific.visual_direction = "Контрастный, цельный mood";
    baseToolSpecific.storytelling_frame = "Путь: напряжение -> кульминация -> выход";
    baseAssets.release_description = "Короткое описание релиза под платформы.";
    baseAssets.short_description = "Ядро смысла релиза в 1-2 фразах.";
    baseAssets.hooks = ["Контрастная фраза", "Личная цитата"];
    baseAssets.call_to_actions = ["Сохрани и поделись", "Добавь в плейлист"];
    baseAssets.captions = ["Мини-подводка к релизу"];
    baseAssets.content_angles = ["История создания", "Смысл текста"];
  } else if (toolId === "content_plan") {
    baseToolSpecific["14_day_plan"] = Array.from({ length: 14 }).map((_, idx) => ({
      day: idx + 1,
      format: "reel",
      hook: `Hook ${idx + 1}`,
      idea: `Идея ${idx + 1}`,
      cta: "Сохрани трек",
      purpose: "Рост вовлечения",
    }));
    baseToolSpecific.content_pillars = ["Hook-first", "Story", "Proof"];
    baseToolSpecific.posting_logic = "Ежедневный короткий цикл с анализом каждые 3 дня.";
    baseAssets.hooks = ["2-секундный заход", "Цитата из трека"];
    baseAssets.reel_ideas = ["Behind the scenes", "Текст+визуал"];
    baseAssets.cta_bank = ["Сохрани", "Поделись"];
    baseAssets.story_prompts = ["Почему этот релиз важен", "Какая эмоция в треке"];
  } else if (toolId === "pitch_pack") {
    baseToolSpecific.target_playlist_types = ["editorial", "algorithmic", "genre"];
    baseToolSpecific.pitch_strategy = ["Короткий factual pitch", "Поддержка цифрами"];
    baseToolSpecific.weak_points = ["Недостаток подтвержденных метрик"];
    baseAssets.pitch_email = "Короткое письмо редактору с фокусом на релевантность.";
    baseAssets.short_pitch = "Короткий питч в 2-3 предложения.";
    baseAssets.press_line = "Линия для пресс-материала.";
    baseAssets.artist_bio = "Краткая био артиста.";
    baseAssets.track_blurb = "Короткое описание трека.";
    baseAssets.subject_lines = ["New release pitch", "Track for your playlist"];
  }

  return {
    hero: {
      title: `${title}: структурный AI-отчет`,
      subtitle: "Ответ собран в safe mode",
      one_liner: `Фокус: ${goal}`,
    },
    summary: {
      what_changed: "Сформирован безопасный структурированный ответ вместо невалидного сырого результата модели.",
      why_it_matters: "Фронтенд получает стабильный JSON контракт без разрывов UX.",
      metrics: ["Валидность JSON", "Стабильность структуры", "Готовность к action"],
    },
    priorities: [
      { title: "Сфокусировать цель", why: "Без четкой цели теряется эффективность", effort: "medium", impact: "high", steps: ["Определить KPI", "Согласовать приоритеты", "Запустить цикл проверки"] },
      { title: "Усилить ключевые каналы", why: "Концентрация дает больше эффекта", effort: "medium", impact: "high", steps: ["Выбрать 2-3 платформы", "Подготовить контент", "Измерить отклик"] },
      { title: "Управлять рисками", why: "Снижает вероятность слива ресурсов", effort: "low", impact: "medium", steps: ["Определить сигналы риска", "Подготовить fallback", "Проверять еженедельно"] },
    ],
    first_actions: [
      { title: "Быстрый аудит входных данных", time_estimate_min: 30, steps: ["Проверить контекст", "Уточнить пробелы", "Обновить brief"] },
      { title: "Запуск минимального плана", time_estimate_min: 45, steps: ["Выбрать 1 гипотезу", "Подготовить материалы", "Запустить публикацию"] },
      { title: "Петля обратной связи", time_estimate_min: 40, steps: ["Собрать метрики", "Сравнить с KPI", "Скорректировать курс"] },
    ],
    risks: [
      { risk: "Недостаток данных", signal: "Неполный контекст и размытые ответы", fix: "Заполнить missing_inputs и обновить генерацию" },
      { risk: "Распыление ресурсов", signal: "Слишком много параллельных задач", fix: "Сократить до топ-3 приоритетов" },
      { risk: "Нестабильный execution", signal: "Срывы сроков по шагам", fix: "Фиксировать дедлайны и контрольные точки" },
    ],
    alt_scenario: {
      when_to_use: "При резком ограничении бюджета/сроков",
      plan_short: ["Сфокусироваться на 1-2 каналах", "Перевести акцент в органику", "Оставить только шаги с лучшим ROI"],
    },
    tool_specific: baseToolSpecific,
    assets: baseAssets,
    quality_meta: {
      confidence_0_1: 0.55,
      missing_inputs: ["partial_context"],
      assumptions: ["Ответ собран fallback-пайплайном Worker"],
    },
  };
}

function validateStudioAiResponse(toolId: StudioToolId, data: Record<string, unknown>): string[] {
  const errors: string[] = [];
  const priorities = Array.isArray(data.priorities) ? data.priorities : [];
  const firstActions = Array.isArray(data.first_actions) ? data.first_actions : [];
  const risks = Array.isArray(data.risks) ? data.risks : [];
  const metrics = arrStrings(toObject(data.summary).metrics);

  if (!toObject(data.hero).title) errors.push("hero.title_missing");
  if (priorities.length !== 3) errors.push("priorities_count_invalid");
  if (firstActions.length !== 3) errors.push("first_actions_count_invalid");
  if (risks.length < 3 || risks.length > 6) errors.push("risks_count_invalid");
  if (metrics.length < 3 || metrics.length > 5) errors.push("metrics_count_invalid");
  if (!toObject(data).tool_specific || typeof data.tool_specific !== "object") errors.push("tool_specific_invalid");
  if (!toObject(data).assets || typeof data.assets !== "object") errors.push("assets_invalid");
  if (!toObject(data).quality_meta || typeof data.quality_meta !== "object") errors.push("quality_meta_invalid");

  if (toolId === "growth_plan" && !Array.isArray(toObject(data.tool_specific).timeline_30_days)) errors.push("growth.timeline_30_days_missing");
  if (toolId === "budget_plan" && !Array.isArray(toObject(data.tool_specific).budget_split)) errors.push("budget.budget_split_missing");
  if (toolId === "packaging" && !toObject(data.tool_specific).packaging_core) errors.push("packaging.packaging_core_missing");
  if (toolId === "content_plan" && !Array.isArray(toObject(data.tool_specific)["14_day_plan"])) errors.push("content.14_day_plan_missing");
  if (toolId === "pitch_pack" && !Array.isArray(toObject(data.tool_specific).pitch_strategy)) errors.push("pitch.pitch_strategy_missing");

  return errors;
}

function clampAndSanitizeResponse(toolId: StudioToolId, data: Record<string, unknown>): Record<string, unknown> {
  const fallback = buildFallbackResponse(toolId, {
    tool_id: toolId,
    context: {},
    answers: {},
    ai_summary: "",
    locale: "ru",
    output_format: "json",
    output_version: "v1",
  });

  const heroIn = toObject(data.hero);
  const summaryIn = toObject(data.summary);
  const qualityIn = toObject(data.quality_meta);
  const toolSpecificIn = toObject(data.tool_specific);
  const assetsIn = toObject(data.assets);

  const prioritiesIn = Array.isArray(data.priorities) ? data.priorities : [];
  const priorities = pickListLength(
    prioritiesIn
      .map((p) => toObject(p))
      .filter((p) => Object.keys(p).length > 0)
      .map((p) => ({
        title: textOr(p.title, "Приоритет"),
        why: textOr(p.why, "Влияет на итог релиза"),
        effort: ["low", "medium", "high"].includes(String(p.effort)) ? String(p.effort) : "medium",
        impact: ["low", "medium", "high"].includes(String(p.impact)) ? String(p.impact) : "medium",
        steps: pickListLength(arrStrings(p.steps), 3, 7, (idx) => `Шаг ${idx + 1}`),
      })),
    3,
    3,
    (idx) => toObject((fallback.priorities as unknown[])[idx]) as unknown as { title: string; why: string; effort: string; impact: string; steps: string[] },
  );

  const firstActionsIn = Array.isArray(data.first_actions) ? data.first_actions : [];
  const firstActions = pickListLength(
    firstActionsIn
      .map((a) => toObject(a))
      .filter((a) => Object.keys(a).length > 0)
      .map((a) => ({
        title: textOr(a.title, "Действие"),
        time_estimate_min: Number.isFinite(Number(a.time_estimate_min)) ? Math.max(5, Math.min(480, Math.round(Number(a.time_estimate_min)))) : 45,
        steps: pickListLength(arrStrings(a.steps), 3, 5, (idx) => `Шаг ${idx + 1}`),
      })),
    3,
    3,
    (idx) => toObject((fallback.first_actions as unknown[])[idx]) as unknown as { title: string; time_estimate_min: number; steps: string[] },
  );

  const risksIn = Array.isArray(data.risks) ? data.risks : [];
  const risks = pickListLength(
    risksIn
      .map((r) => toObject(r))
      .filter((r) => Object.keys(r).length > 0)
      .map((r) => ({
        risk: textOr(r.risk, "Риск"),
        signal: textOr(r.signal, "Сигнал"),
        fix: textOr(r.fix, "Корректирующее действие"),
      })),
    3,
    6,
    (idx) => toObject((fallback.risks as unknown[])[Math.min(idx, 2)]) as unknown as { risk: string; signal: string; fix: string },
  );

  const metrics = pickListLength(arrStrings(summaryIn.metrics), 3, 5, (idx) => ["Охват", "Вовлечение", "Конверсия", "Удержание", "ROI"][idx] ?? `Metric ${idx + 1}`);

  const confidenceRaw = Number(qualityIn.confidence_0_1);
  const confidence = Number.isFinite(confidenceRaw) ? Math.max(0, Math.min(1, confidenceRaw)) : 0.65;

  const out: Record<string, unknown> = {
    hero: {
      title: textOr(heroIn.title, textOr(toObject(fallback.hero).title, "Studio AI отчет")),
      subtitle: textOr(heroIn.subtitle, textOr(toObject(fallback.hero).subtitle, "Структурированный JSON результат")),
      one_liner: textOr(heroIn.one_liner, textOr(toObject(fallback.hero).one_liner, "Фокус на конкретных действиях и рисках")),
    },
    summary: {
      what_changed: textOr(summaryIn.what_changed, textOr(toObject(fallback.summary).what_changed, "Собран структурный план действий.")),
      why_it_matters: textOr(summaryIn.why_it_matters, textOr(toObject(fallback.summary).why_it_matters, "Структурность снижает хаос и ускоряет execution.")),
      metrics,
    },
    priorities,
    first_actions: firstActions,
    risks,
    alt_scenario: {
      when_to_use: textOr(toObject(data.alt_scenario).when_to_use, textOr(toObject(fallback.alt_scenario).when_to_use, "Когда нужно упростить запуск")),
      plan_short: pickListLength(arrStrings(toObject(data.alt_scenario).plan_short), 3, 5, (idx) => (arrStrings(toObject(fallback.alt_scenario).plan_short)[idx] ?? `Fallback шаг ${idx + 1}`)),
    },
    tool_specific: Object.keys(toolSpecificIn).length > 0 ? toolSpecificIn : toObject(fallback.tool_specific),
    assets: Object.keys(assetsIn).length > 0 ? assetsIn : toObject(fallback.assets),
    quality_meta: {
      confidence_0_1: confidence,
      missing_inputs: arrStrings(qualityIn.missing_inputs),
      assumptions: arrStrings(qualityIn.assumptions),
    },
  };

  const validationErrors = validateStudioAiResponse(toolId, out);
  if (validationErrors.length > 0) {
    const q = toObject(out.quality_meta);
    out.quality_meta = {
      ...q,
      assumptions: [...arrStrings(q.assumptions), `Worker clamp fixed ${validationErrors.length} validation issue(s)`],
    };
  }
  return out;
}

// ─── ROUTER ───────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const method = request.method;
    if (method === "OPTIONS") {
      return new Response(null, { status: 204, headers: buildCorsHeaders(request, env) });
    }

    const url = new URL(request.url);
    const path = url.pathname;
    if (method === "GET" && path === "/health") {
      return jsonRespWithCors(request, env, { ok: true, version: CHAT_API_VERSION });
    }
    if (method === "GET" && path === "/debug/env") {
      const envName = String(env.ENV ?? "prod").toLowerCase();
      if (envName !== "dev") {
        const key = request.headers.get("X-AURIX-INTERNAL-KEY") || "";
        const expected = env.AURIX_INTERNAL_KEY || "";
        if (!key || !expected || key !== expected) {
          return new Response("Not Found", { status: 404 });
        }
      }
      return jsonRespWithCors(request, env, {
        ok: true,
        hasOpenAiKey: Boolean((env.AI_API_KEY ?? env.OPENAI_API_KEY ?? "").trim().length > 0),
        hasAllowedOrigins: Boolean((env.ALLOWED_ORIGINS ?? "").trim().length > 0),
        env: envName,
      });
    }
    // Backward compatibility: accept both /dnk-tests/* and /api/dnk-tests/*
    const dnkTestsPath = path.startsWith("/api/dnk-tests/")
      ? path.replace("/api", "")
      : path;

    // ── AAI public endpoints ──
    if (method === "GET" && path.startsWith("/s/")) {
      const releaseId = path.replace("/s/", "").trim();
      if (!releaseId) return jsonResp({ error: "release id required" }, 400);
      return handleSmartLink(request, env as unknown as AaiEnv, releaseId);
    }
    if (method === "GET" && path === "/aai/top10") {
      return handleTop10(request, env as unknown as AaiEnv);
    }
    if (method === "GET" && path === "/aai/top") {
      return handleTopPage(request, env as unknown as AaiEnv);
    }
    if (path === "/aai/visit") {
      return handleVisit(request, env as unknown as AaiEnv);
    }
    if (path === "/aai/click") {
      return handleClick(request, env as unknown as AaiEnv);
    }

    // ── DNK endpoints (GET for polling, POST for mutations) ──
    if (path.startsWith("/dnk/")) {
      const dnkEnv: DnkEnv = env as unknown as DnkEnv;
      if (method === "GET" && path === "/dnk/result") return handleDnkGetResult(request, dnkEnv);
      if (method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);
      if (path === "/dnk/start") return handleDnkStart(request, dnkEnv);
      if (path === "/dnk/answer") return handleDnkAnswer(request, dnkEnv);
      if (path === "/dnk/finish") return handleDnkFinish(request, dnkEnv, _ctx);
      return jsonResp({ error: "Unknown DNK endpoint" }, 404);
    }

    // ── DNK Tests endpoints (6 standalone modules) ──
    if (dnkTestsPath.startsWith("/dnk-tests/")) {
      const testsEnv: DnkTestsEnv = env as unknown as DnkTestsEnv;
      if (method === "OPTIONS") return handleDnkTestsOptions();
      if (method === "GET" && dnkTestsPath === "/dnk-tests/catalog") return handleDnkTestsCatalog(request, testsEnv);
      if (method === "GET" && dnkTestsPath === "/dnk-tests/progress") return handleDnkTestsProgress(request, testsEnv);
      if (method === "GET" && dnkTestsPath === "/dnk-tests/result") return handleDnkTestsGetResult(request, testsEnv);
      if (method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);
      if (dnkTestsPath === "/dnk-tests/start") return handleDnkTestsStart(request, testsEnv);
      if (dnkTestsPath === "/dnk-tests/answer") return handleDnkTestsAnswer(request, testsEnv);
      if (dnkTestsPath === "/dnk-tests/finish") return handleDnkTestsFinish(request, testsEnv);
      return jsonResp({ error: "Unknown DNK tests endpoint" }, 404);
    }

    if (method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);

    if (path === "/api/ai/chat") return handleChat(request, env);
    if (path === "/api/ai/cover") return handleCover(request, env);

    if (path.startsWith("/v1/tools/")) {
      const key = request.headers.get("X-AURIX-INTERNAL-KEY") || "";
      const encoder = new TextEncoder();
      const keyBytes = encoder.encode(key);
      const expectedBytes = encoder.encode(env.AURIX_INTERNAL_KEY || "");
      if (keyBytes.byteLength !== expectedBytes.byteLength ||
          !crypto.subtle.timingSafeEqual(keyBytes, expectedBytes)) {
        return jsonResp({ error: "Forbidden" }, 403);
      }
      return handleTool(path, request, env);
    }

    return jsonResp({ error: "Not found" }, 404);
  },
  async scheduled(_event: ScheduledEvent, _env: Env, _ctx: ExecutionContext): Promise<void> {},
};

// ─── COVER HANDLER ─────────────────────────────────────────────────────

type CoverReq = {
  prompt: string;
  strict_prompt?: boolean;
  negative_prompt?: string;
  follow_prompt_strength?: number;
  safe_zone_guide?: boolean;
  style_preset?: string;
  color_profile?: string;
  size?: "1024x1024" | "1536x1536" | "auto";
  quality?: "high" | "medium";
  output_format?: "png";
  background?: "opaque" | "transparent";
  allow_text?: boolean;
  releaseId?: string | null;
  userId?: string | null;
};

async function handleCover(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  if (!checkRateLimit(ip)) {
    return jsonResp({ error: "Rate limit exceeded. Try again in a minute." }, 429);
  }

  if (!env.OPENAI_API_KEY) return jsonResp({ error: "Server configuration error" }, 500);

  let body: CoverReq;
  try {
    body = (await request.json()) as CoverReq;
  } catch {
    return jsonResp({ error: "Invalid JSON" }, 400);
  }

  const userPrompt = (body.prompt ?? "").toString().trim();
  if (!userPrompt) return jsonResp({ error: "Empty prompt" }, 400);

  const quality = body.quality === "medium" ? "medium" : "high";
  const requestedSize = body.size ?? "1024x1024";
  const background = body.background === "transparent" ? "transparent" : "opaque";
  const allowText = body.allow_text === true;
  const strictPrompt = body.strict_prompt !== false;
  const safeZoneGuide = body.safe_zone_guide !== false;
  const stylePreset = (body.style_preset ?? "").toString().trim();
  const colorProfile = (body.color_profile ?? "").toString().trim();
  const negativePrompt = (body.negative_prompt ?? "").toString().trim();
  const rawStrength = Number(body.follow_prompt_strength);
  const followPromptStrength = Number.isFinite(rawStrength)
    ? Math.max(0.5, Math.min(1.0, rawStrength))
    : 0.9;
  const strictnessRule =
    followPromptStrength >= 0.95
      ? "The user prompt has maximum priority. Preserve requested objects, scene, mood and style exactly."
      : followPromptStrength >= 0.8
        ? "Prioritize the user prompt strongly. Keep requested elements and mood faithful."
        : "Balance user prompt with visual coherence; still keep key requested elements.";

  const prompt = strictPrompt
    ? [
        "You are generating a music album cover.",
        "Follow the user's prompt EXACTLY as the primary creative direction.",
        "Output requirements: single square cover, 1:1 aspect ratio, centered composition, streaming-ready.",
        strictnessRule,
        safeZoneGuide
          ? "Important elements must stay in the center safe-zone (about central 80% area) to prevent crop issues in platform previews."
          : "Use full-canvas composition as requested.",
        stylePreset ? `Preferred style preset: ${stylePreset}.` : "Style should come from user prompt.",
        colorProfile ? `Preferred color profile: ${colorProfile}.` : "Color profile should come from user prompt.",
        negativePrompt
          ? `Avoid these elements/artifacts: ${negativePrompt}.`
          : "Do not add unwanted extra objects or concepts not asked by the user.",
        userPrompt,
        allowText
          ? "If the user asks for text, render clean readable typography."
          : "Do not include readable text unless user explicitly requests it.",
      ].join("\n")
    : [
        "Create a square album cover (1:1).",
        "Follow the user's request as the primary instruction.",
        "Keep result professional and production-ready.",
        userPrompt,
        allowText
          ? "If text is requested, keep it intentional and clean."
          : "Avoid readable text and typography unless explicitly requested.",
      ].join("\n");

  const OPENAI_IMAGE_TIMEOUT_MS = 170_000;

  async function call(size: string, q: "high" | "medium") {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), OPENAI_IMAGE_TIMEOUT_MS);
    try {
      const aiImageBase = (env.AI_BASE_URL || "https://api.openai.com").replace(/\/+$/, "");
      const res = await fetch(`${aiImageBase}/v1/images/generations`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${env.AI_API_KEY || env.OPENAI_API_KEY}`,
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: "gpt-image-1",
          prompt,
          size,
          quality: q,
          output_format: "png",
          background,
        }),
      });
      const data = (await res.json()) as any;
      if (!res.ok) throw new Error(data?.error?.message ?? "OpenAI error");
      const item = data?.data?.[0] ?? {};
      const b64 = (item?.b64_json ?? item?.b64_png ?? item?.b64) as string | undefined;
      if (!b64) throw new Error("Empty image result");
      return b64;
    } finally {
      clearTimeout(timer);
    }
  }

  let sizeToUse = requestedSize === "auto" ? "1024x1024" : requestedSize;
  let qualityToUse: "high" | "medium" = quality;
  try {
    const b64 = await call(sizeToUse, qualityToUse);
    return jsonResp({
      ok: true,
      b64_png: b64,
      meta: {
        size: sizeToUse,
        quality: qualityToUse,
        model: "gpt-image-1",
        follow_prompt_strength: followPromptStrength,
        safe_zone_guide: safeZoneGuide,
      },
    });
  } catch (e: any) {
    // Fallback: if 1536 fails (timeout/model limits), retry with 1024.
    if (sizeToUse === "1536x1536") {
      try {
        sizeToUse = "1024x1024";
        const b64 = await call(sizeToUse, qualityToUse);
        return jsonResp({
          ok: true,
          b64_png: b64,
          meta: {
            size: sizeToUse,
            quality: qualityToUse,
            model: "gpt-image-1",
            fallback: true,
            follow_prompt_strength: followPromptStrength,
            safe_zone_guide: safeZoneGuide,
          },
        });
      } catch (e2: any) {
        return jsonResp({ ok: false, error: e2?.message ?? "Service unavailable" }, 502);
      }
    }
    // Retry once for transient timeout/network errors.
    const msg = String(e?.message ?? "");
    if (msg.toLowerCase().includes("timeout") || msg.toLowerCase().includes("abort")) {
      try {
        const b64 = await call(sizeToUse, qualityToUse);
        return jsonResp({
          ok: true,
          b64_png: b64,
          meta: {
            size: sizeToUse,
            quality: qualityToUse,
            model: "gpt-image-1",
            retry: true,
            follow_prompt_strength: followPromptStrength,
            safe_zone_guide: safeZoneGuide,
          },
        });
      } catch (e2: any) {
        // Final degradation: medium quality with 1024 for best reliability.
        try {
          sizeToUse = "1024x1024";
          qualityToUse = "medium";
          const b64 = await call(sizeToUse, qualityToUse);
          return jsonResp({
            ok: true,
            b64_png: b64,
            meta: {
              size: sizeToUse,
              quality: qualityToUse,
              model: "gpt-image-1",
              retry: true,
              degraded: true,
              follow_prompt_strength: followPromptStrength,
              safe_zone_guide: safeZoneGuide,
            },
          });
        } catch (e3: any) {
          return jsonResp({ ok: false, error: e3?.message ?? "Service unavailable" }, 502);
        }
      }
    }
    return jsonResp({ ok: false, error: e?.message ?? "Service unavailable" }, 502);
  }
}

// ─── CHAT HANDLER ─────────────────────────────────────────────────────

async function handleChat(request: Request, env: Env): Promise<Response> {
  const requestId = crypto.randomUUID();
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  if (!checkRateLimit(ip)) {
    return jsonRespWithCors(request, env, {
      status: "error",
      version: "2",
      tool_id: null,
      message: "Too many requests. Try again in a minute.",
      code: "rate_limited",
      meta: { request_id: requestId },
    }, 429);
  }

  let body: any;
  try {
    body = await request.json();
  } catch (e) {
    console.error(`[chat][${requestId}] invalid_json: ${(e as Error)?.message ?? "unknown"}`);
    return jsonRespWithCors(request, env, {
      status: "error",
      version: "2",
      tool_id: null,
      message: "Request body must be valid JSON.",
      code: "invalid_json",
      meta: { request_id: requestId },
    }, 400);
  }

  const apiKey = (env.AI_API_KEY ?? env.OPENAI_API_KEY ?? "").trim();
  if (!apiKey) {
    console.error(`[chat][${requestId}] missing_env: OPENAI_API_KEY/AI_API_KEY not set`);
    return jsonRespWithCors(request, env, {
      status: "error",
      version: "2",
      tool_id: null,
      message: "AI provider key is not configured.",
      code: "missing_env",
      meta: { request_id: requestId },
    }, 500);
  }
  const aiBaseUrl = (env.AI_BASE_URL ?? "https://api.openai.com").replace(/\/+$/, "");
  const chatUrl = `${aiBaseUrl}/v1/chat/completions`;
  const studioMode = typeof body?.tool_id === "string" || String(body?.output_format ?? "").trim().toLowerCase() === "json";
  if (studioMode) {
    const toolIdRaw = String(body?.tool_id ?? "").trim();
    const normalizedToolId = normalizeToolId(toolIdRaw);
    if (!toolIdRaw || !normalizedToolId) {
      return jsonRespWithCors(request, env, {
        status: "error",
        version: CHAT_API_VERSION,
        tool_id: toolIdRaw || null,
        code: "invalid_input",
        message: "Invalid tool_id for studio mode.",
        meta: { request_id: requestId },
      }, 400);
    }
    const toolId = normalizedToolId;
    console.log(`[chat][${requestId}] studioMode=true normalized_tool_id=${toolId}`);

    const context = toObject(body?.context);
    const answers = toObject(body?.answers);
    if (Object.keys(context).length === 0 || Object.keys(answers).length === 0) {
      return jsonRespWithCors(request, env, {
        status: "error",
        version: CHAT_API_VERSION,
        tool_id: toContractToolId(toolId),
        code: "INVALID_INPUT",
        message: "context и answers обязательны для studio mode.",
        meta: { request_id: requestId },
      }, 400);
    }

    const cfg = STUDIO_SCHEMA_CONFIGS[toolId];
    const basePrompt = JSON.stringify(
      {
        tool_id: toContractToolId(toolId),
        locale: String(body?.locale ?? "ru"),
        output_format: "json",
        output_version: body?.output_version ?? 2,
        context,
        answers,
        ai_summary: String(body?.ai_summary ?? ""),
      },
      null,
      2,
    );

    try {
      let modelUsed = "gpt-4o-mini";
      const first = await runStructuredJsonCompletion(
        env,
        cfg.systemPrompt,
        `Return ONLY valid JSON with keys: summary (string), priorities (array of strings or objects {title,why,steps[]}), optional first_actions (array of strings), optional risks (array), optional alt_scenario (string), optional hero ({title,subtitle}). No markdown.\nINPUT:\n${basePrompt}`,
        0.2,
      );
      modelUsed = first.model;
      let parsed = parseJsonSafe(first.content);
      let payload = extractToolDataPayload(parsed);
      let errors = payload && validateMinimal(payload) ? [] : ["minimal_validation_failed"];
      console.log(`[chat][${requestId}] studio validate_first=${errors.length === 0 ? "pass" : "fail"}`);

      if (!payload || errors.length > 0) {
        const retryPrompt = [
          "Convert raw output into valid JSON strictly matching schema",
          "Return ONLY valid JSON with keys: summary (string), priorities (array of strings). No markdown. No extra keys.",
          `RAW_OUTPUT:\n${first.content}`,
          `INPUT:\n${basePrompt}`,
        ].join("\n");
        const repair = await runStructuredJsonCompletion(
          env,
          "You are a JSON repair assistant. Return only valid JSON object.",
          retryPrompt,
          0,
        );
        modelUsed = repair.model;
        parsed = parseJsonSafe(repair.content);
        payload = extractToolDataPayload(parsed);
        errors = payload && validateMinimal(payload) ? [] : ["minimal_validation_failed"];
        console.log(`[chat][${requestId}] studio validate_retry=${errors.length === 0 ? "pass" : "fail"}`);
      }

      if (!payload || errors.length > 0) {
        return jsonRespWithCors(request, env, {
          status: "error",
          version: CHAT_API_VERSION,
          tool_id: toContractToolId(toolId),
          code: "INVALID_MODEL_OUTPUT",
          message: "Не удалось собрать структурный результат",
          meta: { request_id: requestId },
        }, 422);
      }
      const cleanData = sanitizeStudioData(payload);

      return jsonRespWithCors(request, env, {
        status: "ok",
        version: CHAT_API_VERSION,
        tool_id: toContractToolId(toolId),
        data: cleanData,
        meta: {
          request_id: requestId,
          model: modelUsed,
          generated_at: new Date().toISOString(),
        },
      });
    } catch (e) {
      console.error(`[chat][${requestId}] studio internal_error: ${(e as Error)?.message ?? "unknown"}`);
      return jsonRespWithCors(request, env, {
        status: "error",
        version: CHAT_API_VERSION,
        tool_id: toContractToolId(toolId),
        code: "INVALID_MODEL_OUTPUT",
        message: "Не удалось собрать структурный результат",
        meta: { request_id: requestId },
      }, 422);
    }
  }

  const message = typeof body?.message === "string" ? body.message.trim() : "";
  if (!message) {
    return jsonRespWithCors(request, env, {
      status: "error",
      version: "2",
      tool_id: null,
      message: "Field `message` is required and cannot be empty.",
      code: "invalid_input",
      meta: { request_id: requestId },
    }, 400);
  }
  const historySource = Array.isArray(body?.history) ? body.history : [];
  const history = historySource.slice(-12).map((m: any) => ({
    role: m.role as "user" | "assistant",
    content: String(m.content ?? ""),
  }));
  const messages: ChatMessage[] = [
    { role: "system", content: CHAT_SYSTEM },
    ...history,
    { role: "user", content: message },
  ];
  console.log(`[chat][${requestId}] mode=legacy tool_id=none validation=ok`);

  try {
    const res = await fetch(chatUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ model: "gpt-4o-mini", messages, max_tokens: 500 }),
    });

    const rawText = await res.text();
    let data: any = null;
    try {
      data = JSON.parse(rawText);
    } catch {
      data = null;
    }

    if (!res.ok) {
      console.error(
        `[chat][${requestId}] upstream_error status=${res.status} body=${rawText.slice(0, 1000)}`,
      );
      return jsonRespWithCors(request, env, {
        status: "error",
        version: "2",
        tool_id: null,
        message: data?.error?.message ?? "AI provider request failed.",
        code: "upstream_error",
        meta: { request_id: requestId },
      }, res.status >= 500 ? 502 : 400);
    }

    const reply = data?.choices?.[0]?.message?.content?.trim() ?? "Не удалось получить ответ.";
    console.log(`[chat][${requestId}] mode=legacy response_type=text`);
    return jsonRespWithCors(request, env, {
      status: "ok",
      version: CHAT_API_VERSION,
      tool_id: null,
      data: { message: reply },
      meta: {
        request_id: requestId,
        generated_at: new Date().toISOString(),
        model: "gpt-4o-mini",
      },
    });
  } catch (e) {
    console.error(`[chat][${requestId}] internal_error: ${(e as Error)?.message ?? "unknown"}`);
    return jsonRespWithCors(request, env, {
      status: "error",
      version: CHAT_API_VERSION,
      tool_id: null,
      message: "The server had an error while processing your request.",
      code: "internal_error",
      meta: { request_id: requestId },
    }, 500);
  }
}

function logToolObservability(input: {
  toolId: StudioToolId;
  success: boolean;
  fallbackUsed: boolean;
  parseError: boolean;
  validationErrorsCount: number;
  responseSize: number;
  latencyMs: number;
}): void {
  console.log(
    JSON.stringify({
      event: "studio_ai_tool_response",
      tool_id: input.toolId,
      success: input.success,
      fallback_used: input.fallbackUsed,
      parse_error: input.parseError,
      validation_errors_count: input.validationErrorsCount,
      response_size: input.responseSize,
      latency_ms: input.latencyMs,
    }),
  );
}

function safeNormalize(
  toolId: StudioToolId,
  req: UnifiedStudioRequest,
  parsed: Record<string, unknown> | null,
): { data: Record<string, unknown>; usedFallback: boolean; parseError: boolean; validationErrors: number } {
  const parseError = !parsed;
  const source = parsed ?? buildFallbackResponse(toolId, req);
  const before = validateStudioAiResponse(toolId, source);
  const clamped = clampAndSanitizeResponse(toolId, source);
  const after = validateStudioAiResponse(toolId, clamped);
  const data = after.length > 0 ? clampAndSanitizeResponse(toolId, buildFallbackResponse(toolId, req)) : clamped;
  return {
    data,
    usedFallback: parseError || before.length > 0 || after.length > 0,
    parseError,
    validationErrors: before.length + after.length,
  };
}

async function studioToolFlow(toolName: string, body: any, env: Env, startedAt: number): Promise<Response> {
  const requestId = crypto.randomUUID();
  const req = adaptUnifiedStudioRequest(toolName, body);
  const toolId = req.tool_id;
  const systemPrompt = TOOL_SYSTEM_PROMPTS[toolId];
  const userPrompt = buildStudioUserPrompt(req);
  const cacheSeed = JSON.stringify({
    tool_id: req.tool_id,
    context: req.context,
    answers: req.answers,
    ai_summary: req.ai_summary,
    locale: req.locale,
    output_format: req.output_format,
    output_version: req.output_version,
  });
  const cacheKey = `tool:v1:${toolId}:${await sha256(cacheSeed)}`;

  try {
    const rawResult = await cachedAI(env, cacheKey, systemPrompt, userPrompt, 3800);
    const parsed = parseJsonSafe(rawResult) ?? parseJsonSafe((rawResult as any)?._raw_text ?? "");
    const payload = extractToolDataPayload(parsed);
    if (!payload) {
      const err = buildStudioErrorEnvelope(toolId, "2", requestId, "INVALID_MODEL_OUTPUT", "Не удалось собрать структурный результат");
      return jsonResp(err.body, err.statusCode);
    }
    const validationErrors = validateStrictToolData(toolId, payload);
    if (validationErrors.length > 0) {
      const err = buildStudioErrorEnvelope(toolId, "2", requestId, "INVALID_MODEL_OUTPUT", "Не удалось собрать структурный результат");
      return jsonResp(err.body, err.statusCode);
    }
    const responseData = buildStudioOkEnvelope(toolId, "2", requestId, payload);
    logToolObservability({
      toolId,
      success: true,
      fallbackUsed: false,
      parseError: false,
      validationErrorsCount: 0,
      responseSize: JSON.stringify(responseData).length,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResp(responseData);
  } catch (_e) {
    const err = buildStudioErrorEnvelope(toolId, "2", requestId, "INTERNAL_ERROR", "Не удалось собрать структурный результат", 500);
    logToolObservability({
      toolId,
      success: false,
      fallbackUsed: false,
      parseError: true,
      validationErrorsCount: 1,
      responseSize: JSON.stringify(err.body).length,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResp(err.body, err.statusCode);
  }
}

// ─── TOOL HANDLER ─────────────────────────────────────────────────────

async function handleTool(path: string, request: Request, env: Env): Promise<Response> {
  const startedAt = Date.now();
  let body: any;
  try {
    body = await request.json();
  } catch {
    return jsonResp({ error: "Invalid JSON" }, 400);
  }

  const toolName = path.replace("/v1/tools/", "");
  if (toolName === "dnk-content-bridge") {
    try {
      const bodyStr = JSON.stringify(body);
      const cacheKey = `tool:${toolName}:${await sha256(bodyStr)}`;
      const result = await cachedAI(env, cacheKey, DNK_CONTENT_BRIDGE_SYSTEM, buildDnkContentBridgePrompt(body), 3000);
      return jsonResp({ ok: true, data: result });
    } catch (e: any) {
      return jsonResp({ ok: false, error: e.message ?? "AI generation failed" }, 502);
    }
  }

  return studioToolFlow(toolName, body, env, startedAt);
}

// ─── PROMPT BUILDERS ──────────────────────────────────────────────────

function buildGrowthPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  const ctx = i.context ?? {};

  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}
${catalogBlock(body)}

=== ПАРАМЕТРЫ ГЕНЕРАЦИИ ===
Жанр: ${i.genre ?? r.genre ?? "не указан"}
Дата релиза: ${i.releaseDate ?? r.release_date ?? "не указана"}
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["spotify"]).join(", ")}
Аудитория: ${i.audience ?? "не указана"}
Обложка готова: ${i.assets?.coverReady ? "да" : "нет"}
Клип: ${i.assets?.musicVideo ? "да" : "нет"}

Создай ПЕРСОНАЛЬНУЮ 30-дневную карту роста для этого конкретного артиста и релиза. Используй имя артиста, учитывай город, каталог, жанр.`;
}

function buildBudgetPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  const t = i.team ?? {};
  const c = i.constraints ?? {};

  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}
${catalogBlock(body)}

=== ПАРАМЕТРЫ БЮДЖЕТА ===
Тип: ${i.releaseType ?? r.release_type ?? "single"}
Бюджет: ${i.totalBudget ?? 30000} ${i.currency ?? "RUB"}
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Команда: дизайнер=${t.hasDesigner ? "да" : "нет"}, видео=${t.hasVideo ? "да" : "нет"}, PR=${t.hasPR ? "да" : "нет"}
Ограничения: без таргета=${c.noTargetAds ? "да" : "нет"}, без блогеров=${c.noBloggers ? "да" : "нет"}

Создай ПЕРСОНАЛЬНЫЙ бюджет-план. Суммы в allocation ОБЯЗАНЫ в сумме давать ${i.totalBudget ?? 30000} ${i.currency ?? "RUB"}. Учитывай город артиста, его опыт и конкретный релиз.`;
}

function buildPackagingPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};

  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}

=== ПАРАМЕТРЫ УПАКОВКИ ===
Жанр: ${i.genre ?? r.genre ?? "не указан"}
Вайб/настроение: ${i.vibe ?? "не указан"}
О чём трек: ${i.about ?? "не указано"}
Референсы: ${i.references ?? "нет"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["spotify", "yandex"]).join(", ")}

Создай УНИКАЛЬНУЮ упаковку для этого конкретного релиза. Описания должны отражать содержание и вайб трека. Хуки привязаны к теме. Storytelling — атмосферный, не шаблонный.`;
}

function buildContentPlanPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};

  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}

=== ПАРАМЕТРЫ КОНТЕНТ-ПЛАНА ===
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["instagram", "tiktok"]).join(", ")}
Вайб: ${i.vibe ?? "не указан"}
Аудитория: ${i.audience ?? "не указана"}

Создай 14-дневный ПЕРСОНАЛЬНЫЙ контент-план. Каждый день — уникальный сценарий, привязанный к этому артисту и треку. Используй город для локаций съёмок. Шотлисты конкретные: не "красивый кадр", а детальное описание кадра.`;
}

function buildPitchPackPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};

  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}
${catalogBlock(body)}

=== ПАРАМЕТРЫ ПИТЧА ===
Жанр: ${i.genre ?? r.genre ?? "не указан"}
О чём трек: ${i.about ?? "не указано"}
Вайб: ${i.vibe ?? "не указан"}
Референсы: ${i.references ?? "нет"}
Достижения артиста: ${i.achievements ?? "нет"}
Регион: ${i.region ?? "RU"}

Создай ПЕРСОНАЛЬНЫЙ питч-пакет. Short pitch — на английском с именем артиста и названием трека. Bio — на основе реальных данных профиля. Press lines — от лица артиста.`;
}

function buildReleaseDoctorPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}

=== КОНТЕКСТ ===
Текущий этап: ${r.status ?? "draft"}
Цель: ${i.goal ?? "release-ready"}
Комментарии: ${i.note ?? "нет"}

Сделай строгий preflight-аудит релиза. Выдай quality_score и приоритетные правки, которые можно сделать за 24 часа.`;
}

function buildPromoAutopilotPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== ТРЕКЛИСТ ===
${tracksBlock(body)}

=== ПАРАМЕТРЫ АВТОПИЛОТА ===
Цель: ${i.goal ?? "streams"}
Бюджет: ${i.budget ?? "не указан"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["instagram", "tiktok"]).join(", ")}

Построй 7-дневный Smart Promo Autopilot с KPI и fallback-шагами.`;
}

function buildDnkContentBridgePrompt(body: any): string {
  const i = body.inputs ?? {};
  const dnk = i.dnk ?? {};
  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== DNK SUMMARY ===
${JSON.stringify(dnk)}

=== РЕЛИЗ ===
${releaseBlock(body)}

Собери bridge-вывод DNK -> 14 дней контент-действий: оси -> тоны -> хуки -> форматы.`;
}

function buildArtistBriefPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `=== ПРОФИЛЬ АРТИСТА ===
${artistBlock(body)}

=== РЕЛИЗ ===
${releaseBlock(body)}

=== КОНТЕКСТ ===
Фокус недели: ${i.focus ?? "запуск релиза"}
DNK highlights: ${JSON.stringify(i.dnk_highlights ?? [])}
Promo highlights: ${JSON.stringify(i.promo_highlights ?? [])}

Собери структурированный Artist Brief для команды и продакшна.`;
}

function buildWeeklyDigestPrompt(body: any): string {
  const i = body.inputs ?? {};
  return `=== WEEKLY METRICS RAW ===
${JSON.stringify(i.metrics ?? {})}

=== OPS SNAPSHOT ===
${JSON.stringify(i.ops ?? {})}

=== SCOPE ===
${i.scope ?? "artist"}

Сформируй Weekly Executive Digest: wins/risks/priorities с краткой управленческой формулировкой.`;
}
