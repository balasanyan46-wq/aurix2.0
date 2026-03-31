import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import { EdenAiService } from './eden-ai.service';

const COVER_PROMPT_INSTRUCTION = `Ты — арт-директор музыкального лейбла.

Задача: по описанию идеи от артиста сгенерировать prompt для нейросети, которая создаёт обложки альбомов/синглов.

Требования к prompt:
— На английском языке
— Максимум 200 слов
— Описывает визуальный стиль, цветовую палитру, композицию, настроение
— НЕ содержит текст/надписи/буквы на обложке
— Стиль: современный, editorial, высокое качество
— Формат: квадратная обложка альбома, 1:1

Ответь ТОЛЬКО prompt-ом. Без пояснений. Без кавычек. Просто текст prompt-а.`;

interface CoverParams {
  prompt: string;
  strict_prompt?: boolean;
  negative_prompt?: string;
  follow_prompt_strength?: number;
  safe_zone_guide?: boolean;
  style_preset?: string;
  color_profile?: string;
  size?: string;
  quality?: string;
  output_format?: string;
  background?: string;
  allow_text?: boolean;
  releaseId?: string;
  userId?: string;
}

export interface CoverResult {
  ok: boolean;
  b64_png: string;
  meta: Record<string, unknown>;
}

@Injectable()
export class CoverService {
  private readonly logger = new Logger(CoverService.name);

  constructor(private readonly ai: EdenAiService) {}

  /** Full pipeline: prompt → Eden AI image → base64 PNG */
  async generate(params: CoverParams): Promise<CoverResult> {
    const { prompt, size = '1024x1024', quality = 'high' } = params;

    this.logger.log(`[cover] generating (${prompt.length} chars, size=${size}, quality=${quality})`);

    try {
      const result = await this.ai.generate({
        type: 'image',
        prompt,
        resolution: size,
      });

      // result.content is either a URL or a data: URI with base64
      let b64: string;

      if (result.content.startsWith('data:')) {
        // Extract base64 from data URI
        b64 = result.content.split(',')[1] || '';
      } else {
        // It's a URL — download and convert to base64
        this.logger.log(`[cover] downloading from ${result.provider}…`);
        const imgResponse = await axios.get(result.content, {
          responseType: 'arraybuffer',
          timeout: 60_000,
        });
        b64 = Buffer.from(imgResponse.data).toString('base64');
      }

      this.logger.log(`[cover] done (${Math.round(b64.length / 1024)}KB base64, provider=${result.provider})`);

      return {
        ok: true,
        b64_png: b64,
        meta: {
          provider: result.provider,
          size,
          quality,
          style_preset: params.style_preset ?? null,
          prompt_length: prompt.length,
        },
      };
    } catch (error) {
      if (error instanceof HttpException) throw error;
      this.logger.error('[cover] error:', error?.toString());
      throw new HttpException('Ошибка генерации обложки', HttpStatus.BAD_GATEWAY);
    }
  }

  /** Simple pipeline: idea → AI prompt → Eden AI image → content URL */
  async generateFromIdea(idea: string): Promise<{ image: string; prompt: string }> {
    this.logger.log('[cover] generating prompt from idea…');

    const prompt = await this.ai.chat({
      message: idea,
      mode: 'chat',
      history: [],
      contextPrompt: COVER_PROMPT_INSTRUCTION,
    });

    this.logger.log(`[cover] prompt ready (${prompt.length} chars)`);

    const result = await this.ai.generate({
      type: 'image',
      prompt,
      resolution: '1024x1024',
    });

    if (!result.content) {
      throw new HttpException('Image generation returned empty output', HttpStatus.BAD_GATEWAY);
    }

    this.logger.log(`[cover] image ready (provider=${result.provider})`);
    return { image: result.content, prompt };
  }
}
