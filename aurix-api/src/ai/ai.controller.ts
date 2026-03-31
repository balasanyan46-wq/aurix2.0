import {
  Controller,
  Get,
  Post,
  Query,
  Body,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  HttpException,
  HttpStatus,
  Inject,
} from '@nestjs/common';
import { Pool } from 'pg';
import { PG_POOL } from '../database/database.module';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreditGuard, CreditAction } from '../billing/credit.guard';
import { CreditsService } from '../billing/credits.service';
import { EdenAiService } from './eden-ai.service';
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
const MAX_MESSAGE_LENGTH = 4000;

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
    private readonly ai: EdenAiService,
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

  @Throttle({ default: { ttl: 60000, limit: 5 } })
  @Post('generate')
  async generate(
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
    return { ...result, credits: req.creditSpend };
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
    });
  }
}
