/**
 * AI Provider Abstraction Layer
 *
 * Enables switching between OpenAI, YandexGPT, GigaChat, Polza.ai
 * via environment variable AI_PROVIDER.
 *
 * Usage:
 *   const ai = createAiProvider(env);
 *   const text = await ai.chat(system, user);
 *   const image = await ai.generateImage(prompt, opts);
 */

export interface ChatOptions {
  model?: string;
  maxTokens?: number;
  temperature?: number;
  responseFormat?: "text" | "json_object";
  timeoutMs?: number;
}

export interface ImageOptions {
  model?: string;
  size?: string;
  quality?: "high" | "medium";
  outputFormat?: string;
  background?: string;
  timeoutMs?: number;
}

export interface ImageResult {
  b64: string;
  revisedPrompt?: string;
}

export interface AiProvider {
  readonly name: string;
  chat(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<string>;
  chatJSON(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<any>;
  generateImage(prompt: string, opts?: ImageOptions): Promise<ImageResult>;
}

// ─── OpenAI-compatible provider (works with OpenAI, Polza.ai, any OpenAI-compatible API) ───

export class OpenAiCompatibleProvider implements AiProvider {
  readonly name: string;
  private baseUrl: string;
  private apiKey: string;
  private defaultModel: string;
  private defaultImageModel: string;

  constructor(opts: {
    name?: string;
    baseUrl: string;
    apiKey: string;
    defaultModel?: string;
    defaultImageModel?: string;
  }) {
    this.name = opts.name ?? "openai";
    this.baseUrl = opts.baseUrl.replace(/\/+$/, "");
    this.apiKey = opts.apiKey;
    this.defaultModel = opts.defaultModel ?? "gpt-4o-mini";
    this.defaultImageModel = opts.defaultImageModel ?? "gpt-image-1";
  }

  async chat(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<string> {
    const json = await this._chatRaw(systemPrompt, userMessage, {
      ...opts,
      responseFormat: "text",
    });
    return json?.choices?.[0]?.message?.content?.trim() ?? "";
  }

  async chatJSON(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<any> {
    const json = await this._chatRaw(systemPrompt, userMessage, {
      ...opts,
      responseFormat: "json_object",
    });
    const raw = json?.choices?.[0]?.message?.content?.trim() ?? "{}";
    return JSON.parse(raw);
  }

  async generateImage(prompt: string, opts?: ImageOptions): Promise<ImageResult> {
    const timeoutMs = opts?.timeoutMs ?? 170_000;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const res = await fetch(`${this.baseUrl}/v1/images/generations`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        signal: controller.signal,
        body: JSON.stringify({
          model: opts?.model ?? this.defaultImageModel,
          prompt,
          size: opts?.size ?? "1024x1024",
          quality: opts?.quality ?? "high",
          output_format: opts?.outputFormat ?? "png",
          background: opts?.background ?? "opaque",
        }),
      });

      const data = (await res.json()) as any;
      if (!res.ok) throw new Error(data?.error?.message ?? `Image generation error ${res.status}`);

      const item = data?.data?.[0] ?? {};
      const b64 = (item?.b64_json ?? item?.b64_png ?? item?.b64) as string | undefined;
      if (!b64) throw new Error("Empty image response");

      return {
        b64,
        revisedPrompt: item?.revised_prompt,
      };
    } finally {
      clearTimeout(timer);
    }
  }

  private async _chatRaw(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<any> {
    const timeoutMs = opts?.timeoutMs ?? 25_000;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const body: any = {
        model: opts?.model ?? this.defaultModel,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: userMessage },
        ],
        max_tokens: opts?.maxTokens ?? 4000,
        temperature: opts?.temperature ?? 0.7,
      };
      if (opts?.responseFormat === "json_object") {
        body.response_format = { type: "json_object" };
      }

      const res = await fetch(`${this.baseUrl}/v1/chat/completions`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${this.apiKey}`,
        },
        signal: controller.signal,
        body: JSON.stringify(body),
      });

      const data = (await res.json()) as any;
      if (!res.ok) throw new Error(data?.error?.message ?? `Chat error ${res.status}`);
      return data;
    } finally {
      clearTimeout(timer);
    }
  }
}

// ─── YandexGPT Provider ───

export class YandexGptProvider implements AiProvider {
  readonly name = "yandexgpt";
  private apiKey: string;
  private folderId: string;
  private model: string;

  constructor(opts: { apiKey: string; folderId: string; model?: string }) {
    this.apiKey = opts.apiKey;
    this.folderId = opts.folderId;
    this.model = opts.model ?? "yandexgpt-lite";
  }

  async chat(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<string> {
    const timeoutMs = opts?.timeoutMs ?? 30_000;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const res = await fetch("https://llm.api.cloud.yandex.net/foundationModels/v1/completion", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Api-Key ${this.apiKey}`,
          "x-folder-id": this.folderId,
        },
        signal: controller.signal,
        body: JSON.stringify({
          modelUri: `gpt://${this.folderId}/${this.model}`,
          completionOptions: {
            stream: false,
            temperature: opts?.temperature ?? 0.7,
            maxTokens: String(opts?.maxTokens ?? 4000),
          },
          messages: [
            { role: "system", text: systemPrompt },
            { role: "user", text: userMessage },
          ],
        }),
      });

