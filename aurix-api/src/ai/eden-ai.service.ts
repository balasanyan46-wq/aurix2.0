import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import {
  AiProvider,
  ChatParams,
  AiMode,
  AiGenerationType,
  GenerateParams,
  GenerateResult,
  AiRequestLog,
  EDEN_PROVIDERS,
  EDEN_ENDPOINTS,
} from './ai-provider.interface';

// ── System prompt ────────────────────────────────────────────

const SYSTEM_PROMPT = `Ты — продюсер-стратег уровня топ-лейблов. Твоё имя — Aurix AI.

Стиль:
— Коротко, мощно, по делу
— Никакой воды и банальностей
— Конкретные примеры и решения
— Без эмодзи

Запрещено:
— Очевидные советы
— Учебниковый тон
— Общие фразы

Отвечай на языке пользователя.`;

// ── Mode instructions ────────────────────────────────────────

const ANALYZE_INSTRUCTION = `Ты получаешь описание трека или идеи от артиста.

Твоя задача — дать полный стратегический разбор.

Ответ СТРОГО в JSON. Без markdown. Без комментариев. Без текста до или после JSON.

{
  "verdict": "Одно предложение — главный вывод о треке/идее. Честно, резко, по делу.",
  "audience": [
    "Конкретный сегмент аудитории с деталями — кто именно, где сидит, что слушает"
  ],
  "content": [
    "Конкретная идея для контента — что снять, как снять, какой формат"
  ],
  "strategy": [
    "Конкретный шаг стратегии — что делать, где, как"
  ],
  "problems": [
    "Конкретная проблема или слабое место — что исправить"
  ],
  "next_steps": [
    "Конкретное следующее действие — одно предложение, готовое к выполнению"
  ]
}

Требования:
— минимум 4 пункта в каждом массиве
— каждый пункт — конкретный, нишевый, не банальный
— audience — НЕ "молодежь 18-25", а "парни 19-22, которые слушают плейлист 'грустный рэп' в VK и залипают на эстетику ночного города"
— content — НЕ "снять видео", а "вертикальное видео 15 сек: ты идёшь по ночной улице, камера на уровне земли, трек играет с задержкой 2 сек"
— strategy — НЕ "продвигать в соцсетях", а "первые 3 дня: закинуть в 5 пабликов VK с аудиторией 10-50k, договориться на бартер"
— problems — честная критика, без обтекаемых формулировок
— verdict — одно резкое предложение, как продюсер сказал бы артисту в лицо`;

const MODE_INSTRUCTIONS: Record<AiMode, string | null> = {
  chat: null,
  dnk_full: null,
  analyze: ANALYZE_INSTRUCTION,

  lyrics: `Напиши текст песни.

Формат:
— Куплет 1 (4-8 строк)
— Припев (сильный, запоминающийся, 4 строки)
— Куплет 2 (4-8 строк)
— Припев
— Бридж (2-4 строки, смена ракурса)
— Финальный припев

Требования:
— точные рифмы, не глагольные
— живые образы, не клише
— коммерческий стиль — текст должен цеплять с первой строки
— припев должен застревать в голове`,

  ideas: `Сгенерируй 10 идей для трека.

Ответ строго в JSON:

[
  {
    "title": "Рабочее название",
    "idea": "Концепция",
    "hook": "Ключевая фраза для припева"
  }
]`,

  reels: `Сгенерируй 10 идей для Reels/TikTok.

Ответ строго в JSON:

[
  {
    "idea": "Что снять и как",
    "hook": "Первые 2 секунды",
    "caption": "Текст поста"
  }
]`,

  dnk: `Проанализируй артиста и верни разбор.

Ответ строго в JSON:

{
  "audience": ["Сегменты аудитории"],
  "triggers": ["Эмоциональные триггеры"],
  "content_angles": ["Контент-стратегии"],
  "reels_ideas": ["Идеи для Reels"]
}`,
};

