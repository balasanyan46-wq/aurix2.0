import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import Replicate from 'replicate';
import { DeepSeekService } from './deepseek.service';
import axios from 'axios';

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
  private replicate: Replicate;

  constructor(private readonly deepseek: DeepSeekService) {
    const token = process.env.REPLICATE_API_TOKEN;
    if (!token) {
      this.logger.warn('REPLICATE_API_TOKEN is not set — cover generation will fail');
    }
    this.replicate = new Replicate({ auth: token || '' });
  }

  /** Full pipeline: prompt → Replicate → base64 PNG */
  async generate(params: CoverParams): Promise<CoverResult> {
    const { prompt, size = '1024x1024', quality = 'high' } = params;

    this.logger.log(`[cover] generating (${prompt.length} chars, size=${size}, quality=${quality})`);

    try {
      const output = await this.replicate.run('black-forest-labs/flux-1.1-pro', {
        input: {
          prompt,
          aspect_ratio: '1:1',
          output_format: 'png',
          safety_tolerance: 2,
        },
      });

      // flux-1.1-pro returns a URL (string or FileOutput)
      const imageUrl = typeof output === 'string' ? output : String(output);

      if (!imageUrl || imageUrl === 'undefined') {
        throw new Error('Replicate returned empty output');
      }

      this.logger.log(`[cover] image generated, downloading from Replicate…`);

      // Download and convert to base64
      const imgResponse = await axios.get(imageUrl, {
        responseType: 'arraybuffer',
        timeout: 60_000,
      });

      const b64 = Buffer.from(imgResponse.data).toString('base64');

      this.logger.log(`[cover] done (${Math.round(b64.length / 1024)}KB base64)`);

      return {
        ok: true,
        b64_png: b64,
        meta: {
          model: 'flux-1.1-pro',
          size,
          quality,
          style_preset: params.style_preset ?? null,
          prompt_length: prompt.length,
        },
      };
    } catch (error) {
      if (error instanceof HttpException) throw error;

      this.logger.error('[cover] error:', error?.toString());

      throw new HttpException(
        'Ошибка генерации обложки',
        HttpStatus.BAD_GATEWAY,
      );
    }
  }

  /** Simple pipeline: idea → DeepSeek prompt → Replicate → URL */
  async generateFromIdea(idea: string): Promise<{ image: string; prompt: string }> {
    this.logger.log('[cover] generating prompt from idea…');

    const prompt = await this.deepseek.chat({
      message: idea,
      mode: 'chat',
      history: [],
      contextPrompt: COVER_PROMPT_INSTRUCTION,
    });

    this.logger.log(`[cover] prompt ready (${prompt.length} chars)`);

    const output = await this.replicate.run('black-forest-labs/flux-1.1-pro', {
      input: {
        prompt,
        aspect_ratio: '1:1',
        output_format: 'png',
        safety_tolerance: 2,
      },
    });

    const image = typeof output === 'string' ? output : String(output);

    if (!image || image === 'undefined') {
      throw new HttpException('Replicate returned empty output', HttpStatus.BAD_GATEWAY);
    }

    this.logger.log(`[cover] image ready → ${image.slice(0, 80)}…`);
    return { image, prompt };
  }
}
