import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios, { AxiosError } from 'axios';
import { AiProvider, ChatMessage, ChatParams, AiMode } from './ai-provider.interface';

interface DeepSeekChoice {
  message: { role: string; content: string };
}

interface DeepSeekResponse {
  choices: DeepSeekChoice[];
}

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

// ── Analyze mode — the new main mode ─────────────────────────

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

// ── Legacy mode instructions (kept for backward compat) ──────

const MODE_INSTRUCTIONS: Record<AiMode, string | null> = {
  chat: null,
  dnk_full: null, // Full DNK — system prompt provided via contextPrompt
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
export class DeepSeekService implements AiProvider {
  private readonly logger = new Logger(DeepSeekService.name);
  private readonly apiUrl = 'https://api.deepseek.com/v1/chat/completions';
  private readonly model = 'deepseek-chat';

  private get apiKey(): string {
    const key = process.env.DEEPSEEK_API_KEY;
    if (!key) {
      throw new HttpException(
        'DEEPSEEK_API_KEY is not configured',
        HttpStatus.INTERNAL_SERVER_ERROR,
      );
    }
    return key;
  }

  async chat(params: ChatParams): Promise<string> {
    const { message, mode = 'chat', history, contextPrompt } = params;

    // Build system prompt: base + user context (never user-supplied)
    let systemPrompt = SYSTEM_PROMPT;
    if (contextPrompt) {
      systemPrompt += `\n\n${contextPrompt}`;
    }

    const modeInstruction = MODE_INSTRUCTIONS[mode];

    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
    ];

    if (history && history.length > 0) {
      for (const msg of history) {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({
            role: msg.role as 'user' | 'assistant',
            content: msg.content,
          });
        }
      }
    }

    const userContent = modeInstruction
      ? `${modeInstruction}\n\n---\n\nЗапрос артиста: ${message}`
      : message;

    messages.push({ role: 'user', content: userContent });

    const isStructured = mode === 'analyze' || mode === 'ideas' || mode === 'reels' || mode === 'dnk' || mode === 'dnk_full';
    const temperature = isStructured ? 0.7 : 0.9;
    const maxTokens = mode === 'dnk_full' ? 8000 : mode === 'analyze' ? 4000 : mode === 'lyrics' ? 2000 : isStructured ? 3000 : 1500;

    try {
      const { data } = await axios.post<DeepSeekResponse>(
        this.apiUrl,
        {
          model: this.model,
          messages,
          temperature,
          max_tokens: maxTokens,
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
          timeout: mode === 'dnk_full' ? 120_000 : 60_000,
        },
      );

      const content = data.choices?.[0]?.message?.content;
      if (!content) {
        throw new Error('Empty response from DeepSeek');
      }

      if (isStructured) {
        return this.extractJson(content);
      }

      return content;
    } catch (error) {
      if (error instanceof HttpException) throw error;

      const axiosErr = error as AxiosError;
      if (axiosErr.response?.data) {
        this.logger.error('DeepSeek API error:', axiosErr.response.data);
      } else {
        this.logger.error('DeepSeek request failed:', axiosErr.message);
      }

      throw new HttpException(
        'AI service unavailable',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  private extractJson(raw: string): string {
    const fenceMatch = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
    if (fenceMatch) {
      return fenceMatch[1].trim();
    }

    const trimmed = raw.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        JSON.parse(trimmed);
        return trimmed;
      } catch {
        // Fall through
      }
    }

    return raw;
  }
}
