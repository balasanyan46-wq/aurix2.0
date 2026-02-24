interface Env {
  OPENAI_API_KEY: string;
  AURIX_INTERNAL_KEY: string;
  AURIX_CACHE: KVNamespace;
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
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
      temperature: 0.7,
      response_format: { type: "json_object" },
    }),
  });

  const data = (await res.json()) as any;
  if (!res.ok) throw new Error(data?.error?.message ?? "OpenAI error");

  const raw = data?.choices?.[0]?.message?.content?.trim() ?? "{}";
  const parsed = JSON.parse(raw);

  await env.AURIX_CACHE.put(cacheKey, JSON.stringify(parsed), { expirationTtl: 86400 });
  return parsed;
}

// ─── TOOL SYSTEM PROMPTS ──────────────────────────────────────────────

const GROWTH_PLAN_SYSTEM = `Ты — AI-стратег музыкального маркетинга Aurix. Генерируешь 30-дневную карту роста для релиза.
Ответ СТРОГО в JSON:
{
  "summary": "краткое описание стратегии",
  "positioning": {"one_liner": "...", "angle": "...", "audience": "..."},
  "risks": ["риск 1", ...],
  "levers": ["рычаг 1", ...],
  "content_angles": ["угол 1", ...],
  "quick_wins_48h": ["быстрая победа 1", ...],
  "weekly_focus": [{"week":1,"focus":"..."},{"week":2,"focus":"..."},{"week":3,"focus":"..."},{"week":4,"focus":"..."}],
  "days": [{"day":0,"title":"...","tasks":["..."],"outputs":["..."],"time_min":45}, ... до day 30],
  "checkpoints": [{"day":7,"kpi":["..."],"actions":["..."]},{"day":14,...},{"day":30,...}]
}
Пиши на русском. Будь конкретным, давай реальные действия, не общие фразы.`;

const BUDGET_PLAN_SYSTEM = `Ты — AI-финансовый стратег Aurix для музыкантов. Генерируешь бюджет-план продвижения.
Ответ СТРОГО в JSON:
{
  "summary": "...",
  "risks": ["на что сольётся бюджет 1", ...],
  "must_do": ["обязательное 1", ...],
  "anti_waste": ["нельзя тратить на 1", ...],
  "cheapest_strategy": "что делать при мин. бюджете",
  "allocation": [{"category":"...","amount":0,"percent":0,"notes":"...","currency":"₽"}, ...],
  "dont_spend_on": ["..."],
  "must_spend_on": ["..."],
  "next_steps": ["..."]
}
Пиши на русском. Суммы должны сойтись с общим бюджетом.`;

const PACKAGING_SYSTEM = `Ты — AI-копирайтер и маркетолог Aurix. Создаёшь полную упаковку релиза.
Ответ СТРОГО в JSON:
{
  "title_variants": ["вариант 1", ... до 5],
  "description_platforms": {
    "yandex": "описание для Яндекс Музыки (до 500 символов)",
    "vk": "описание для VK Музыки",
    "spotify": "описание для Spotify (English)",
    "apple": "описание для Apple Music (English)"
  },
  "storytelling": "история/нарратив релиза (3-5 предложений)",
  "hooks": ["хук 1", ... 10-20 коротких фраз для роликов],
  "cta_variants": ["призыв 1", ... 5-10 CTA]
}
Пиши на языке платформы. Хуки — цепляющие, 5-10 слов.`;

const CONTENT_PLAN_SYSTEM = `Ты — AI-контент-стратег Aurix. Создаёшь 14-дневный контент-план Reels/Shorts.
Ответ СТРОГО в JSON:
{
  "strategy": "общая стратегия (2-3 предложения)",
  "days": [
    {"day":1,"format":"Reels","hook":"хук первых 2 сек","script":"полный сценарий (3-5 предложений)","shotlist":["кадр 1","кадр 2",...],"cta":"призыв к действию"},
    ... до day 14
  ]
}
Каждый день — уникальный формат. Миксуй: Reels, Shorts, TikTok, Stories, Carousel. Пиши на русском.`;