// ── Eden AI response shapes ─────────────────────────────────

interface EdenProviderResult {
  status: string;
  generated_text?: string;
  items?: Array<{ image: string; image_resource_url?: string }>;
  video?: string;
  video_resource_url?: string;
  audio?: string;
  audio_resource_url?: string;
}

// ── Service ──────────────────────────────────────────────────

@Injectable()
export class EdenAiService implements AiProvider {
  private readonly log = new Logger(EdenAiService.name);
  private readonly apiKey: string;

  constructor() {
    const key = process.env.EDEN_AI_API_KEY;
    if (!key) {
      throw new Error('EDEN_AI_API_KEY is not defined');
    }
    this.apiKey = key;
    this.log.log('Eden AI service initialized');
  }

  // ── Text chat (implements AiProvider) ──────────────────────

  async chat(params: ChatParams): Promise<string> {
    const { message, mode = 'chat', history, contextPrompt } = params;

    let systemPrompt = SYSTEM_PROMPT;
    if (contextPrompt) {
      systemPrompt += `\n\n${contextPrompt}`;
    }

    const modeInstruction = MODE_INSTRUCTIONS[mode];

    const previousHistory: Array<{ role: string; message: string }> = [];
    if (history?.length) {
      for (const msg of history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          previousHistory.push({ role: msg.role, message: msg.content });
        }
      }
    }

    const userContent = modeInstruction
      ? `${modeInstruction}\n\n---\n\nЗапрос артиста: ${message}`
      : message;

    const isStructured =
      mode === 'analyze' || mode === 'ideas' || mode === 'reels' ||
      mode === 'dnk' || mode === 'dnk_full';

    const temperature = isStructured ? 0.7 : 0.9;
    const maxTokens =
      mode === 'dnk_full' ? 8000
        : mode === 'analyze' ? 4000
          : mode === 'lyrics' ? 2000
            : isStructured ? 3000 : 1500;

    const body: Record<string, any> = {
      providers: EDEN_PROVIDERS.text,
      text: userContent,
      chatbot_global_action: systemPrompt,
      temperature,
      max_tokens: maxTokens,
    };
    if (previousHistory.length > 0) {
      body.previous_history = previousHistory;
    }

    const timeout = mode === 'dnk_full' ? 120_000 : 60_000;
    const result = await this.callEden('text', body, timeout);
    const content = result.content;

