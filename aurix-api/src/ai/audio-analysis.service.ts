import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import { execSync } from 'child_process';
import { writeFileSync, readFileSync, unlinkSync, existsSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import FormData = require('form-data');
import { AiGatewayService } from './ai-gateway.service';
import {
  MeasuredData,
  DerivedInsights,
  AiExplanation,
  TrackAnalysisResponse,
} from './analysis/analysis.dto';
import { deriveInsights } from './analysis/analysis-rule-engine';
import { buildAnalysisPrompt } from './analysis/analysis-prompt-builder';

@Injectable()
export class AudioAnalysisService {
  private readonly logger = new Logger(AudioAnalysisService.name);
  private readonly pythonUrl =
    process.env.AUDIO_ANALYSIS_URL || 'http://localhost:8001';

  constructor(private readonly ai: AiGatewayService) {}

  // ══════════════════════════════════════════════════════════════
  // MAIN PIPELINE: Python → Rule Engine → Single LLM call
  // ══════════════════════════════════════════════════════════════

  async analyzeTrack(
    file: Express.Multer.File,
    userLyrics?: string,
  ): Promise<TrackAnalysisResponse> {
    // Step 1: Extract measured data (Python service)
    const measured = await this.extractMeasuredData(file);

    // Resolve effective lyrics
    const rawLyrics = measured.transcript.text || userLyrics || null;
    const effectiveLyrics = rawLyrics && this.isLyricsUsable(rawLyrics) ? rawLyrics : null;

    if (rawLyrics && !effectiveLyrics) {
      this.logger.log('Transcript rejected (low quality / gibberish)');
    }

    // If user provided lyrics but whisper didn't find any, use user lyrics
    if (userLyrics && !measured.transcript.text) {
      const words = effectiveLyrics ? effectiveLyrics.split(/\s+/).length : 0;
      measured.transcript = {
        text: effectiveLyrics,
        language: null,
        confidence: 0.5,
        segment_count: 0,
        word_count: words,
        repeated_phrase_ratio: 0,
        language_confidence: 0,
        reliability_flags: ['user_provided'],
      };
    }

    // Step 2: Rule engine → derived insights (deterministic)
    const derived = deriveInsights(measured);

    this.logger.log(
      `Analysis: BPM=${measured.bpm.bpm}, key=${measured.key.key}, ` +
      `genre=${derived.genre}, hit=${derived.hit_score}, ` +
      `hook=${derived.hook_time}s, lufs=${measured.lufs}, ` +
      `confidence=${derived.confidence.overall_analysis_confidence}, ` +
      `insights=${derived.insights.length}`,
    );

    // Step 3: Single LLM call for explanation
    const aiExplanation = await this.generateExplanation(measured, derived, effectiveLyrics);

    return {
      measured_data: measured,
      derived_insights: derived,
      ai_explanation: aiExplanation,
    };
  }

  // ══════════════════════════════════════════════════════════════
  // STEP 1: Python service → MeasuredData
  // ══════════════════════════════════════════════════════════════

  private async extractMeasuredData(
    file: Express.Multer.File,
  ): Promise<MeasuredData> {
    const { buffer, filename, mimetype } = this.compressIfNeeded(file);
    const form = new FormData();
    form.append('file', buffer, { filename, contentType: mimetype });

    try {
      const { data } = await axios.post<MeasuredData>(
        `${this.pythonUrl}/analyze`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 120_000,
          maxContentLength: 200 * 1024 * 1024,
          maxBodyLength: 200 * 1024 * 1024,
        },
      );
      return data;
    } catch (error: any) {
      this.logger.error(
        `Python service error: ${error.message}`,
        error.response?.data,
      );

      if (error.response?.status && error.response.status < 500) {
        throw new HttpException(
          error.response.data?.detail || 'Audio file rejected',
          error.response.status,
        );
      }

      throw new HttpException(
        'Audio analysis service is temporarily unavailable. Please try again in a few seconds.',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // STEP 3: Single LLM call → AiExplanation
  // ══════════════════════════════════════════════════════════════

  private async generateExplanation(
    measured: MeasuredData,
    derived: DerivedInsights,
    lyrics: string | null,
  ): Promise<AiExplanation> {
    const { system, user } = buildAnalysisPrompt(measured, derived, lyrics);

    const raw = await this.ai.simpleChat(system, user, {
      maxTokens: 2000,
      temperature: 0.5,
      timeout: 45_000,
    });

    try {
      let cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replace(/^```\w*\n?/, '').replace(/\n?```$/, '');
      }
      const parsed = JSON.parse(cleaned);

      return {
        verdict: parsed.verdict || '',
        producer_notes: parsed.producer_notes || '',
        top_fixes: Array.isArray(parsed.top_fixes) ? parsed.top_fixes.slice(0, 5) : [],
        strengths: Array.isArray(parsed.strengths) ? parsed.strengths.slice(0, 5) : [],
        score: this.clamp(Number(parsed.score) || 5, 0, 10),
        viral_probability: this.clamp(Math.round(Number(parsed.viral_probability) || derived.hit_score * 0.9), 0, 100),
        improvement_prompt: parsed.improvement_prompt || '',
        tiktok_segment: parsed.tiktok_segment || undefined,
        lyrics_insight: lyrics ? (parsed.lyrics_insight || undefined) : undefined,
      };
    } catch {
      this.logger.warn('Failed to parse AI explanation JSON, using fallback');
      return {
        verdict: 'Analysis completed. AI explanation unavailable.',
        producer_notes: '',
        top_fixes: [],
        strengths: [],
        score: 5,
        viral_probability: Math.round(derived.hit_score * 0.9),
        improvement_prompt: '',
      };
    }
  }

  // ══════════════════════════════════════════════════════════════
  // COMPRESSION — large WAV/FLAC → MP3
  // ══════════════════════════════════════════════════════════════

  private compressIfNeeded(file: Express.Multer.File): { buffer: Buffer; filename: string; mimetype: string } {
    const name = (file.originalname || '').toLowerCase();
    const isLarge = file.buffer.length > 15 * 1024 * 1024;
    const isUncompressed = name.endsWith('.wav') || name.endsWith('.flac') || name.endsWith('.aiff');

    if (!isLarge || !isUncompressed) {
      return { buffer: file.buffer, filename: file.originalname || 'track.mp3', mimetype: file.mimetype || 'audio/mpeg' };
    }

    const id = Date.now().toString(36);
    const ext = name.split('.').pop() || 'wav';
    const inPath = join(tmpdir(), `aurix_in_${id}.${ext}`);
    const outPath = join(tmpdir(), `aurix_out_${id}.mp3`);

    try {
      writeFileSync(inPath, file.buffer);
      this.logger.log(`Compressing ${ext.toUpperCase()} ${(file.buffer.length / 1024 / 1024).toFixed(1)}MB → MP3`);
      execSync(`ffmpeg -i "${inPath}" -codec:a libmp3lame -b:a 192k -y "${outPath}" 2>/dev/null`, { timeout: 30000 });
      const mp3Buffer = readFileSync(outPath);
      this.logger.log(`Compressed: ${(mp3Buffer.length / 1024 / 1024).toFixed(1)}MB`);
      return { buffer: mp3Buffer, filename: 'track.mp3', mimetype: 'audio/mpeg' };
    } catch (e: any) {
      this.logger.warn(`Compression failed, using original: ${e.message}`);
      return { buffer: file.buffer, filename: file.originalname || 'track.wav', mimetype: file.mimetype || 'audio/wav' };
    } finally {
      try { if (existsSync(inPath)) unlinkSync(inPath); } catch {}
      try { if (existsSync(outPath)) unlinkSync(outPath); } catch {}
    }
  }

  // ══════════════════════════════════════════════════════════════
  // LYRICS VALIDATION
  // ══════════════════════════════════════════════════════════════

  private isLyricsUsable(text: string): boolean {
    const t = text.trim();
    if (t.length < 40) return false;

    const words = t.split(/\s+/);
    if (words.length < 8) return false;

    const realWords = words.filter(w => w.replace(/[^a-zA-Zа-яА-ЯёЁ]/g, '').length >= 3);
    if (realWords.length / words.length < 0.3) return false;

    const freq: Record<string, number> = {};
    for (const w of words) {
      const lw = w.toLowerCase().replace(/[^a-zA-Zа-яА-ЯёЁ]/g, '');
      if (lw.length < 2) continue;
      freq[lw] = (freq[lw] || 0) + 1;
    }
    const maxFreq = Math.max(...Object.values(freq), 0);
    if (maxFreq > words.length * 0.4) return false;

    const hasCyrillic = /[а-яА-ЯёЁ]{3,}/.test(t);
    const hasLatin = /[a-zA-Z]{3,}/.test(t);
    if (!hasCyrillic && !hasLatin) return false;

    return true;
  }

  // ══════════════════════════════════════════════════════════════
  // VOCAL PROCESSING — unchanged
  // ══════════════════════════════════════════════════════════════

  async processVocal(
    file: Express.Multer.File,
    preset = 'hit',
    autotune = 'off',
    strength = 0.5,
    key = 'C_major',
    style = 'none',
  ): Promise<Buffer> {
    const form = new FormData();
    form.append('file', file.buffer, {
      filename: file.originalname || 'vocal.wav',
      contentType: file.mimetype || 'audio/wav',
    });

    const params = new URLSearchParams({
      preset, autotune, strength: String(strength), key, style,
    });

    try {
      const { data } = await axios.post(
        `${this.pythonUrl}/process-vocal?${params}`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 60_000,
          maxContentLength: 100 * 1024 * 1024,
          maxBodyLength: 100 * 1024 * 1024,
          responseType: 'arraybuffer',
        },
      );
      this.logger.log(`Vocal processed: ${(data.length / 1024).toFixed(0)}KB, preset=${preset}`);
      return Buffer.from(data);
    } catch (e: any) {
      this.logger.error(`Vocal processing failed: ${e.message}`);
      throw new HttpException(
        'Vocal processing failed',
        HttpStatus.SERVICE_UNAVAILABLE,
      );
    }
  }

  async fullPipeline(
    beatFile: Express.Multer.File,
    vocalFile: Express.Multer.File,
    opts: { preset?: string; style?: string; autotune?: string; strength?: number; key?: string; target?: string },
  ): Promise<Buffer> {
    const form = new FormData();
    form.append('beat', beatFile.buffer, { filename: beatFile.originalname || 'beat.mp3', contentType: beatFile.mimetype || 'audio/mpeg' });
    form.append('vocal', vocalFile.buffer, { filename: vocalFile.originalname || 'vocal.webm', contentType: vocalFile.mimetype || 'audio/webm' });

    const params = new URLSearchParams({
      preset: opts.preset || 'hit',
      style: opts.style || 'wide_star',
      autotune: opts.autotune || 'on',
      strength: String(opts.strength || 0.5),
      key: opts.key || 'C_major',
      target: opts.target || 'spotify',
    });

    try {
      const { data } = await axios.post(
        `${this.pythonUrl}/full-pipeline?${params}`,
        form,
        { headers: form.getHeaders(), timeout: 120_000, maxContentLength: 200 * 1024 * 1024, maxBodyLength: 200 * 1024 * 1024, responseType: 'arraybuffer' },
      );
      this.logger.log(`Full pipeline done: ${(data.length / 1024).toFixed(0)}KB`);
      return Buffer.from(data);
    } catch (e: any) {
      this.logger.error(`Full pipeline failed: ${e.message}`);
      throw new HttpException('Processing failed', HttpStatus.SERVICE_UNAVAILABLE);
    }
  }

  private clamp(v: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, v));
  }
}