const PITCH_PACK_SYSTEM = `Ты — AI-PR стратег Aurix. Создаёшь питч-пакет для плейлист-кураторов.
Ответ СТРОГО в JSON:
{
  "short_pitch": "короткий питч (2-3 предложения, до 200 символов)",
  "long_pitch": "развёрнутый питч (5-8 предложений)",
  "email_subjects": ["тема 1", ... до 5],
  "press_lines": ["строка 1", ... 5-10 строк для пресс-релиза],
  "artist_bio": "биография артиста (3-5 предложений)"
}
Пиши профессионально. Short pitch — на английском для международных кураторов. Long pitch — на русском.`;

const CHAT_SYSTEM = `Ты AI-помощник Aurix. Помогаешь артистам оформить релиз, заполнить форму, подготовить описание, теги, стратегию релиза. Отвечай кратко и по делу. Не выдумывай факты. Юр/фин вопросы — аккуратно, без обещаний. Не запрашивай и не выдавай персональные данные.`;

// ─── ROUTER ───────────────────────────────────────────────────────────

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }
    if (request.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405);

    const url = new URL(request.url);
    const path = url.pathname;

    // Chat endpoint (public, rate-limited by IP)
    if (path === "/api/ai/chat") return handleChat(request, env);

    // Tool endpoints (internal key protected)
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
  return `Релиз: «${r.title ?? "—"}» (${r.artist ?? "—"})
Жанр: ${i.genre ?? r.genre ?? "не указан"}
Тип: ${r.release_type ?? "single"}
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["spotify"]).join(", ")}
Аудитория: ${i.audience ?? "не указана"}
Обложка готова: ${i.assets?.coverReady ? "да" : "нет"}
Клип: ${i.assets?.musicVideo ? "да" : "нет"}

Сгенерируй полную 30-дневную карту роста.`;
}

function buildBudgetPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  const t = i.team ?? {};
  const c = i.constraints ?? {};
  return `Релиз: «${r.title ?? "—"}» (${r.artist ?? "—"})
Тип: ${i.releaseType ?? r.release_type ?? "single"}
Бюджет: ${i.totalBudget ?? 30000} ${i.currency ?? "RUB"}
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Команда: дизайнер=${t.hasDesigner ? "да" : "нет"}, видео=${t.hasVideo ? "да" : "нет"}, PR=${t.hasPR ? "да" : "нет"}
Ограничения: без таргета=${c.noTargetAds ? "да" : "нет"}, без блогеров=${c.noBloggers ? "да" : "нет"}

Сгенерируй бюджет-план.`;
}

function buildPackagingPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `Релиз: «${r.title ?? "—"}» (${r.artist ?? "—"})
Жанр: ${i.genre ?? r.genre ?? "не указан"}
Вайб/настроение: ${i.vibe ?? "не указан"}
О чём трек: ${i.about ?? "не указано"}
Референсы: ${i.references ?? "нет"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["spotify", "yandex"]).join(", ")}

Создай полную упаковку: варианты названий, описания для платформ, сторителлинг, хуки для видео, CTA.`;
}

function buildContentPlanPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `Релиз: «${r.title ?? "—"}» (${r.artist ?? "—"})
Жанр: ${r.genre ?? "не указан"}
Цель: ${i.goal ?? "streams"}
Регион: ${i.region ?? "RU"}
Платформы: ${(i.platforms ?? ["instagram", "tiktok"]).join(", ")}
Вайб: ${i.vibe ?? "не указан"}
Аудитория: ${i.audience ?? "не указана"}

Создай 14-дневный контент-план Reels/Shorts с конкретными сценариями, хуками и шотлистами.`;
}

function buildPitchPackPrompt(body: any): string {
  const r = body.release ?? {};
  const i = body.inputs ?? {};
  return `Релиз: «${r.title ?? "—"}» (${r.artist ?? "—"})
Жанр: ${i.genre ?? r.genre ?? "не указан"}
О чём трек: ${i.about ?? "не указано"}
Вайб: ${i.vibe ?? "не указан"}
Референсы: ${i.references ?? "нет"}
Достижения артиста: ${i.achievements ?? "нет"}
Регион: ${i.region ?? "RU"}

Создай питч-пакет для плейлист-кураторов и журналистов.`;
}
