// ══════════════════════════════════════════════════════════════
// Confidence Scoring v2
// More realistic: uses extended transcript/structure/hook data
// Overall uses weakest-link approach, not just average
// ══════════════════════════════════════════════════════════════

import { MeasuredData, ConfidenceScores } from './analysis.dto';

export function computeConfidence(measured: MeasuredData): ConfidenceScores {
  const transcript = transcriptConfidence(measured);
  const structure = structureConfidence(measured);
  const hook = hookConfidence(measured);
  const key = measured.key.confidence;
  const bpm = measured.bpm.agreement;

  // Overall: weighted average PLUS weakest-link penalty
  const hasTranscript = measured.transcript.text !== null;

  const components = [
    { name: 'structure', value: structure, weight: 0.25 },
    { name: 'hook', value: hook, weight: 0.25 },
    { name: 'bpm', value: bpm, weight: 0.20 },
    { name: 'key', value: key, weight: 0.15 },
  ];
  if (hasTranscript) {
    components.push({ name: 'transcript', value: transcript, weight: 0.15 });
  }

  const totalWeight = components.reduce((sum, c) => sum + c.weight, 0);
  const weightedAvg = components.reduce((sum, c) => sum + c.value * c.weight, 0) / totalWeight;

  // Weakest-link penalty: if any component is below 0.3, drag overall down
  const weakest = Math.min(...components.map(c => c.value));
  let overall = weightedAvg;
  if (weakest < 0.3) {
    overall = overall * 0.7 + weakest * 0.3; // blend with weakest
  }

  return {
    transcript_confidence: round(transcript),
    structure_confidence: round(structure),
    hook_confidence: round(hook),
    key_confidence: round(key),
    overall_analysis_confidence: round(overall),
  };
}

function transcriptConfidence(measured: MeasuredData): number {
  const t = measured.transcript;
  if (!t.text) return 0;

  // Start from whisper model confidence
  let conf = t.confidence;

  // Word count adjustments
  if (t.word_count > 100) conf = Math.min(1, conf + 0.1);
  else if (t.word_count > 50) conf = Math.min(1, conf + 0.05);
  else if (t.word_count < 20) conf *= 0.6;
  else if (t.word_count < 30) conf *= 0.8;

  // Segment count
  if (t.segment_count > 10) conf = Math.min(1, conf + 0.05);
  if (t.segment_count < 3) conf = Math.max(0, conf - 0.1);

  // Repeated phrase ratio: high repetition can indicate hallucination
  if (t.repeated_phrase_ratio > 0.6) conf *= 0.5;
  else if (t.repeated_phrase_ratio > 0.4) conf *= 0.7;

  // Reliability flags
  const flags = t.reliability_flags || [];
  if (flags.includes('possible_hallucination')) conf *= 0.3;
  if (flags.includes('low_confidence')) conf *= 0.7;
  if (flags.includes('uncertain_language')) conf *= 0.85;

  // Language confidence
  if (t.language_confidence < 0.4) conf *= 0.7;

  // Text length
  if (t.text.length < 50) conf *= 0.5;
  else if (t.text.length < 100) conf *= 0.75;

  return clamp(conf);
}

function structureConfidence(measured: MeasuredData): number {
  const sections = measured.section_candidates;
  if (sections.length === 0) return 0.1;
  if (sections.length === 1) return 0.2;

  let conf = 0.4;

  // Number of distinct section types
  const types = new Set(sections.map(s => s.label));
  if (types.size >= 4) conf += 0.2;
  else if (types.size >= 3) conf += 0.15;
  else if (types.size >= 2) conf += 0.05;

  // Section repetition score: higher = clearer structure
  const repScore = measured.section_repetition_score ?? 0;
  if (repScore > 0.4) conf += 0.2;
  else if (repScore > 0.2) conf += 0.1;

  // Average per-section confidence
  if (sections.length > 0) {
    const avgSectionConf = sections.reduce((sum, s) => sum + (s.confidence || 0.5), 0) / sections.length;
    conf += avgSectionConf * 0.15;
  }

  // Good section duration spread
  const durations = sections.map(s => s.end - s.start);
  const avgDur = durations.reduce((a, b) => a + b, 0) / durations.length;
  const durVariance = durations.reduce((a, d) => a + (d - avgDur) ** 2, 0) / durations.length;
  if (durVariance > 10) conf += 0.05;

  return clamp(conf);
}

function hookConfidence(measured: MeasuredData): number {
  if (measured.hook_candidates.length === 0) return 0;

  const best = measured.hook_candidates[0];

  // Start from the candidate's own confidence
  let conf = best.confidence;

  // Gap between top two candidates: larger gap = more distinct hook
  if (measured.hook_candidates.length >= 2) {
    const second = measured.hook_candidates[1];
    const gap = best.combined_score - second.combined_score;
    if (gap < 0.05) conf *= 0.6; // almost identical — very ambiguous
    else if (gap < 0.1) conf *= 0.75;
    else if (gap > 0.3) conf = Math.min(1, conf + 0.1);
  }

  // Multi-signal bonus: hook is supported by both energy AND repetition
  if (best.based_on_energy && best.based_on_repetition) {
    conf = Math.min(1, conf + 0.1);
  }

  // Vocal presence adds confidence for vocal tracks
  if (best.based_on_vocal_presence) {
    conf = Math.min(1, conf + 0.05);
  }

  // Short tracks have less reliable detection
  if (measured.duration < 30) conf *= 0.5;
  else if (measured.duration < 60) conf *= 0.8;

  return clamp(conf);
}

function clamp(v: number): number {
  return Math.max(0, Math.min(1, v));
}

function round(v: number): number {
  return Math.round(v * 100) / 100;
}
