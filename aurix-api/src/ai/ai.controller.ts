import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Req,
  Res,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  UploadedFiles,
  HttpException,
  HttpStatus,
  Inject,
  Param,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { FileInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreditGuard, CreditAction } from '../billing/credit.guard';
import { CreditsService } from '../billing/credits.service';
import { AiGatewayService } from './ai-gateway.service';
import { DnkService } from './dnk.service';
import { DnkTestsService } from './dnk-tests.service';
import { AiContextService, ContextMode } from './ai-context.service';
import { AiProfileService } from './ai-profile.service';
import { CoverService } from './cover.service';
import { AudioAnalysisService } from './audio-analysis.service';
import type { AiMode, AiGenerationType } from './ai-provider.interface';
import { GENERATION_CREDIT_ACTIONS } from './ai-provider.interface';

const VALID_MODES = new Set<AiMode>([
  'chat', 'lyrics', 'ideas', 'reels', 'dnk', 'dnk_full', 'analyze',
]);

const VALID_CONTEXT_MODES = new Set<ContextMode>(['full', 'no_dnk', 'clean']);
const VALID_GEN_TYPES = new Set<AiGenerationType>(['text', 'image', 'video', 'audio']);

const MAX_HISTORY_LENGTH = 20;
const MAX_MESSAGE_LENGTH = 8000;

interface ChatBody {
  message: string;
  mode?: string;
  history?: Array<{ role: string; content: string }>;
  locale?: string;
  page?: string;
  context_mode?: string;
  track_id?: string;
}

@UseGuards(JwtAuthGuard)
@Controller('api/ai')
export class AiController {
  constructor(
    @Inject(PG_POOL) private readonly pool: Pool,
    private readonly ai: AiGatewayService,
    private readonly credits: CreditsService,
    private readonly dnkSvc: DnkService,
    private readonly dnkTestsSvc: DnkTestsService,
    private readonly ctx: AiContextService,
    private readonly profileSvc: AiProfileService,
    private readonly coverSvc: CoverService,
    private readonly audioAnalysis: AudioAnalysisService,
  ) {}

  // ── Text chat ──────────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 10 } })
  @Post('chat')
  @CreditAction('ai_chat')
  @UseGuards(CreditGuard)
  async chat(
    @Req() req: any,
    @Body() body: ChatBody,
  ): Promise<{ reply: string; credits?: any }> {
    const message = body.message?.trim();
    if (!message) {
      throw new HttpException('message is required', HttpStatus.BAD_REQUEST);
    }
    if (message.length > MAX_MESSAGE_LENGTH) {
      throw new HttpException(
        `message too long (max ${MAX_MESSAGE_LENGTH} chars)`,
        HttpStatus.BAD_REQUEST,
      );
    }

    const mode: AiMode = VALID_MODES.has(body.mode as AiMode)
      ? (body.mode as AiMode)
      : 'chat';

    const contextMode: ContextMode = VALID_CONTEXT_MODES.has(
      body.context_mode as ContextMode,
    )
      ? (body.context_mode as ContextMode)
      : 'full';

    const history = (body.history || [])
      .filter((m) => m.role === 'user' || m.role === 'assistant')
      .slice(-MAX_HISTORY_LENGTH)
      .map((m) => ({
        role: m.role,
        content: String(m.content || '').slice(0, MAX_MESSAGE_LENGTH),
      }));

    const userId = req.user?.id;
    let contextPrompt = '';
    if (userId && contextMode !== 'clean') {
      const userContext = await this.ctx.buildContext(userId, contextMode, body.track_id);
      contextPrompt = this.ctx.contextToPrompt(userContext);
    }

    const reply = await this.ai.chat({ message, mode, history, contextPrompt });
    return { reply, credits: req.creditSpend };
  }

  // ── Unified generate (image / video / audio / text) ────────

  @Post('generate')
  @Throttle({ default: { ttl: 60000, limit: 5 } })
  async generateMedia(
    @Req() req: any,
    @Body() body: {
      type?: string;
      prompt?: string;
      resolution?: string;
      language?: string;
      voice?: string;
    },
  ) {
    const prompt = body.prompt?.trim();
    if (!prompt) {
      throw new HttpException('prompt is required', HttpStatus.BAD_REQUEST);
    }
    if (prompt.length > MAX_MESSAGE_LENGTH) {
      throw new HttpException(`prompt too long (max ${MAX_MESSAGE_LENGTH} chars)`, HttpStatus.BAD_REQUEST);
    }

    const type: AiGenerationType = VALID_GEN_TYPES.has(body.type as AiGenerationType)
      ? (body.type as AiGenerationType)
      : 'text';

    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }

