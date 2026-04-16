// ══════════════════════════════════════════════════════════════
// Analysis DTO — 3-layer explainable pipeline
// Layer 1: MeasuredData   — raw signals from Python service
// Layer 2: DerivedInsights — deterministic rule engine output
// Layer 3: AiExplanation  — LLM interpretation (human language)
// ══════════════════════════════════════════════════════════════

// ── Layer 1: Measured Data ──────────────────────────────────

export interface FreqBands {
  sub_bass: number;
  bass: number;
  low_mid: number;
  mid: number;
  upper_mid: number;
  high: number;
  brilliance: number;
}

export interface SpectralFeatures {
  brightness_hz: number;
  spectral_contrast: number;
  spectral_flux: number;
  spectral_rolloff: number;
  spectral_bandwidth: number;
  zcr: number;
  mfcc_means: number[];
  freq_bands: FreqBands;
}

export interface HookCandidate {
  time: number;
  energy_score: number;
  repetition_score: number;
  combined_score: number;
  confidence: number;
  reason: string;
  based_on_energy: boolean;
  based_on_repetition: boolean;
  based_on_vocal_presence: boolean;
}

export interface MainHookCandidate {
  time: number;
  confidence: number;
  reason: string;
}

export interface DropCandidate {
  time: number;
  magnitude: number;
}

export interface SectionCandidate {
  label: string;
  start: number;
  end: number;
  energy: number;
  confidence: number;
  fingerprint_group: number;
}

export interface StructurePoint {
  time: number;
  energy: number;
}

export interface IntroMetrics {
  intro_energy: number;
  main_energy: number;
  ratio: number;
  intro_vocal_presence: boolean;
  intro_transition_strength: number;
}

export interface TranscriptData {
  text: string | null;
  language: string | null;
  confidence: number;
  segment_count: number;
  word_count: number;
  repeated_phrase_ratio: number;
  language_confidence: number;
  reliability_flags: string[];
}

export interface GenreCandidate {
  genre: string;
  confidence: number;
  reason: string;
}

export interface KeyDetection {
  key: string;
  confidence: number;
}

export interface BpmDetection {
  bpm: number;
  candidates: number[];
  agreement: number;
}

export interface MeasuredData {
  bpm: BpmDetection;
  key: KeyDetection;
  duration: number;

  // Loudness & energy
  lufs: number;
  rms: number;
  rms_max: number;
  dynamic_range: number;
  energy_curve: number[];
  waveform_peaks: number[];

  // Spectral
  spectral: SpectralFeatures;

  // Rhythm
  tempo_stability: number;
  onset_density: number;
  harmonic_ratio: number;

  // Hook
  hook_candidates: HookCandidate[];
  main_hook_candidate: MainHookCandidate | null;
  hook_detection_method_version: string;

  // Structure
  section_candidates: SectionCandidate[];
  first_vocal_time: number | null;
  first_chorus_candidate_time: number | null;
  intro_duration_estimate: number;
  section_repetition_score: number;
  structure_detection_method_version: string;
  structure: StructurePoint[];

  // Drop
  drop_candidates: DropCandidate[];

  // Intro
  intro_metrics: IntroMetrics;

  // Transcript
  transcript: TranscriptData;

  // Genre
  genre_candidates: GenreCandidate[];
  primary_genre: string;
  genre_confidence: number;
}

// ── Layer 2: Derived Insights ───────────────────────────────

export type InsightSeverity = 'critical' | 'warning' | 'info' | 'positive';
export type InsightGroup = 'timing' | 'hook' | 'loudness' | 'transcript' | 'structure' | 'genre' | 'mix' | 'general';

export interface Insight {
  code: string;
  severity: InsightSeverity;
  group: InsightGroup;
  title: string;
  detail: string;
  why_this_matters: string;
  suggested_fix: string;
  priority: number; // 1 = highest
}

export interface ConfidenceScores {
  transcript_confidence: number;
  structure_confidence: number;
  hook_confidence: number;
  key_confidence: number;
  overall_analysis_confidence: number;
}

export interface DerivedInsights {
  genre: string;
  hit_score: number;
  insights: Insight[];
  confidence: ConfidenceScores;

  // Resolved single values from candidates
  hook_time: number;
  drop_time: number;
  intro_weak: boolean;

  // Pre-computed for LLM context
  early_energy_ratio: number;
  energy_variation: number;
  peak_energy: number;
}

// ── Layer 3: AI Explanation ─────────────────────────────────

export interface AiExplanation {
  verdict: string;
  producer_notes: string;
  top_fixes: Array<{ issue: string; fix: string; time?: number }>;
  strengths: string[];
  score: number;
  viral_probability: number;
  improvement_prompt: string;
  tiktok_segment?: { start: number; end: number; idea: string };
  lyrics_insight?: {
    main_theme: string;
    hook_quality: string;
    weak_parts: string;
    energy_match: string;
  };
}

// ── Final Response ──────────────────────────────────────────

export interface TrackAnalysisResponse {
  measured_data: MeasuredData;
  derived_insights: DerivedInsights;
  ai_explanation: AiExplanation;
}

// ── Legacy compat (for DB storage) ──────────────────────────

export interface TrackAnalysisDbRow {
  user_id: number;
  filename: string;
  genre: string;
  bpm: number;
  key: string;
  duration: number;
  hit_score: number;
  score: number;
  viral_probability: number;
  measured_data: MeasuredData;
  derived_insights: DerivedInsights;
  ai_explanation: AiExplanation;
  lyrics: string | null;
}
