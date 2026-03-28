import { Injectable, Logger, HttpException, HttpStatus } from '@nestjs/common';
import axios from 'axios';
import FormData = require('form-data');
import { DeepSeekService } from './deepseek.service';

export interface StructurePoint {
  time: number;
  energy: number;
}

export interface AudioMetrics {
  bpm: number;
  duration: number;
  energy: number;
  energy_mean: number;
  energy_max: number;
  brightness: number;
  brightness_hz: number;
  tempo_stability: number;
  spectral_contrast: number;
  onset_density: number;
  dynamic_range: number;
  estimated_key: string;
  energy_curve: number[];
  sections: Array<{
    start: number;
    end: number;
    type: string;
    energy: number;
  }>;
  structure: StructurePoint[];
  hook_time: number;
  drop_time: number;
  intro_weak: boolean;
  // Hit predictor fields
  energy_variation: number;
  peak_energy: number;
  energy_std: number;
  early_energy: number;
  hit_score: number;
}

export interface TrackAnalysisResult {
  audioMetrics: AudioMetrics;
  aiAnalysis: string;
  score: number;
  hitScore: number;
  viralProbability: number;
}

@Injectable()
export class AudioAnalysisService {
  private readonly logger = new Logger(AudioAnalysisService.name);
  private readonly pythonUrl =
    process.env.AUDIO_ANALYSIS_URL || 'http://localhost:8001';

  constructor(private readonly ai: DeepSeekService) {}

  async analyzeTrack(
    file: Express.Multer.File,
    lyrics?: string,
  ): Promise<TrackAnalysisResult> {
    const audioMetrics = await this.extractAudioFeatures(file);
    const aiAnalysis = await this.getAiAnalysis(audioMetrics, lyrics);
    const score = this.extractScore(aiAnalysis);
    const viralProbability = this.extractViralProbability(aiAnalysis, audioMetrics.hit_score);

    return {
      audioMetrics,
      aiAnalysis,
      score,
      hitScore: audioMetrics.hit_score,
      viralProbability,
    };
  }

  private async extractAudioFeatures(
    file: Express.Multer.File,
  ): Promise<AudioMetrics> {
    const form = new FormData();
    form.append('file', file.buffer, {
      filename: file.originalname || 'track.mp3',
      contentType: file.mimetype || 'audio/mpeg',
    });

    try {
      const { data } = await axios.post<AudioMetrics>(
        `${this.pythonUrl}/analyze`,
        form,
        {
          headers: form.getHeaders(),
          timeout: 120_000,
          maxContentLength: 200 * 1024 * 1024,
          maxBodyLength: 200 * 1024 * 1024,
        },
      );

      this.logger.log(
        `Audio: BPM=${data.bpm}, key=${data.estimated_key}, ` +
        `hook=${data.hook_time}s, hit_score=${data.hit_score}, ` +
        `e_var=${data.energy_variation}, early_e=${data.early_energy}`,
      );
      return data;
    } catch (error: any) {
      this.logger.error(
        `Python service error: ${error.message}`,
        error.response?.data,
      );
      return this.fallbackMetrics(file);
    }
  }

