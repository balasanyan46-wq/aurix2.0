import { Injectable, Inject, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import axios from 'axios';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import * as path from 'path';
import { PG_POOL } from '../database/database.module';
import { AiGatewayService } from './ai-gateway.service';

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
  url: string;
  meta: Record<string, unknown>;
}

@Injectable()
export class CoverService {
  private readonly logger = new Logger(CoverService.name);

  constructor(
    private readonly ai: AiGatewayService,
  ) {}

  /** Full pipeline: prompt → AI Gateway image → URL */
  async generate(params: CoverParams): Promise<CoverResult> {
    const { prompt, quality = 'high' } = params;

    this.logger.log(`[cover] generating (${prompt.length} chars, quality=${quality})`);

    try {
      const result = await this.ai.generate({
        type: 'image',
        prompt,
      });

      this.logger.log(`[cover] done (provider=${result.provider}, url=${result.content.slice(0, 80)})`);

      // Download image and serve from our domain to avoid CORS issues
      let finalUrl = result.content;
      try {
        const imgRes = await axios.get(result.content, { responseType: 'arraybuffer', timeout: 30000 });
        const fileName = `cover-${randomUUID()}.png`;
        const uploadDir = '/tmp/aurix-covers';
        if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
        const filePath = path.join(uploadDir, fileName);
        fs.writeFileSync(filePath, imgRes.data);

        // Copy to web-accessible directory
        const webDir = '/root/aurix/web/generated';
        if (!fs.existsSync(webDir)) fs.mkdirSync(webDir, { recursive: true });
        fs.copyFileSync(filePath, path.join(webDir, fileName));
        finalUrl = `https://aurixmusic.ru/generated/${fileName}`;
        this.logger.log(`[cover] saved locally: ${finalUrl}`);
      } catch (dlErr: any) {
        this.logger.warn(`[cover] download failed, using direct URL: ${dlErr.message}`);
      }

      return {
        ok: true,
        url: finalUrl,
        meta: {
          provider: result.provider,
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

  /** Simple pipeline: idea → AI prompt → AI Gateway image → content URL */
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
    });

    if (!result.content) {
      throw new HttpException('Image generation returned empty output', HttpStatus.BAD_GATEWAY);
    }

    this.logger.log(`[cover] image ready (provider=${result.provider})`);
    return { image: result.content, prompt };
  }
}
