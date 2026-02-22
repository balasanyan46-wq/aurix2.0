const SYSTEM_PROMPT = `Ты AI-помощник Aurix. Помогаешь артистам оформить релиз, заполнить форму, подготовить описание, теги, стратегию релиза. Отвечай кратко и по делу. Не выдумывай факты. Юр/фин вопросы — аккуратно, без обещаний. Не запрашивай и не выдавай персональные данные.`;

interface Env {
  OPENAI_API_KEY: string;
}

interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

interface RequestBody {
  message: string;
  history?: Array<{ role: string; content: string }>;
  page?: string;
  context?: Record<string, unknown>;
}

const RATE_LIMIT = 20;
const RATE_WINDOW_MS = 60_000;

const rateMap = new Map<string, { count: number; resetAt: number }>();

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const entry = rateMap.get(ip);
  if (!entry) {
    rateMap.set(ip, { count: 1, resetAt: now + RATE_WINDOW_MS });
    return true;
  }
  if (now >= entry.resetAt) {
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
  "Access-Control-Allow-Headers": "Content-Type",
  "Access-Control-Max-Age": "86400",
};

function jsonResponse(body: object, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders,
    },
  });
}

export default {
  async fetch(request: Request, env: Env, _ctx: ExecutionContext): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    if (request.method !== "POST" || new URL(request.url).pathname !== "/api/ai/chat") {
      return jsonResponse({ error: "Not found" }, 404);
    }

    const ip = request.headers.get("CF-Connecting-IP") ?? "unknown";
    if (!checkRateLimit(ip)) {
      return jsonResponse({ error: "Rate limit exceeded. Try again in a minute." }, 429);
    }

    let body: RequestBody;
    try {
      body = (await request.json()) as RequestBody;
    } catch {
      return jsonResponse({ error: "Invalid JSON" }, 400);
    }

    const message = (body.message ?? "").toString().trim();
    if (!message) {
      return jsonResponse({ error: "Empty message" }, 400);
    }

    const history = (body.history ?? []).slice(-12).map((m) => ({
      role: m.role as "user" | "assistant",
      content: String(m.content ?? ""),
    }));

    const messages: ChatMessage[] = [
      { role: "system", content: SYSTEM_PROMPT },
      ...history,
      { role: "user", content: message },
    ];

    const apiKey = env.OPENAI_API_KEY;
    if (!apiKey) {
      return jsonResponse({ error: "Server configuration error" }, 500);
    }

    try {
      const res = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: "gpt-4o-mini",
          messages,
          max_tokens: 500,
        }),
      });

      const data = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>;
        error?: { message?: string };
      };

      if (!res.ok) {
        const err = data?.error?.message ?? "OpenAI API error";
        return jsonResponse({ error: err }, res.status >= 500 ? 502 : 400);
      }

      const reply =
        data?.choices?.[0]?.message?.content?.trim() ?? "Не удалось получить ответ.";
      return jsonResponse({ reply });
    } catch (e) {
      return jsonResponse({ error: "Service unavailable" }, 503);
    }
  },
};