  /**
   * AI analysis — full producer breakdown + hit prediction.
   */
  private async getAiAnalysis(
    metrics: AudioMetrics,
    lyrics?: string,
  ): Promise<string> {
    const sectionsSummary = metrics.sections
      .map(
        (s) =>
          `${s.type}: ${s.start}s–${s.end}s (energy: ${(s.energy * 100).toFixed(0)}%)`,
      )
      .join('\n');

    const structureSummary = this.summarizeStructure(metrics.structure);

    // Hit verdict label
    const hitLabel = metrics.hit_score >= 70
      ? 'ПОТЕНЦИАЛЬНЫЙ ХИТ'
      : metrics.hit_score >= 40
        ? 'ЕСТЬ ПОТЕНЦИАЛ'
        : 'ТРЕК НЕ ЗАЙДЁТ';

    const prompt = `Ты — топовый музыкальный продюсер и аналитик. Говоришь как есть, без воды.

Вот данные РЕАЛЬНОГО аудио-анализа трека (librosa + наш алгоритм):

═══ ОСНОВНЫЕ МЕТРИКИ ═══
BPM: ${metrics.bpm}
Тональность: ${metrics.estimated_key}
Длительность: ${metrics.duration} сек
Общая энергия (0-1): ${metrics.energy}
Яркость (0-1): ${metrics.brightness}
Стабильность темпа: ${metrics.tempo_stability}
Плотность ударов: ${metrics.onset_density} /сек
Динамический диапазон: ${metrics.dynamic_range} dB

═══ HIT PREDICTOR ═══
🔥 Hit Score: ${metrics.hit_score}/100 → ${hitLabel}
📊 Energy Variation (динамика): ${metrics.energy_variation} ${metrics.energy_variation > 0.5 ? '(высокая — хорошо)' : metrics.energy_variation > 0.3 ? '(средняя)' : '(низкая — трек монотонный)'}
⚡ Peak Energy: ${metrics.peak_energy}
📉 Early Energy (первые 10 сек): ${metrics.early_energy} ${metrics.early_energy < 0.5 ? '⚠️ КРИТИЧЕСКИ НИЗКАЯ — слушатель уходит' : metrics.early_energy < 0.7 ? '⚠️ ниже нормы' : '✅ ок'}
🎯 Hook: ${metrics.hook_time}s ${metrics.hook_time < 15 ? '✅ раннее — хорошо' : metrics.hook_time < 30 ? '⚠️ нормально' : '❌ поздно — слушатель уйдёт'}
💥 Drop: ${metrics.drop_time > 0 ? `${metrics.drop_time}s` : 'нет'}
⚠️ Intro слабое: ${metrics.intro_weak ? 'ДА' : 'НЕТ'}

═══ СТРУКТУРА ═══
Секции:
${sectionsSummary}

Энергия по времени:
${structureSummary}

${lyrics ? `═══ ТЕКСТ ═══\n${lyrics}\n` : ''}

═══ ЗАДАЧА ═══
1. Скажи честно: трек зайдёт или нет
2. Объясни ПОЧЕМУ (конкретно, с цифрами)
3. Где главный провал (с секундой)
4. Что убивает вирусность
5. Дай 3-5 конкретных правок с таймингами
6. Скажи, можно ли сделать хит из этого

Ответ СТРОГО в JSON:

{
  "score": число от 0 до 10,
  "verdict": "Одно резкое предложение — главный вывод",
  "genre_guess": "Предполагаемый жанр",
  "viral_probability": число от 0 до 100 (процент вирусности),
  "main_problem": "Главная проблема трека с конкретной секундой",
  "killer_issue": "Что именно убивает вирусность — одно предложение",
  "can_be_hit": true/false,
  "hit_recipe": "Если можно сделать хит — конкретно что изменить (1-2 предложения)",
  "strengths": ["сильная сторона 1", "сильная сторона 2", "сильная сторона 3"],
  "problems": ["проблема 1 (с секундой)", "проблема 2 (с секундой)", "проблема 3"],
  "improvements": [
    {"time": секунда, "action": "что конкретно сделать"},
    {"time": секунда, "action": "что конкретно сделать"},
    {"time": секунда, "action": "что конкретно сделать"}
  ],
  "hook_potential": число от 0 до 10,
  "production_quality": число от 0 до 10,
  "viral_potential": число от 0 до 10,
  "playlist_chance": число от 0 до 10,
  "best_tiktok_segment": "timestamp",
  "mix_notes": "замечания по миксу",
  "market_fit": "как вписывается в тренды",
  "structure_verdict": "оценка структуры",
  "hook_analysis": "разбор хука на ${metrics.hook_time}s",
  "drop_analysis": "${metrics.drop_time > 0 ? `разбор дропа на ${metrics.drop_time}s` : 'нет дропа'}",
  "intro_analysis": "разбор intro",
  "listener_dropout": "где и почему слушатель уходит (с секундой)",
  "retention_killer": "что конкретно убивает retention в первые 10 секунд",
  "fix_timestamps": [
    {"time": секунда, "issue": "проблема", "fix": "решение"}
  ],
  "final_opinion": "Финальное мнение продюсера — 2-3 предложения, как есть"
}

Требования:
— viral_probability основывай на hit_score (${metrics.hit_score}) + своей оценке
— если hit_score < 40 — будь жёсток, скажи правду
— если hit_score > 70 — объясни что именно делает трек сильным
— если early_energy низкая — это ГЛАВНАЯ проблема (68% слушателей уходят до 10 сек)
— improvements ОБЯЗАТЕЛЬНО с таймингами
— main_problem — с конкретной секундой
— final_opinion — без воды, как продюсер говорит артисту в лицо`;

    return this.ai.chat({
      message: prompt,
      mode: 'analyze',
    });
  }