    // Per-type credit deduction
    const actionKey = GENERATION_CREDIT_ACTIONS[type];
    const spendResult = await this.credits.spend(userId, actionKey);
    if (!spendResult.ok) {
      throw new HttpException(
        {
          code: 'NO_CREDITS',
          message: 'Недостаточно кредитов',
          balance: spendResult.balance,
          cost: spendResult.cost,
        },
        HttpStatus.PAYMENT_REQUIRED,
      );
    }

    const result = await this.ai.generate({
      type,
      prompt,
      userId,
      resolution: body.resolution,
      language: body.language,
      voice: body.voice,
    });

    return {
      ...result,
      credits: {
        cost: spendResult.cost,
        balance: spendResult.balance,
        transactionId: spendResult.transactionId,
      },
    };
  }

  // ── DNK Artist ─────────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('dnk')
  @CreditAction('ai_chat')
  @UseGuards(CreditGuard)
  async dnk(
    @Req() req: any,
    @Body() body: {
      answers: Array<{
        question_id: string;
        answer_type: string;
        answer_json: Record<string, any>;
      }>;
      style_level?: string;
    },
  ) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }
    if (!body.answers || !Array.isArray(body.answers) || body.answers.length < 10) {
      throw new HttpException('at least 10 answers are required', HttpStatus.BAD_REQUEST);
    }

    const result = await this.dnkSvc.generateDnk(userId, body.answers, body.style_level || 'normal');
    return { ...result, credits: req.creditSpend };
  }

  @Get('dnk-results/latest')
  async getLatestDnkResult(@Req() req: any) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }
    const { rows } = await this.pool.query(
      `SELECT dr.*, ds.user_id, ds.id as session_id
       FROM dnk_results dr
       JOIN dnk_sessions ds ON ds.id = dr.session_id
       WHERE ds.user_id = $1 AND ds.status = 'finished'
       ORDER BY dr.created_at DESC LIMIT 1`,
      [userId],
    );
    return rows[0] || null;
  }

  @Get('dnk-answers')
  async getDnkAnswers(@Req() req: any, @Query('session_id') sessionId: string) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }
    if (!sessionId) {
      throw new HttpException('session_id is required', HttpStatus.BAD_REQUEST);
    }
    const { rows: sessions } = await this.pool.query(
      `SELECT id FROM dnk_sessions WHERE id = $1 AND user_id = $2`,
      [sessionId, userId],
    );
    if (sessions.length === 0) {
      throw new HttpException('session not found', HttpStatus.NOT_FOUND);
    }
    const { rows } = await this.pool.query(
      `SELECT question_id, answer_type, answer_json FROM dnk_answers WHERE session_id = $1`,
      [sessionId],
    );
    return rows;
  }

  // ── DNK Tests ──────────────────────────────────────────────

  @Get('dnk-tests/catalog')
  async dnkTestsCatalog() {
    return this.dnkTestsSvc.getCatalog();
  }

  @Post('dnk-tests/start')
  async dnkTestsStart(@Req() req: any, @Body() body: { test_slug: string }) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    if (!body.test_slug) throw new HttpException('test_slug is required', HttpStatus.BAD_REQUEST);
    return this.dnkTestsSvc.startSession(userId, body.test_slug);
  }

  @Post('dnk-tests/answer')
  async dnkTestsAnswer(
    @Req() req: any,
    @Body() body: { session_id: string; question_id: string; answer_type: string; answer_json: Record<string, any> },
  ) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    return this.dnkTestsSvc.submitAnswer(userId, body.session_id, body.question_id, body.answer_type, body.answer_json);
  }

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('dnk-tests/finish')
  @CreditAction('ai_chat')
  @UseGuards(CreditGuard)
  async dnkTestsFinish(@Req() req: any, @Body() body: { session_id: string }) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    if (!body.session_id) throw new HttpException('session_id is required', HttpStatus.BAD_REQUEST);
    const result = await this.dnkTestsSvc.finish(userId, body.session_id);
    return { ...result, credits: req.creditSpend };
  }

  @Get('dnk-tests/result')
  async dnkTestsResult(
    @Req() req: any,
    @Query('session_id') sessionId?: string,
    @Query('result_id') resultId?: string,
  ) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    return this.dnkTestsSvc.getResult(userId, sessionId, resultId);
  }

  @Get('dnk-tests/progress')
  async dnkTestsProgress(@Req() req: any) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    return this.dnkTestsSvc.getProgress(userId);
  }

  // ── Cover ──────────────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('cover')
  @CreditAction('ai_cover')
  @UseGuards(CreditGuard)
  async cover(@Req() req: any, @Body() body: Record<string, any>) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }

    const prompt = body.prompt?.toString()?.trim();
    if (!prompt) {
      throw new HttpException('prompt is required', HttpStatus.BAD_REQUEST);
    }
    if (prompt.length > 8000) {
      throw new HttpException('prompt too long', HttpStatus.BAD_REQUEST);
    }

    if (body.releaseId) {
      const { rows } = await this.pool.query(
        `SELECT r.id FROM releases r
         JOIN artists a ON a.id = r.artist_id
         WHERE r.id = $1 AND a.user_id = $2`,
        [body.releaseId, userId],
      );
      if (rows.length === 0) {
        throw new HttpException('release not found or not yours', HttpStatus.FORBIDDEN);
      }
    }

    return this.coverSvc.generate({
      prompt,
      strict_prompt: body.strict_prompt,
      negative_prompt: body.negative_prompt,
      follow_prompt_strength: body.follow_prompt_strength,
      safe_zone_guide: body.safe_zone_guide,
      style_preset: body.style_preset,
      color_profile: body.color_profile,
      size: body.size,
      quality: body.quality,
      output_format: body.output_format,
      background: body.background,
      allow_text: body.allow_text,
      releaseId: body.releaseId,
      userId,
    });
  }

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('generate-cover')
  @CreditAction('ai_cover')
  @UseGuards(CreditGuard)
  async generateCover(
    @Body() body: { idea?: string },
  ): Promise<{ image: string; prompt: string }> {
    const idea = body.idea?.trim();
    if (!idea) {
      throw new HttpException('idea is required', HttpStatus.BAD_REQUEST);
    }
    if (idea.length > 2000) {
      throw new HttpException('idea too long (max 2000 chars)', HttpStatus.BAD_REQUEST);
    }
    return this.coverSvc.generateFromIdea(idea);
  }

  // ── Analytics insights (free — not credit-gated) ───────────
  // Получает сводку по статистике артиста и возвращает советы от AI.

  @Throttle({ default: { ttl: 60000, limit: 10 } })
  @Post('analyze-stats')
  async analyzeStats(
    @Req() req: any,
    @Body() body: {
      total_streams?: number;
      total_revenue?: number;
      currency?: string;
      total_releases?: number;
      period_days?: number;
      top_platforms?: Array<{ name: string; streams: number; revenue: number }>;
      top_countries?: Array<{ name: string; streams: number; revenue: number }>;
      top_tracks?: Array<{ title: string; streams: number; revenue: number }>;
      usage_types?: Array<{ name: string; revenue: number }>;
    },
  ): Promise<{ insights: string }> {
    const userId = req.user?.id;

    const system = `Ты — продюсер-аналитик. Твоя задача — посмотреть статистику релизов артиста и дать короткие, конкретные, применимые советы.

Стиль:
— Без воды и банальностей
— Максимум конкретики (названия платформ, стран, треков, % цифры)
— Говори как наставник артисту, который смотрит его цифры впервые
— На русском

Ответ СТРОГО в JSON:
{
  "summary": "1–2 предложения — что в цифрах главное",
  "strengths": ["2–3 сильных стороны с конкретикой: '82% дохода — Яндекс Музыка, это твоя опора'"],
  "issues": ["2–3 проблемы или упущенных возможности"],
  "actions": ["3–5 конкретных действий: 'Запости превью в TikTok для трека X, он даёт 40% дохода'"],
  "next_step": "Одно главное следующее действие"
}`;

    const lines: string[] = ['СТАТИСТИКА АРТИСТА:'];
    const cs = body.currency === 'RUB' ? '₽' : '$';
    if (body.total_streams != null) lines.push(`Всего стримов: ${body.total_streams}`);
    if (body.total_revenue != null) lines.push(`Общий доход: ${cs}${body.total_revenue.toFixed(2)}`);
    if (body.total_releases != null) lines.push(`Релизов: ${body.total_releases}`);
    if (body.period_days != null) lines.push(`Период данных: ${body.period_days} дней`);

    if (body.top_platforms?.length) {
      lines.push('', 'ТОП ПЛАТФОРМ:');
      for (const p of body.top_platforms.slice(0, 8)) {
        lines.push(`  • ${p.name}: ${p.streams} стримов, ${cs}${p.revenue.toFixed(2)}`);
      }
    }
    if (body.top_countries?.length) {
      lines.push('', 'ТОП СТРАН:');
      for (const c of body.top_countries.slice(0, 8)) {
        lines.push(`  • ${c.name}: ${c.streams} стримов, ${cs}${c.revenue.toFixed(2)}`);
      }
    }
    if (body.top_tracks?.length) {
      lines.push('', 'ТОП ТРЕКОВ:');
      for (const t of body.top_tracks.slice(0, 8)) {
        lines.push(`  • "${t.title}": ${t.streams} стримов, ${cs}${t.revenue.toFixed(2)}`);
      }
    }
    if (body.usage_types?.length) {
      lines.push('', 'ТИПЫ ИСПОЛЬЗОВАНИЯ:');
      for (const u of body.usage_types.slice(0, 6)) {
        lines.push(`  • ${u.name}: ${cs}${u.revenue.toFixed(2)}`);
      }
    }

    // Добавим контекст профиля (DNK / персональные данные)
    try {
      if (userId) {
        const ctx = await this.ctx.buildContext(userId, 'full');
        const ctxPrompt = this.ctx.contextToPrompt(ctx);
        if (ctxPrompt) lines.push('', 'КОНТЕКСТ АРТИСТА:', ctxPrompt);
      }
    } catch {}

    const userMessage = lines.join('\n');

    const reply = await this.ai.simpleChat(system, userMessage, {
      maxTokens: 1200,
      temperature: 0.6,
      timeout: 60_000,
    });

    // Парсер JSON вынимает структуру, клиент дальше её рендерит
    return { insights: reply };
  }

  // ── Track analysis ─────────────────────────────────────────

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('analyze-track')
  @CreditAction('ai_hit_predictor')
  @UseGuards(CreditGuard)
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 100 * 1024 * 1024 },
      fileFilter: (_req, file, cb) => {
        if (!file.mimetype.startsWith('audio/')) {
          return cb(
            new HttpException('only audio files allowed', HttpStatus.BAD_REQUEST),
            false,
          );
        }
        cb(null, true);
      },
    }),
  )
  async analyzeTrack(
    @Req() req: any,
    @UploadedFile() file: Express.Multer.File,
    @Body() body: { lyrics?: string },
  ) {
    if (!file) {
      throw new HttpException('audio file is required', HttpStatus.BAD_REQUEST);
    }
    const result = await this.audioAnalysis.analyzeTrack(file, body.lyrics?.trim() || undefined);

    // Save to history
    const userId = req.user?.id;
    if (userId) {
      try {
        await this.pool.query(
          `INSERT INTO track_analyses (user_id, filename, genre, bpm, key, duration, hit_score, score, viral_probability, audio_metrics, lyrics_analysis, ai_analysis, lyrics)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
          [
            userId,
            file.originalname || 'track',
            result.derived_insights.genre,
            result.measured_data.bpm.bpm,
            result.measured_data.key.key,
            result.measured_data.duration,
            result.derived_insights.hit_score,
            result.ai_explanation.score,
            result.ai_explanation.viral_probability,
            JSON.stringify(result.measured_data),
            JSON.stringify(result.derived_insights),
            JSON.stringify(result.ai_explanation),
            result.measured_data.transcript.text,
          ],
        );
      } catch (e: any) {
        // Non-fatal — don't fail the response
      }
    }

    return { ...result, credits: req.creditSpend };
  }

  // ── AI Vocal Processing ────────────────────────────────────

  @Post('process-vocal')
  @UseInterceptors(
    FileInterceptor('file', {
      limits: { fileSize: 100 * 1024 * 1024 },
    }),
  )
  async processVocal(
    @Req() req: any,
    @UploadedFile() file: Express.Multer.File,
    @Res() res: any,
    @Query('preset') qPreset?: string,
    @Query('autotune') qAutotune?: string,
    @Query('strength') qStrength?: string,
    @Query('key') qKey?: string,
    @Query('style') qStyle?: string,
  ) {
    if (!file) {
      throw new HttpException('audio file is required', HttpStatus.BAD_REQUEST);
    }
    const preset = qPreset || 'hit';
    const autotune = qAutotune || 'off';
    const strength = parseFloat(qStrength || '0.5');
    const key = qKey || 'C_major';
    const style = qStyle || 'none';
    const processed = await this.audioAnalysis.processVocal(file, preset, autotune, strength, key, style);
    res.set({
      'Content-Type': 'audio/wav',
      'Content-Disposition': 'attachment; filename="processed.wav"',
      'Content-Length': processed.length,
    });
    res.send(processed);
  }

  // ── Full Pipeline (vocal + beat → processed + mixed + mastered) ───

  @Post('full-pipeline')
  @UseInterceptors(FileFieldsInterceptor([
    { name: 'beat', maxCount: 1 },
    { name: 'vocal', maxCount: 1 },
  ], { limits: { fileSize: 100 * 1024 * 1024 } }))
  async fullPipeline(
    @Req() req: any,
    @UploadedFiles() files: { beat?: Express.Multer.File[]; vocal?: Express.Multer.File[] },
    @Res() res: any,
    @Query('style') style?: string,
    @Query('autotune') autotune?: string,
    @Query('strength') strength?: string,
    @Query('key') key?: string,
    @Query('target') target?: string,
  ) {
    const beat = files.beat?.[0];
    const vocal = files.vocal?.[0];
    if (!beat || !vocal) throw new HttpException('beat and vocal files required', HttpStatus.BAD_REQUEST);

    const processed = await this.audioAnalysis.fullPipeline(beat, vocal, {
      style: style || 'wide_star',
      autotune: autotune || 'on',
      strength: parseFloat(strength || '0.5'),
      key: key || 'C_major',
      target: target || 'spotify',
    });
    res.set({ 'Content-Type': 'audio/wav', 'Content-Disposition': 'attachment; filename="final.wav"', 'Content-Length': processed.length });
    res.send(processed);
  }

  // ── Track analysis history ────────────────────────────────

  @Get('analyses')
  async listAnalyses(@Req() req: any) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
    const { rows } = await this.pool.query(
      `SELECT id, filename, genre, bpm, key, duration, hit_score, score, viral_probability, created_at
       FROM track_analyses WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [userId],
    );
    return rows;
  }

  @Get('analyses/:id')
  async getAnalysis(@Req() req: any, @Param('id') id: string) {
    const userId = req.user?.id;
    if (!userId) throw new HttpException('Unauthorized', HttpStatus.UNAUTHORIZED);
    const { rows } = await this.pool.query(
      `SELECT * FROM track_analyses WHERE id = $1 AND user_id = $2`,
      [id, userId],
    );
    if (!rows.length) throw new HttpException('Not found', HttpStatus.NOT_FOUND);
    const row = rows[0];

    // Support both old and new format
    const isNewFormat = row.audio_metrics?.bpm?.bpm !== undefined;
    if (isNewFormat) {
      return {
        measured_data: row.audio_metrics,
        derived_insights: row.lyrics_analysis,
        ai_explanation: typeof row.ai_analysis === 'string' ? JSON.parse(row.ai_analysis) : row.ai_analysis,
        filename: row.filename,
        createdAt: row.created_at,
      };
    }

    // Legacy format fallback
    return {
      audioMetrics: row.audio_metrics,
      lyricsAnalysis: row.lyrics_analysis,
      aiAnalysis: typeof row.ai_analysis === 'string' ? row.ai_analysis : JSON.stringify(row.ai_analysis),
      score: row.score,
      hitScore: row.hit_score,
      viralProbability: row.viral_probability,
      genre: row.genre,
      lyrics: row.lyrics,
      filename: row.filename,
      createdAt: row.created_at,
    };
  }

  // ── AI Profile ─────────────────────────────────────────────

  @Get('profile')
  async getProfile(@Req() req: any) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }
    return (await this.profileSvc.get(userId)) || {};
  }

  @Post('profile')
  async upsertProfile(
    @Req() req: any,
    @Body() body: {
      name?: string;
      genre?: string;
      mood?: string;
      references_list?: string[];
      goals?: string[];
      style_description?: string;
      goal?: string;
    },
  ) {
    const userId = req.user?.id;
    if (!userId) {
      throw new HttpException('auth required', HttpStatus.UNAUTHORIZED);
    }
    return this.profileSvc.upsert(userId, {
      name: body.name?.trim(),
      genre: body.genre?.trim(),
      mood: body.mood?.trim(),
      references_list: body.references_list,
      goals: body.goals,
      style_description: body.style_description?.trim(),
      goal: body.goal?.trim(),
    });
  }
}
