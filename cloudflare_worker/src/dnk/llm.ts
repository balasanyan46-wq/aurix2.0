import type { LLMProvider, LLMCallOptions, DnkEnv } from "./types";

const DEFAULT_TIMEOUT_MS = 25_000;
const DEFAULT_MAX_TOKENS = 4000;
const MAX_RETRIES = 1;

export class OpenAIProvider implements LLMProvider {
  private apiKey: string;
  private model: string;

  constructor(apiKey: string, model = "gpt-4o-mini") {
    this.apiKey = apiKey;
    this.model = model;
  }

  async generateJSON(systemPrompt: string, userPayload: string, opts?: LLMCallOptions): Promise<any> {
    const timeoutMs = opts?.timeoutMs ?? DEFAULT_TIMEOUT_MS;
    const maxTokens = opts?.maxTokens ?? DEFAULT_MAX_TOKENS;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeoutMs);

        const res = await fetch("https://api.openai.com/v1/chat/completions", {
          method: "POST",
          signal: controller.signal,
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${this.apiKey}`,
          },
          body: JSON.stringify({
            model: this.model,
            messages: [
              { role: "system", content: systemPrompt },
              { role: "user", content: userPayload },
            ],
            max_tokens: maxTokens,
            temperature: 0.7,
            response_format: { type: "json_object" },
          }),
        });

        clearTimeout(timer);

        if (res.status >= 500 && attempt < MAX_RETRIES) {
          lastError = new Error(`OpenAI ${res.status}`);
          await sleep(1000 * (attempt + 1));
          continue;
        }

        const data = (await res.json()) as any;
        if (!res.ok) {
          throw new Error(data?.error?.message ?? `OpenAI error ${res.status}`);
        }

        const raw = data?.choices?.[0]?.message?.content?.trim() ?? "{}";
        return JSON.parse(raw);
      } catch (e: any) {
        if (e.name === "AbortError") {
          lastError = new Error("LLM timeout");
        } else {
          lastError = e;
        }
        if (attempt < MAX_RETRIES) {
          await sleep(1000 * (attempt + 1));
          continue;
        }
      }
    }

    throw lastError ?? new Error("LLM generation failed");
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export function createLLMProvider(env: DnkEnv): LLMProvider {
  const apiKey = env.DNK_OPENAI_API_KEY || env.OPENAI_API_KEY || "";
  console.log("[DNK] LLM key present:", Boolean(apiKey));
  if (!apiKey) {
    throw new Error("LLM_NOT_CONFIGURED");
  }
  return new OpenAIProvider(apiKey);
}