  private summarizeStructure(structure: StructurePoint[]): string {
    if (!structure || structure.length === 0) return '(нет данных)';
    const step = Math.max(1, Math.floor(structure.length / 10));
    const points: string[] = [];
    for (let i = 0; i < structure.length; i += step) {
      const p = structure[i];
      const bar = '█'.repeat(Math.round(p.energy * 20));
      points.push(`${p.time.toFixed(1)}s: ${bar} ${(p.energy * 100).toFixed(0)}%`);
    }
    return points.join('\n');
  }

  private extractScore(aiResponse: string): number {
    try {
      const parsed = JSON.parse(aiResponse);
      const score = Number(parsed.score);
      if (!isNaN(score) && score >= 0 && score <= 10) {
        return Math.round(score * 10) / 10;
      }
    } catch {
      const match = aiResponse.match(/"score"\s*:\s*(\d+(?:\.\d+)?)/);
      if (match) {
        return Math.min(10, Math.max(0, parseFloat(match[1])));
      }
    }
    return 5.0;
  }

  /**
   * Extract viral probability from AI or estimate from hit_score.
   */
  private extractViralProbability(aiResponse: string, hitScore: number): number {
    try {
      const parsed = JSON.parse(aiResponse);
      const vp = Number(parsed.viral_probability);
      if (!isNaN(vp) && vp >= 0 && vp <= 100) {
        return Math.round(vp);
      }
    } catch {
      const match = aiResponse.match(/"viral_probability"\s*:\s*(\d+(?:\.\d+)?)/);
      if (match) {
        return Math.min(100, Math.max(0, Math.round(parseFloat(match[1]))));
      }
    }
    // Fallback: estimate from hit_score
    return Math.min(100, Math.max(0, Math.round(hitScore * 0.9)));
  }

  private fallbackMetrics(file: Express.Multer.File): AudioMetrics {
    this.logger.warn('Using fallback metrics — Python service unavailable');
    const estimatedDuration = file.size / (128 * 1024 / 8);

    return {
      bpm: 120,
      duration: Math.round(estimatedDuration),
      energy: 0.5,
      energy_mean: 0.08,
      energy_max: 0.2,
      brightness: 0.5,
      brightness_hz: 3500,
      tempo_stability: 0.8,
      spectral_contrast: 20,
      onset_density: 3,
      dynamic_range: 15,
      estimated_key: 'C',
      energy_curve: Array(50).fill(0.08),
      sections: [
        { start: 0, end: estimatedDuration, type: 'full', energy: 0.5 },
      ],
      structure: Array.from({ length: 50 }, (_, i) => ({
        time: (i / 50) * estimatedDuration,
        energy: 0.5,
      })),
      hook_time: Math.round(estimatedDuration * 0.3),
      drop_time: 0,
      intro_weak: false,
      energy_variation: 0.3,
      peak_energy: 0.15,
      energy_std: 0.04,
      early_energy: 0.7,
      hit_score: 50,
    };
  }
}
