// ══════════════════════════════════════════════════════════════
// Legacy Response Mapper
// Maps new 3-layer analysis to old frontend contract
// Frontend reads: audioMetrics, aiAnalysis (JSON string),
//   score, hitScore, viralProbability, genre, lyrics, lyricsAnalysis
// ══════════════════════════════════════════════════════════════

import { TrackAnalysisResponse } from './analysis.dto';

export function mapToLegacyResponse(analysis: TrackAnalysisResponse) {
  const m = analysis.measured_data;
  const d = analysis.derived_insights;
  const ai = analysis.ai_explanation;

  // ── audioMetrics: flat object matching old Python response ──
  const audioMetrics: Record<string, any> = {
    bpm: m.bpm.bpm,
    duration: m.duration,
    energy: Math.min(1, m.rms / 0.15),
    energy_mean: m.rms,
    energy_max: m.rms_max,
    brightness: Math.min(1, Math.max(0, ((m.spectral?.brightness_hz ?? 3000) - 1000) / 7000)),
    brightness_hz: m.spectral?.brightness_hz ?? 0,
    tempo_stability: m.tempo_stability,
    spectral_contrast: m.spectral?.spectral_contrast ?? 0,
    onset_density: m.onset_density,
    dynamic_range: m.dynamic_range,
    estimated_key: m.key.key,
    genre: d.genre,
    lyrics: m.transcript?.text ?? null,
    energy_curve: m.energy_curve,
    waveform_peaks: m.waveform_peaks,
    sections: (m.section_candidates || []).map(s => ({
      start: s.start,
      end: s.end,
      type: s.label ?? (s as any).type ?? 'unknown',
      energy: s.energy,
    })),
    structure: m.structure,
    hook_time: d.hook_time,
    drop_time: d.drop_time,
    intro_weak: d.intro_weak,
    energy_variation: d.energy_variation,
    peak_energy: d.peak_energy,
    energy_std: 0,
    early_energy: d.early_energy_ratio,
    hit_score: d.hit_score,
    lufs: m.lufs,
    spectral_flux: m.spectral?.spectral_flux ?? 0,
    freq_bands: m.spectral?.freq_bands ?? {},
  };

  // ── aiAnalysis: JSON string matching old merged GPT response ──
  const aiObj: Record<string, any> = {
    score: ai.score,
    verdict: ai.verdict,
    genre: d.genre,
    viral_probability: ai.viral_probability,
    strengths: ai.strengths ?? [],
    problems: (d.insights || [])
      .filter(i => i.severity === 'critical' || i.severity === 'warning')
      .map(i => i.title),
    main_problem: d.insights?.find(i => i.severity === 'critical')?.title ?? '',
    killer_issue: d.insights?.find(i => i.severity === 'critical')?.detail ?? '',
    can_be_hit: d.hit_score >= 60,
    hit_recipe: ai.top_fixes?.map(f => f.fix).join('; ') ?? '',
    fix_recommendations: ai.top_fixes?.map(f => f.fix) ?? [],
    producer_notes: ai.producer_notes ?? '',
    top_fixes: ai.top_fixes ?? [],
    // Producer sub-scores (not available in new format — zeros)
    hook_potential: 0,
    production_quality: 0,
    viral_potential: 0,
    playlist_chance: 0,
    hookScore: 0,
    structureScore: 0,
    emotionScore: 0,
    originalityScore: 0,
    // Structure / hook / freq verdicts from producer_notes
    structure_verdict: ai.producer_notes ?? '',
    hook_analysis: '',
    freq_balance_verdict: '',
    final_opinion: ai.producer_notes ?? '',
    retention_killer: d.insights?.find(i => i.code === 'intro_weak' || i.code === 'early_energy_critical')?.title ?? '',
    // TikTok
    best_tiktok_segment: ai.tiktok_segment
      ? `${ai.tiktok_segment.start}-${ai.tiktok_segment.end}s`
      : '',
    // Lyrics
    lyrics_insight: ai.lyrics_insight ?? null,
    // Key/viral moments — empty in new format
    key_moments: [],
    viral_moments: [],
    fix_timestamps: (ai.top_fixes ?? [])
      .filter(f => f.time != null)
      .map(f => ({ time: f.time, issue: f.issue, fix: f.fix })),
    // Improvement prompt
    improvement_prompt: ai.improvement_prompt ?? '',
  };

  const aiAnalysis = JSON.stringify(aiObj);

  // ── lyricsAnalysis: old format was LyricsIntelligence object ──
  // New format doesn't have separate lyrics GPT call.
  // Build a compatible stub from transcript + ai_explanation.
  const lyricsAnalysis = m.transcript?.text ? {
    structure: [],
    hook: '',
    themes: [],
    emotion: '',
    strongest_lines: [],
    weakest_lines: [],
    repetition_patterns: [],
  } : null;

  return {
    audioMetrics,
    aiAnalysis,
    score: ai.score,
    hitScore: d.hit_score,
    viralProbability: ai.viral_probability,
    genre: d.genre,
    lyrics: m.transcript?.text ?? null,
    lyricsAnalysis,
  };
}