      const data = (await res.json()) as any;
      if (!res.ok) throw new Error(data?.error?.message ?? `YandexGPT error ${res.status}`);
      return data?.result?.alternatives?.[0]?.message?.text?.trim() ?? "";
    } finally {
      clearTimeout(timer);
    }
  }

  async chatJSON(systemPrompt: string, userMessage: string, opts?: ChatOptions): Promise<any> {
    const text = await this.chat(
      systemPrompt + "\n\nОтвечай СТРОГО в формате JSON.",
      userMessage,
      opts,
    );
    return JSON.parse(text);
  }

  async generateImage(_prompt: string, _opts?: ImageOptions): Promise<ImageResult> {
    // YandexGPT does not have image generation.
    // Use Kandinsky (GigaChat) or Yandex ART for images.
    throw new Error("YandexGPT does not support image generation. Use 'gigachat' or 'kandinsky' provider.");
  }
}

// ─── Factory ───

export interface AiEnvVars {
  AI_PROVIDER?: string;
  AI_API_KEY?: string;
  AI_BASE_URL?: string;
  OPENAI_API_KEY?: string;
  YANDEX_API_KEY?: string;
  YANDEX_FOLDER_ID?: string;
  YANDEX_GPT_MODEL?: string;
}

export function createAiProvider(env: AiEnvVars): AiProvider {
  const provider = (env.AI_PROVIDER ?? "openai").toLowerCase();

  switch (provider) {
    case "yandexgpt":
    case "yandex": {
      const apiKey = env.YANDEX_API_KEY || env.AI_API_KEY || "";
      const folderId = env.YANDEX_FOLDER_ID || "";
      if (!apiKey || !folderId) throw new Error("YANDEX_API_KEY and YANDEX_FOLDER_ID required");
      return new YandexGptProvider({
        apiKey,
        folderId,
        model: env.YANDEX_GPT_MODEL,
      });
    }

    case "polza":
    case "polza.ai": {
      const apiKey = env.AI_API_KEY || "";
      if (!apiKey) throw new Error("AI_API_KEY required for Polza.ai");
      return new OpenAiCompatibleProvider({
        name: "polza",
        baseUrl: env.AI_BASE_URL || "https://api.polza.ai",
        apiKey,
        defaultModel: "gpt-4o-mini",
      });
    }

    case "openai":
    default: {
      const apiKey = env.AI_API_KEY || env.OPENAI_API_KEY || "";
      if (!apiKey) throw new Error("OPENAI_API_KEY or AI_API_KEY required");
      return new OpenAiCompatibleProvider({
        name: "openai",
        baseUrl: env.AI_BASE_URL || "https://api.openai.com",
        apiKey,
      });
    }
  }
}
