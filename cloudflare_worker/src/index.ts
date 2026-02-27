import {
  handleDnkStart,
  handleDnkAnswer,
  handleDnkFinish,
  handleDnkGetResult,
  handleDnkOptions,
} from "./dnk/handlers";
import type { DnkEnv } from "./dnk/types";

interface Env {
  OPENAI_API_KEY: string;
  AURIX_INTERNAL_KEY: string;
  AURIX_CACHE: KVNamespace;
  SUPABASE_URL: string;
  SUPABASE_SERVICE_ROLE_KEY: string;
}

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

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

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
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

  const data = (await res.json()) as any;
  if (!res.ok) throw new Error(data?.error?.message ?? "OpenAI error");

  const raw = data?.choices?.[0]?.message?.content?.trim() ?? "{}";
  const parsed = JSON.parse(raw);

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

const CHAT_SYSTEM = `Ты AI-помощник Aurix. Помогаешь артистам оформить релиз, заполнить форму, подготовить описание, теги, стратегию релиза. Отвечай кратко и по делу. Не выдумывай факты. Юр/фин вопросы — аккуратно, без обещаний. Не запрашивай и не выдавай персональные данные.`;

// ─── ROUTER ───────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    const method = request.method;
    if (method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

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

    if (method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);

    if (path === "/api/ai/chat") return handleChat(request, env);
    if (path === "/api/ai/cover") return handleCover(request, env);

    if (path.startsWith("/v1/tools/")) {
      const key = request.headers.get("X-AURIX-INTERNAL-KEY");
      if (!key || key !== env.AURIX_INTERNAL_KEY) {
        return jsonResp({ error: "Forbidden" }, 403);
      }
      return handleTool(path, request, env);
    }

    return jsonResp({ error: "Not found" }, 404);
  },
};

// ─── COVER HANDLER ─────────────────────────────────────────────────────

type CoverReq = {
  prompt: string;
  size?: "1024x1024" | "1536x1536" | "auto";
  quality?: "high" | "medium";
  output_format?: "png";
  background?: "opaque" | "transparent";
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

  const noText = [
    "No readable text.",
    "No typography.",
    "No logos.",
    "No watermarks.",
    "No brand names.",
    "No UI, no mockups, no app screens.",
  ].join(" ");

  const prompt = [
    "Square album cover (1:1).",
    "High-end, premium, professional.",
    "Clean composition, strong focal point, studio quality lighting.",
    userPrompt,
    noText,
  ].join("\n");

  async function call(size: string) {
    const res = await fetch("https://api.openai.com/v1/images/generations", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({
        model: "gpt-image-1",
        prompt,
        size,
        quality,
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
  }

  let sizeToUse = requestedSize === "auto" ? "1024x1024" : requestedSize;
  try {
    const b64 = await call(sizeToUse);
    return jsonResp({ ok: true, b64_png: b64, meta: { size: sizeToUse, quality, model: "gpt-image-1" } });
  } catch (e: any) {
    // Fallback: if 1536 is unsupported / fails, retry with 1024.
    if (sizeToUse === "1536x1536") {
      try {
        sizeToUse = "1024x1024";
        const b64 = await call(sizeToUse);
        return jsonResp({ ok: true, b64_png: b64, meta: { size: sizeToUse, quality, model: "gpt-image-1", fallback: true } });
      } catch (e2: any) {
        return jsonResp({ ok: false, error: e2?.message ?? "Service unavailable" }, 502);
      }
    }
    return jsonResp({ ok: false, error: e?.message ?? "Service unavailable" }, 502);
  }
}

// ─── CHAT HANDLER ─────────────────────────────────────────────────────

async function handleChat(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
  if (!checkRateLimit(ip)) {
    return jsonResp({ error: "Rate limit exceeded. Try again in a minute." }, 429);
  }

  let body: any;
  try {
    body = await request.json();
  } catch {
    return jsonResp({ error: "Invalid JSON" }, 400);
  }

  const message = (body.message ?? "").toString().trim();
  if (!message) return jsonResp({ error: "Empty message" }, 400);

  const history = (body.history ?? []).slice(-12).map((m: any) => ({
    role: m.role as "user" | "assistant",
    content: String(m.content ?? ""),
  }));

  const messages: ChatMessage[] = [
    { role: "system", content: CHAT_SYSTEM },
    ...history,
    { role: "user", content: message },
  ];

  if (!env.OPENAI_API_KEY) return jsonResp({ error: "Server configuration error" }, 500);

  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({ model: "gpt-4o-mini", messages, max_tokens: 500 }),
    });

    const data = (await res.json()) as any;
    if (!res.ok) {
      return jsonResp({ error: data?.error?.message ?? "OpenAI API error" }, res.status >= 500 ? 502 : 400);
    }

    const reply = data?.choices?.[0]?.message?.content?.trim() ?? "Не удалось получить ответ.";
    return jsonResp({ reply });
  } catch {
    return jsonResp({ error: "Service unavailable" }, 503);
  }
}

// ─── TOOL HANDLER ─────────────────────────────────────────────────────

async function handleTool(path: string, request: Request, env: Env): Promise<Response> {
  let body: any;
  try {
    body = await request.json();
  } catch {
    return jsonResp({ error: "Invalid JSON" }, 400);
  }

  const toolName = path.replace("/v1/tools/", "");
  const bodyStr = JSON.stringify(body);
  const cacheKey = `tool:${toolName}:${await sha256(bodyStr)}`;

  let systemPrompt: string;
  let userPrompt: string;
  let maxTokens = 3000;

  switch (toolName) {
    case "growth-plan":
      systemPrompt = GROWTH_PLAN_SYSTEM;
      userPrompt = buildGrowthPrompt(body);
      maxTokens = 4000;
      break;
    case "budget-plan":
      systemPrompt = BUDGET_PLAN_SYSTEM;
      userPrompt = buildBudgetPrompt(body);
      maxTokens = 3000;
      break;
    case "release-packaging":
      systemPrompt = PACKAGING_SYSTEM;
      userPrompt = buildPackagingPrompt(body);
      maxTokens = 3000;
      break;
    case "content-plan-14":
      systemPrompt = CONTENT_PLAN_SYSTEM;
      userPrompt = buildContentPlanPrompt(body);
      maxTokens = 4000;
      break;
    case "playlist-pitch-pack":
      systemPrompt = PITCH_PACK_SYSTEM;
      userPrompt = buildPitchPackPrompt(body);
      maxTokens = 2500;
      break;
    default:
      return jsonResp({ error: `Unknown tool: ${toolName}` }, 404);
  }

  try {
    const result = await cachedAI(env, cacheKey, systemPrompt, userPrompt, maxTokens);
    return jsonResp({ ok: true, data: result });
  } catch (e: any) {
    return jsonResp({ ok: false, error: e.message ?? "AI generation failed" }, 502);
  }
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
