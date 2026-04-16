// ══════════════════════════════════════════════════════════════
// Analysis Prompt Builder v2
// Builds a single LLM prompt from measured_data + derived_insights
// Uses extended fields: vocal time, chorus time, reliability flags
// LLM only EXPLAINS — never discovers facts
// ══════════════════════════════════════════════════════════════

import { MeasuredData, DerivedInsights } from './analysis.dto';

export function buildAnalysisPrompt(
  measured: MeasuredData,
  derived: DerivedInsights,
  lyrics: string | null,
): { system: string; user: string } {
  const system = `Ты — музыкальный продюсер-аналитик. Тебе предоставлены ТОЧНЫЕ данные анализа трека.

ПРАВИЛА:
— НЕ определяй BPM, тональность, LUFS, таймкоды самостоятельно — они уже даны
— НЕ спорь с данными — они измерены приборами
— Объясняй найденные проблемы и сильные стороны ЧЕЛОВЕЧЕСКИМ ЯЗЫКОМ
— Будь конкретным: называй секунды, dB, проценты
— Опирайся на insights rule engine — они уже определили проблемы
— Дай improvement_prompt — промпт для генерации улучшенной версии трека (на англ.)
— Ответ СТРОГО в JSON. Без markdown. Без текста до или после JSON.`;

  const lines: string[] = [];

  // ── Core measurements ──
  lines.push('=== ИЗМЕРЕННЫЕ ДАННЫЕ ===');
  lines.push(`BPM: ${measured.bpm.bpm} (согласованность: ${pct(measured.bpm.agreement)})`);
  lines.push(`Тональность: ${measured.key.key} (уверенность: ${pct(measured.key.confidence)})`);
  lines.push(`Длительность: ${fmtTime(measured.duration)}`);
  lines.push(`LUFS: ${measured.lufs.toFixed(1)} | RMS: ${(measured.rms * 100).toFixed(1)}%`);
  lines.push(`Динамический диапазон: ${measured.dynamic_range.toFixed(1)} dB`);
  lines.push(`Темпо стабильность: ${pct(measured.tempo_stability)}`);
  lines.push(`Гармоническое: ${pct(measured.harmonic_ratio)}`);

  // Spectral
  const sp = measured.spectral;
  const fb = sp.freq_bands;
  lines.push(`Яркость: ${sp.brightness_hz.toFixed(0)} Hz`);
  lines.push(`Баланс: Bass=${pct(fb.sub_bass + fb.bass)} Mid=${pct(fb.mid + fb.low_mid)} High=${pct(fb.high + fb.upper_mid + fb.brilliance)}`);

  // ── Hook ──
  if (measured.main_hook_candidate) {
    const h = measured.main_hook_candidate;
    lines.push(`Хук: ${h.time.toFixed(1)}s (confidence: ${pct(h.confidence)}, reason: ${h.reason})`);
  } else {
    lines.push('Хук: не обнаружен');
  }

  // ── Vocal timing ──
  if (measured.first_vocal_time !== null) {
    lines.push(`Первый вокал: ${measured.first_vocal_time.toFixed(1)}s`);
  } else {
    lines.push('Вокал: не обнаружен');
  }

  // ── Structure ──
  if (measured.section_candidates.length > 0) {
    const sections = measured.section_candidates.slice(0, 8).map(s =>
      `${s.label}:${s.start.toFixed(0)}-${s.end.toFixed(0)}s(${pct(s.energy)},conf=${pct(s.confidence)})`
    ).join(', ');
    lines.push(`Секции: ${sections}`);
  }

  if (measured.first_chorus_candidate_time !== null) {
    lines.push(`Первый припев: ${measured.first_chorus_candidate_time.toFixed(0)}s`);
  }

  if (measured.intro_duration_estimate > 0) {
    lines.push(`Длина интро: ${measured.intro_duration_estimate.toFixed(0)}s`);
  }

  lines.push(`Повторяемость секций: ${pct(measured.section_repetition_score ?? 0)}`);

  // Intro
  lines.push(`Интро: энергия ${pct(measured.intro_metrics.ratio)} от основной, вокал: ${measured.intro_metrics.intro_vocal_presence ? 'да' : 'нет'}, переход: ${pct(measured.intro_metrics.intro_transition_strength)}`);

  // Drop
  if (measured.drop_candidates.length > 0) {
    lines.push(`Дроп: ${measured.drop_candidates[0].time.toFixed(1)}s (сила: ${pct(measured.drop_candidates[0].magnitude)})`);
  }

  // ── Genre ──
  lines.push(`Жанр: ${measured.primary_genre} (confidence: ${pct(measured.genre_confidence ?? 0)})`);
  if (measured.genre_candidates.length > 1) {
    const alt = measured.genre_candidates.slice(1, 3).map(g => `${g.genre}(${pct(g.confidence)})`).join(', ');
    lines.push(`Альтернативные жанры: ${alt}`);
  }

  // ── Derived insights ──
  lines.push('');
  lines.push('=== ВЫВОДЫ RULE ENGINE ===');
  lines.push(`Hit Score: ${derived.hit_score}/100`);
  lines.push(`Уверенность анализа: ${pct(derived.confidence.overall_analysis_confidence)}`);

  // Group insights by severity
  const criticals = derived.insights.filter(i => i.severity === 'critical');
  const warnings = derived.insights.filter(i => i.severity === 'warning');
  const positives = derived.insights.filter(i => i.severity === 'positive');

  if (criticals.length > 0) {
    lines.push('');
    lines.push('КРИТИЧЕСКИЕ ПРОБЛЕМЫ:');
    for (const ins of criticals) {
      lines.push(`  [!!!] ${ins.title}`);
      lines.push(`        ${ins.detail}`);
      lines.push(`        Почему важно: ${ins.why_this_matters}`);
      if (ins.suggested_fix) lines.push(`        Фикс: ${ins.suggested_fix}`);
    }
  }

  if (warnings.length > 0) {
    lines.push('');
    lines.push('ПРЕДУПРЕЖДЕНИЯ:');
    for (const ins of warnings) {
      lines.push(`  [!] ${ins.title}`);
      lines.push(`      ${ins.detail}`);
    }
  }

  if (positives.length > 0) {
    lines.push('');
    lines.push('СИЛЬНЫЕ СТОРОНЫ:');
    for (const ins of positives) {
      lines.push(`  [+] ${ins.title}`);
    }
  }

  // ── Transcript ──
  if (lyrics) {
    lines.push('');
    lines.push('=== ТЕКСТ ===');
    lines.push(`Уверенность: ${pct(measured.transcript.confidence)}, язык: ${measured.transcript.language || '?'} (${pct(measured.transcript.language_confidence)})`);
    lines.push(`Слов: ${measured.transcript.word_count}, повтор фраз: ${pct(measured.transcript.repeated_phrase_ratio)}`);

    const flags = measured.transcript.reliability_flags || [];
    if (flags.length > 0) {
      lines.push(`Флаги: ${flags.join(', ')}`);
    }

    lines.push(lyrics.slice(0, 1200));
  } else {
    lines.push('');
    lines.push('Инструментал (текст не обнаружен)');
  }

  // ── Task ──
  lines.push('');
  lines.push('=== ЗАДАНИЕ ===');
  lines.push('Объясни результаты анализа ЧЕЛОВЕЧЕСКИМ ЯЗЫКОМ. Опирайся на данные и выводы rule engine.');
  lines.push('Ответь JSON:');
  lines.push(`{
  "verdict": "Главный вывод — 1-2 предложения. Что это за трек и каковы его перспективы",
  "producer_notes": "Разбор для продюсера: структура, микс, аранжировка — 3-5 предложений. Ссылайся на конкретные секунды и данные",
  "score": 0-10,
  "viral_probability": 0-100,
  "top_fixes": [
    {"issue": "конкретная проблема из данных", "fix": "конкретное действие", "time": секунда_или_null},
    {"issue": "проблема", "fix": "действие", "time": null},
    {"issue": "проблема", "fix": "действие", "time": null}
  ],
  "strengths": ["сильная сторона 1", "сильная сторона 2", "сильная сторона 3"],
  "tiktok_segment": {"start": секунда, "end": секунда, "idea": "идея для Reels с этим фрагментом"},
  "lyrics_insight": {
    "main_theme": "о чём текст",
    "hook_quality": "оценка хука текста",
    "weak_parts": "слабые части текста",
    "energy_match": "совпадает ли энергия музыки с текстом"
  },
  "improvement_prompt": "Detailed English prompt for AI to generate an improved version. Include: genre (${measured.primary_genre}), BPM (${measured.bpm.bpm}), key (${measured.key.key}), specific structural fixes based on the critical issues above, mix improvements, and arrangement changes. Be actionable."
}`);

  if (!lyrics) {
    lines.push('(lyrics_insight = null, т.к. инструментал)');
  }

  return { system, user: lines.join('\n') };
}

function pct(v: number): string {
  return `${(v * 100).toFixed(0)}%`;
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}
