import { Inject, Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { EdenAiService } from './eden-ai.service';

interface DnkAnswer {
  question_id: string;
  answer_type: string;
  answer_json: Record<string, any>;
}

const DNK_SYSTEM_PROMPT = `Ты — музыкальный продюсер и психолог-аналитик мирового уровня.

Твоя задача — определить DNK артиста на основе его ответов на серию вопросов.

Ты получаешь массив ответов артиста. Каждый ответ содержит:
- question_id: ID вопроса
- answer_type: тип (scale — шкала 1-5, forced_choice — выбор, sjt — ситуационное суждение, open — открытый)
- answer_json: ответ (value для scale, key для choice/sjt, text для open)

Проанализируй ответы и верни СТРОГО JSON без markdown, без комментариев.

Структура ответа:

{
  "axes": {
    "energy": <0-100>,
    "novelty": <0-100>,
    "darkness": <0-100>,
    "lyric_focus": <0-100>,
    "structure": <0-100>,
    "conflict_style": <0-100>,
    "publicness": <0-100>,
    "commercial_focus": <0-100>
  },
  "confidence": {
    "energy": <0.0-1.0>,
    "novelty": <0.0-1.0>,
    "darkness": <0.0-1.0>,
    "lyric_focus": <0.0-1.0>,
    "structure": <0.0-1.0>,
    "conflict_style": <0.0-1.0>,
    "publicness": <0.0-1.0>,
    "commercial_focus": <0.0-1.0>
  },
  "social_axes": {
    "warmth": <0-100>,
    "power": <0-100>,
    "edge": <0-100>,
    "clarity": <0-100>
  },
  "social_summary": {
    "magnets": ["что притягивает людей к артисту — 3-5 пунктов"],
    "repellers": ["что отталкивает — 3-5 пунктов"],
    "people_come_for": "одно предложение — за чем люди тянутся к этому артисту",
    "people_leave_when": "одно предложение — когда и почему отваливаются",
    "taboos": ["3-5 вещей, которые артисту категорически нельзя делать публично"],
    "scripts": {
      "hate_reply": ["2-3 примера как артист отвечает на хейт"],
      "interview_style": ["2-3 характеристики поведения на интервью"],
      "conflict_style": ["2-3 паттерна в конфликтах"],
      "teamwork_rule": ["2-3 правила работы в команде"]
    }
  },
  "passport_hero": {
    "hook": "одна фраза-зацепка, определяющая артиста",
    "how_people_feel_you": "2-3 предложения — как люди воспринимают артиста",
    "magnet": ["3-4 главных магнита артиста"],
    "repulsion": ["3-4 вещи, которые отталкивают"],
    "shadow": "теневая сторона артиста — 2-3 предложения",
    "taboo": ["3-4 табу для публичного образа"],
    "next_7_days": ["5-7 конкретных действий на ближайшую неделю"]
  },
  "profile_text": "развёрнутый текстовый профиль артиста, 3-5 абзацев",
  "profile_short": "короткий профиль, 2-3 предложения",
  "profile_full": "полный профиль, 5-8 абзацев с глубоким анализом",
  "recommendations": {
    "music": {
      "genre_direction": "рекомендация по жанру",
      "sound_palette": ["3-5 элементов саунда"],
      "bpm_range": "диапазон BPM",
      "references": ["3-5 референсов"],
      "avoid": ["что избегать в музыке"]
    },
    "content": {
      "platforms": ["приоритетные платформы"],
      "formats": ["форматы контента"],
      "frequency": "частота публикаций",
      "tone": "тон коммуникации",
      "avoid": ["что избегать в контенте"]
    },
    "behavior": {
      "public_style": "стиль публичного поведения",
      "conflict_strategy": "стратегия в конфликтах",
      "fan_interaction": "как общаться с фанатами",
      "growth_tactics": ["тактики роста"]
    },
    "visual": {
      "aesthetic": "визуальная эстетика",
      "color_palette": ["цвета"],
      "cover_style": "стиль обложек",
      "photo_direction": "направление фотосессий"
    }
  },
  "prompts": {
    "track_concept": "концепция следующего трека",
    "lyrics_seed": "затравка для текста",
    "cover_prompt": "промпт для генерации обложки",
    "reels_series": "идея серии Reels"
  },
  "tags": ["5-8 тегов, описывающих артиста"]
}

Требования:
— Все тексты на русском
— Будь конкретным и резким, без воды и банальностей
— Оси (axes) рассчитывай на основе ответов: scale напрямую влияет на значение, forced_choice и sjt определяют направление, open даёт качественную глубину
— confidence отражает насколько уверенно можно определить ось по имеющимся ответам
— profile_text и profile_full пиши как продюсер, который видит артиста насквозь
— recommendations должны быть нишевыми и конкретными, НЕ банальными
— passport_hero.hook — это одна убойная фраза, которая цепляет
— next_7_days — конкретные действия, готовые к выполнению`;

const HARD_STYLE_ADDON = `

ВАЖНО: Стиль "hard" — будь максимально жёстким, провокационным и честным.
Не щади чувства. Говори как продюсер, который видел тысячи артистов и не собирается льстить.
passport_hero.shadow должен быть особенно глубоким и болезненно точным.
recommendations должны быть радикальными.`;

@Injectable()
export class DnkService {
  private readonly logger = new Logger(DnkService.name);

  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ai: EdenAiService,
  ) {}

  async generateDnk(
    userId: string,
    answers: DnkAnswer[],
    styleLevel: string,
  ): Promise<Record<string, any>> {
    // 1. Create session
    const sessionRes = await this.pool.query(
      `INSERT INTO dnk_sessions (user_id, status, started_at)
       VALUES ($1, 'in_progress', now())
       RETURNING id`,
      [userId],
    );
    const sessionId = sessionRes.rows[0].id;

    // 2. Store answers
    for (const a of answers) {
      const mappedType = this.mapAnswerType(a.answer_type);
      await this.pool.query(
        `INSERT INTO dnk_answers (session_id, question_id, answer_type, answer_json)
         VALUES ($1, $2, $3, $4)
         ON CONFLICT (session_id, question_id) DO UPDATE SET answer_json = $4`,
        [sessionId, a.question_id, mappedType, JSON.stringify(a.answer_json)],
      );
    }

    // 3. Format answers for AI
    const answersText = answers
      .map((a) => {
        const val = a.answer_json;
        let readable: string;
        if (a.answer_type === 'scale') {
          readable = `value=${val.value}/5`;
        } else if (a.answer_type === 'forced_choice' || a.answer_type === 'sjt') {
          readable = `choice=${val.key}`;
        } else {
          readable = `text="${val.text || ''}"`;
        }
        return `- ${a.question_id} (${a.answer_type}): ${readable}`;
      })
      .join('\n');

    // 4. Call Eden AI
    let systemPrompt = DNK_SYSTEM_PROMPT;
    if (styleLevel === 'hard') {
      systemPrompt += HARD_STYLE_ADDON;
    }

    const userMessage = `Вот ответы артиста на интервью DNK:\n\n${answersText}\n\nПроанализируй и верни полный DNK профиль в JSON.`;

    let rawResult: string;
    try {
      rawResult = await this.ai.chat({
        message: userMessage,
        mode: 'dnk_full',
        contextPrompt: systemPrompt,
      });
    } catch (e) {
      this.logger.error('Eden AI DNK call failed', e);
      // Mark session as abandoned
      await this.pool.query(
        `UPDATE dnk_sessions SET status = 'abandoned' WHERE id = $1`,
        [sessionId],
      );
      throw new HttpException(
        'AI service unavailable, try again later',
        HttpStatus.BAD_GATEWAY,
      );
    }

    // 5. Parse result
    let parsed: Record<string, any>;
    try {
      parsed = JSON.parse(rawResult);
    } catch {
      this.logger.error('Failed to parse DNK JSON', rawResult.slice(0, 500));
      await this.pool.query(
        `UPDATE dnk_sessions SET status = 'abandoned' WHERE id = $1`,
        [sessionId],
      );
      throw new HttpException(
        'AI returned invalid format, try again',
        HttpStatus.BAD_GATEWAY,
      );
    }

    // 6. Store result in DB
    const axes = parsed.axes || {};
    const confidence = parsed.confidence || {};
    const socialAxes = parsed.social_axes || {};
    const profileText = parsed.profile_text || '';
    const recommendations = {
      ...parsed.recommendations,
      social_summary: parsed.social_summary,
      passport_hero: parsed.passport_hero,
      _profile_short: parsed.profile_short || '',
      _profile_full: parsed.profile_full || '',
      _social_axes: socialAxes,
    };
    const prompts = parsed.prompts || {};
    const rawFeatures = { tags: parsed.tags || [] };

    await this.pool.query(
      `INSERT INTO dnk_results
        (session_id, axes, confidence, social_axes, profile_text, recommendations, prompts, raw_features, regen_count)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0)`,
      [
        sessionId,
        JSON.stringify(axes),
        JSON.stringify(confidence),
        JSON.stringify(socialAxes),
        profileText,
        JSON.stringify(recommendations),
        JSON.stringify(prompts),
        JSON.stringify(rawFeatures),
      ],
    );

    // 7. Mark session finished
    await this.pool.query(
      `UPDATE dnk_sessions SET status = 'finished', finished_at = now() WHERE id = $1`,
      [sessionId],
    );

    // 8. Return full result to Flutter
    return {
      status: 'ready',
      session_id: sessionId,
      axes,
      confidence,
      social_axes: socialAxes,
      social_summary: parsed.social_summary || {},
      passport_hero: parsed.passport_hero || {},
      profile_text: profileText,
      profile_short: parsed.profile_short || '',
      profile_full: parsed.profile_full || '',
      recommendations: parsed.recommendations || {},
      prompts,
      tags: parsed.tags || [],
      regen_count: 0,
    };
  }

  private mapAnswerType(type: string): string {
    switch (type) {
      case 'scale':
        return 'scale';
      case 'forced_choice':
        return 'choice';
      case 'sjt':
        return 'sjt';
      case 'open':
        return 'open_text';
      default:
        return 'open_text';
    }
  }
}