    return isStructured ? this.extractJson(content) : content;
  }

  // ── Simple text call (for services that just need a quick prompt) ──

  async simpleChat(
    systemPrompt: string,
    userMessage: string,
    opts?: { maxTokens?: number; temperature?: number; timeout?: number },
  ): Promise<string> {
    const body: Record<string, any> = {
      providers: EDEN_PROVIDERS.text,
      text: userMessage,
      chatbot_global_action: systemPrompt,
      max_tokens: opts?.maxTokens ?? 1500,
      temperature: opts?.temperature ?? 0.7,
    };

    const result = await this.callEden('text', body, opts?.timeout ?? 30_000);
    return result.content;
  }

  // ── Unified generate (all types) ──────────────────────────

  async generate(params: GenerateParams): Promise<GenerateResult> {
    const { type, prompt } = params;

    if (type === 'text') {
      const text = await this.chat({ message: prompt });
      return { type: 'text', content: text, provider: 'eden', raw: null };
    }

    const body = this.buildGenerateBody(type, prompt, params);
    const timeout = type === 'video' ? 300_000 : 120_000;

    return this.callEden(type, body, timeout, params.userId);
  }

  // ── Internal: build request body per type ──────────────────

  private buildGenerateBody(
    type: AiGenerationType,
    prompt: string,
    params: GenerateParams,
  ): Record<string, any> {
    const base = { providers: EDEN_PROVIDERS[type], text: prompt };

    switch (type) {
      case 'image':
        return {
          ...base,
          resolution: params.resolution || '1024x1024',
          num_images: params.numImages || 1,
        };
      case 'video':
        return base;
      case 'audio':
        return {
          ...base,
          language: params.language || 'ru',
          option: params.voice || 'FEMALE',
        };
      default:
        return base;
    }
  }

  // ── Internal: single HTTP call + normalize + log ───────────

  private async callEden(
    type: AiGenerationType,
    body: Record<string, any>,
    timeout: number,
    userId?: string,
  ): Promise<GenerateResult> {
    const endpoint = EDEN_ENDPOINTS[type];
    const startMs = Date.now();

    try {
      const { data } = await axios.post<Record<string, EdenProviderResult>>(
        endpoint,
        body,
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          timeout,
        },
      );

      const normalized = this.normalize(type, data);
      this.logRequest({ userId, type, provider: normalized.provider, success: true, latencyMs: Date.now() - startMs });

      return normalized;
    } catch (error) {
      const latencyMs = Date.now() - startMs;
      const msg = error instanceof Error ? error.message : String(error);
      this.logRequest({ userId, type, provider: 'none', success: false, latencyMs, error: msg });

      if (error instanceof HttpException) throw error;

      this.log.error(`[${type}] Eden AI failed (${latencyMs}ms): ${msg}`);
      throw new HttpException(
        `AI ${type} generation failed`,
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  // ── Normalize Eden multi-provider response ─────────────────

  private normalize(
    type: AiGenerationType,
    data: Record<string, EdenProviderResult>,
  ): GenerateResult {
    // Walk providers in the configured priority order
    const providerList = EDEN_PROVIDERS[type].split(',');

    // Try priority order first, then any remaining
    const allProviders = [
      ...providerList,
      ...Object.keys(data).filter((k) => !providerList.includes(k)),
    ];

    for (const provider of allProviders) {
      const r = data[provider];
      if (!r || r.status !== 'success') continue;

      switch (type) {
        case 'text':
          if (r.generated_text) {
            return { type, content: r.generated_text, provider, raw: r };
          }
          break;

        case 'image':
          if (r.items?.length) {
            const item = r.items[0];
            const content = item.image_resource_url || `data:image/png;base64,${item.image}`;
            return { type, content, provider, raw: r };
          }
          break;

        case 'video':
          if (r.video_resource_url || r.video) {
            return { type, content: (r.video_resource_url || r.video)!, provider, raw: r };
          }
          break;

        case 'audio':
          if (r.audio_resource_url || r.audio) {
            const content = r.audio_resource_url || `data:audio/mp3;base64,${r.audio}`;
            return { type, content, provider, raw: r };
          }
          break;
      }
    }

    // Log all provider failures
    for (const [provider, r] of Object.entries(data)) {
      if (r?.status !== 'success') {
        this.log.warn(`[${type}] provider ${provider} failed: ${r?.status ?? 'no response'}`);
      }
    }

    throw new HttpException(
      `All ${type} providers failed`,
      HttpStatus.BAD_GATEWAY,
    );
  }

  // ── Logging ────────────────────────────────────────────────

  private logRequest(entry: AiRequestLog): void {
    const tag = entry.success ? 'OK' : 'FAIL';
    const detail = entry.error ? ` err=${entry.error.slice(0, 120)}` : '';
    this.log.log(
      `[${entry.type}] ${tag} provider=${entry.provider} ` +
      `user=${entry.userId ?? 'anon'} ${entry.latencyMs}ms${detail}`,
    );
  }

  // ── JSON extraction ────────────────────────────────────────

  private extractJson(raw: string): string {
    // Try markdown fence
    const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fenceMatch) return fenceMatch[1].trim();

    // Try raw JSON
    const trimmed = raw.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        JSON.parse(trimmed);
        return trimmed;
      } catch { /* fall through */ }
    }

    return raw;
  }
}
