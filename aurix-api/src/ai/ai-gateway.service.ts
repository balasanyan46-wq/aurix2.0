import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import {
  AiProvider,
  ChatParams,
  AiMode,
  GenerateParams,
  GenerateResult,
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

Если в контексте есть DNK профиль артиста — ты ОБЯЗАН его использовать:
— Обращайся к конкретным осям и показателям артиста
— Привязывай советы к его архетипу, сильным и слабым сторонам
— Говори как продюсер, который работает с этим артистом лично
— Если артист спрашивает «что мне делать» — отвечай через его DNK

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

// ── Service ──────────────────────────────────────────────────

@Injectable()
export class AiGatewayService implements AiProvider {
  private readonly log = new Logger('AiService');
  private readonly gatewayUrl: string;
  private readonly gatewaySecret: string;

  constructor() {
    this.gatewayUrl = process.env.AI_GATEWAY_URL || '';
    this.gatewaySecret = process.env.AI_GATEWAY_SECRET || '';

    if (!this.gatewayUrl) {
      this.log.warn('AI_GATEWAY_URL not set — AI features will not work');
    } else {
      this.log.log(`AI Service initialized (gateway: ${this.gatewayUrl})`);
    }
  }

  // ── Text chat ────────────────────────────────────────────

  async chat(params: ChatParams): Promise<string> {
    const { message, mode = 'chat', history, contextPrompt } = params;

    let systemPrompt = SYSTEM_PROMPT;
    if (contextPrompt) systemPrompt += `\n\n${contextPrompt}`;

    const modeInstruction = MODE_INSTRUCTIONS[mode];
    const userContent = modeInstruction
      ? `${modeInstruction}\n\n---\n\nЗапрос артиста: ${message}`
      : message;

    const isStructured =
      mode === 'analyze' || mode === 'ideas' || mode === 'reels' ||
      mode === 'dnk' || mode === 'dnk_full';

    const temperature = isStructured ? 0.7 : 0.9;
    const maxTokens =
      mode === 'dnk_full' ? 8000
        : mode === 'analyze' ? 3000
          : mode === 'lyrics' ? 2000
            : isStructured ? 3000 : 1500;

    const timeout = mode === 'dnk_full' ? 120_000 : mode === 'analyze' ? 120_000 : 30_000;

    // Build messages array for Gateway
    const messages: Array<{ role: string; content: string }> = [
      { role: 'system', content: systemPrompt },
    ];

    // Add conversation history
    if (history?.length) {
      for (const msg of history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      }
    }

    messages.push({ role: 'user', content: userContent });

    // gpt-4o-mini — самый стабильный и быстрый через EU-прокси; analyze требует gpt-4.1 для качества;
    // dnk_full (8000 токенов) оставляем gateway default, т.к. у него длиннее контекст.
    const model =
      mode === 'analyze' ? 'gpt-4.1'
      : mode === 'dnk_full' ? undefined
      : 'gpt-4o-mini';
    const content = await this.callGateway(messages, { maxTokens, temperature, timeout, model });
    return isStructured ? this.extractJson(content) : content;
  }

  // ── Simple text call ──────────────────────────────────────

  async simpleChat(
    systemPrompt: string,
    userMessage: string,
    opts?: { maxTokens?: number; temperature?: number; timeout?: number },
  ): Promise<string> {
    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: userMessage },
    ];
    return this.callGateway(messages, {
      maxTokens: opts?.maxTokens ?? 1500,
      temperature: opts?.temperature ?? 0.7,
      timeout: opts?.timeout ?? 30_000,
    });
  }

  // ── Unified generate (all types) ──────────────────────────

  async generate(params: GenerateParams): Promise<GenerateResult> {
    const { type, prompt } = params;

    if (type === 'text') {
      const text = await this.chat({ message: prompt });
      return { type: 'text', content: text, provider: 'gateway', raw: null };
    }

    if (type === 'image') {
      return this.generateImage(prompt, params);
    }

    throw new HttpException(
      `Генерация типа "${type}" пока не поддерживается`,
      HttpStatus.BAD_REQUEST,
    );
  }

  // ── Image generation via Gateway ──────────────────────────

  private async generateImage(prompt: string, params: GenerateParams): Promise<GenerateResult> {
    if (!this.gatewayUrl) {
      throw new HttpException('AI Gateway не настроен', HttpStatus.SERVICE_UNAVAILABLE);
    }

    const startMs = Date.now();
    try {
      const { data } = await axios.post(`${this.gatewayUrl}/ai/image`, {
        prompt,
        size: params.resolution || '1024x1024',
      }, {
        headers: { 'X-Gateway-Secret': this.gatewaySecret, 'Content-Type': 'application/json' },
        timeout: 120_000,
      });

      if (data.success && data.url) {
        this.log.log(`[image] OK via ${data.provider} ${Date.now() - startMs}ms`);
        return { type: 'image', content: data.url, provider: `gateway/${data.provider}`, raw: null };
      }

      throw new Error('No URL in response');
    } catch (e: any) {
      this.log.error(`[image] Failed (${Date.now() - startMs}ms): ${e.message}`);
      throw new HttpException('Генерация изображения не удалась', HttpStatus.BAD_GATEWAY);
    }
  }

  // ── Call AI Gateway (with retry + fallback) ────────────────

  private async callGateway(
    messages: Array<{ role: string; content: string }>,
    opts: { maxTokens?: number; temperature?: number; timeout?: number; model?: string },
  ): Promise<string> {
    if (!this.gatewayUrl) {
      throw new HttpException('AI Gateway не настроен', HttpStatus.SERVICE_UNAVAILABLE);
    }

    const baseTimeout = opts.timeout || 30_000;
    const requestedModel = opts.model;

    // Heavy calls (analyze/dnk_full, timeout ≥ 60s) — 3 попытки с полным таймаутом, разные модели.
    // Chat-like calls — 4 попытки с градуированным таймаутом (fail-fast → retry дольше),
    // чередуем две быстрые модели, чтобы не биться в один и тот же прокси-путь.
    const isHeavy = baseTimeout >= 60_000;

    const primary = requestedModel || 'gpt-4o-mini';
    const alternate = primary === 'gpt-4o-mini' ? 'gpt-4.1-mini' : 'gpt-4o-mini';

    const attempts: Array<{ model?: string; timeout: number }> = isHeavy
      ? [
          { model: primary, timeout: baseTimeout },
          { model: alternate, timeout: baseTimeout },
          { model: primary, timeout: baseTimeout },
        ]
      : [
          { model: primary, timeout: 15_000 },
          { model: alternate, timeout: 20_000 },
          { model: primary, timeout: 25_000 },
          { model: alternate, timeout: 30_000 },
        ];

    let lastError = '';

    for (let i = 0; i < attempts.length; i++) {
      const attempt = attempts[i];
      const startMs = Date.now();

      try {
        const body: Record<string, unknown> = {
          messages,
          max_tokens: opts.maxTokens || 2000,
          temperature: opts.temperature ?? 0.7,
        };
        if (attempt.model) body.model = attempt.model;

        const { data } = await axios.post(`${this.gatewayUrl}/ai/chat`, body, {
          headers: {
            'X-Gateway-Secret': this.gatewaySecret,
            'Content-Type': 'application/json',
          },
          timeout: attempt.timeout,
        });

        if (data.success && data.result) {
          const latency = Date.now() - startMs;
          if (i > 0) {
            this.log.warn(`[text] OK on retry #${i} via ${data.provider}/${data.model} ${latency}ms`);
          } else {
            this.log.log(`[text] OK via ${data.provider}/${data.model} ${latency}ms`);
          }
          return data.result;
        }

        throw new Error(data.error || 'Empty response from AI Gateway');
      } catch (e: any) {
        if (e instanceof HttpException) throw e;

        const latencyMs = Date.now() - startMs;
        lastError = e.message || 'Unknown error';
        const modelLabel = attempt.model || 'default';

        if (i < attempts.length - 1) {
          this.log.warn(`[text] Attempt ${i + 1}/${attempts.length} failed (${modelLabel}, ${latencyMs}ms): ${lastError} → retrying`);
          // Небольшая пауза с jitter — не бьём прокси сразу же, даём ему «выдохнуть».
          await new Promise((r) => setTimeout(r, 250 + Math.random() * 350));
        } else {
          this.log.error(`[text] All ${attempts.length} attempts failed. Last: ${modelLabel} (${latencyMs}ms): ${lastError}`);
        }
      }
    }

    throw new HttpException(
      'AI временно недоступен. Попробуйте позже.',
      HttpStatus.BAD_GATEWAY,
    );
  }

  // ── JSON extraction ────────────────────────────────────────

  private extractJson(raw: string): string {
    const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fenceMatch) return fenceMatch[1].trim();

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
