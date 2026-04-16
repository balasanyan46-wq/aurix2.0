// ══════════════════════════════════════════════════════════════
// Analysis Rule Engine v2
// Deterministic: MeasuredData → DerivedInsights
// Grouped rules with rich explainable insights
// ══════════════════════════════════════════════════════════════

import {
  MeasuredData,
  DerivedInsights,
  Insight,
  InsightSeverity,
  InsightGroup,
} from './analysis.dto';
import { computeConfidence } from './analysis-confidence';

export function deriveInsights(measured: MeasuredData): DerivedInsights {
  const insights: Insight[] = [];

  // ── Resolve candidates to single values ──
  const hookTime = measured.hook_candidates.length > 0
    ? measured.hook_candidates[0].time
    : 0;

  const dropTime = measured.drop_candidates.length > 0
    ? measured.drop_candidates[0].time
    : 0;

  const introWeak = measured.intro_metrics.ratio < 0.4 && measured.duration > 15;

  // ── Energy-derived metrics ──
  const rms = measured.rms;
  const rmsMax = measured.rms_max;
  const energyVariation = rmsMax > 0 ? (rmsMax - rms) / (rms + 1e-6) : 0;
  const peakEnergy = rmsMax;

  const curve = measured.energy_curve;
  const earlyFrames = Math.max(1, Math.floor(curve.length * 0.23));
  const earlyEnergy = curve.slice(0, earlyFrames).reduce((a, b) => a + b, 0) / earlyFrames;
  const avgEnergy = curve.reduce((a, b) => a + b, 0) / (curve.length || 1);
  const earlyEnergyRatio = avgEnergy > 0 ? earlyEnergy / avgEnergy : 1;

  // ── Genre ──
  const genre = measured.primary_genre || (
    measured.genre_candidates.length > 0
      ? measured.genre_candidates[0].genre
      : 'Other'
  );

  // ── Hit Score ──
  const hitScore = calculateHitScore({
    hookTime,
    introWeak,
    energyVariation,
    earlyEnergyRatio,
    peakEnergy,
    rms,
    bpm: measured.bpm.bpm,
    dynamicRange: measured.dynamic_range,
    tempoStability: measured.tempo_stability,
    duration: measured.duration,
    spectralFlux: measured.spectral.spectral_flux,
    lufs: measured.lufs,
  });

  // ══════════════════════════════════════════════════════════════
  // RULE GROUPS
  // ══════════════════════════════════════════════════════════════

  timingRules(measured, insights, hookTime, earlyEnergyRatio, introWeak);
  hookRules(measured, insights, hookTime);
  loudnessRules(measured, insights);
  transcriptRules(measured, insights);
  structureRules(measured, insights);
  genreConfidenceRules(measured, insights);
  mixRules(measured, insights);

  // Sort by priority
  insights.sort((a, b) => a.priority - b.priority);

  // ── Confidence scores ──
  const confidence = computeConfidence(measured);

  return {
    genre,
    hit_score: hitScore,
    insights,
    confidence,
    hook_time: hookTime,
    drop_time: dropTime,
    intro_weak: introWeak,
    early_energy_ratio: round3(earlyEnergyRatio),
    energy_variation: round3(energyVariation),
    peak_energy: round4(peakEnergy),
  };
}

// ══════════════════════════════════════════════════════════════
// TIMING RULES
// ══════════════════════════════════════════════════════════════

function timingRules(m: MeasuredData, ins: Insight[], hookTime: number, earlyRatio: number, introWeak: boolean) {
  // Intro weak
  if (introWeak) {
    ins.push(insight({
      code: 'intro_weak',
      severity: 'critical',
      group: 'timing',
      title: `Weak intro (${pct(m.intro_metrics.ratio)} of main energy)`,
      detail: `The first 8 seconds have only ${pct(m.intro_metrics.ratio)} of the track's median energy.`,
      why: 'Weak intros cause listeners to skip within 5-8 seconds on streaming platforms.',
      fix: 'Add energy to the intro, or shorten it to get to the first vocal/hook faster.',
      priority: 1,
    }));
  }

  // Intro has no vocals
  if (!m.intro_metrics.intro_vocal_presence && m.first_vocal_time !== null && m.first_vocal_time > 10) {
    ins.push(insight({
      code: 'late_vocal_entry',
      severity: 'warning',
      group: 'timing',
      title: `Vocals start late at ${m.first_vocal_time.toFixed(0)}s`,
      detail: `No vocal presence detected in the intro. First vocal appears at ${m.first_vocal_time.toFixed(1)}s.`,
      why: 'Vocal-driven tracks benefit from early vocal presence for listener engagement.',
      fix: 'Add a vocal ad-lib, sample, or teaser in the intro before the main vocal entry.',
      priority: 3,
    }));
  }

  // Intro transition strength
  if (m.intro_metrics.intro_transition_strength < 0.2 && m.duration > 30) {
    ins.push(insight({
      code: 'weak_intro_transition',
      severity: 'warning',
      group: 'timing',
      title: `Weak transition out of intro`,
      detail: `Energy transition from intro to main section is only ${pct(m.intro_metrics.intro_transition_strength)} increase.`,
      why: 'A clear energy jump after the intro signals the start of the song and prevents skips.',
      fix: 'Add a riser, fill, or percussion hit to mark the transition from intro to verse.',
      priority: 5,
    }));
  }

  // Early energy
  if (earlyRatio < 0.5) {
    ins.push(insight({
      code: 'early_energy_critical',
      severity: 'critical',
      group: 'timing',
      title: `Very low opening energy (${pct(earlyRatio)} of average)`,
      detail: `The first 10 seconds have ${pct(earlyRatio)} of the track's average energy.`,
      why: 'The opening is the most critical moment for streaming retention — most skips happen here.',
      fix: 'Increase presence in the first 10s: louder intro elements, earlier bass entry, or vocal snippet.',
      priority: 2,
    }));
  } else if (earlyRatio < 0.7) {
    ins.push(insight({
      code: 'early_energy_low',
      severity: 'warning',
      group: 'timing',
      title: `Below-average opening energy (${pct(earlyRatio)})`,
      detail: `First 10 seconds are at ${pct(earlyRatio)} of the track's average energy level.`,
      why: 'Moderate opening energy may cause some listeners to skip before the main section.',
      fix: 'Consider adding more presence to the opening section.',
      priority: 4,
    }));
  }

  // Duration
  if (m.duration > 300) {
    ins.push(insight({
      code: 'track_too_long',
      severity: 'warning',
      group: 'timing',
      title: `Track is long for streaming (${fmtTime(m.duration)})`,
      detail: `At ${fmtTime(m.duration)}, this track exceeds the typical streaming-friendly length.`,
      why: 'Tracks over 5 minutes get fewer complete listens and lower average stream duration.',
      fix: 'Consider creating a radio edit at 3-4 minutes for streaming distribution.',
      priority: 6,
    }));
  } else if (m.duration < 60) {
    ins.push(insight({
      code: 'track_very_short',
      severity: 'warning',
      group: 'timing',
      title: `Track is very short (${fmtTime(m.duration)})`,
      detail: `Duration is only ${fmtTime(m.duration)}.`,
      why: 'Very short tracks may not qualify for some editorial playlists.',
      fix: 'Consider extending with an additional verse or instrumental bridge.',
      priority: 6,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// HOOK RULES
// ══════════════════════════════════════════════════════════════

function hookRules(m: MeasuredData, ins: Insight[], hookTime: number) {
  // Hook timing
  if (hookTime > 30) {
    ins.push(insight({
      code: 'hook_late',
      severity: 'critical',
      group: 'hook',
      title: `Hook appears late at ${hookTime.toFixed(1)}s`,
      detail: `The main hook/memorable moment was detected at ${hookTime.toFixed(1)}s into the track.`,
      why: 'Streaming listeners typically decide to skip within 15-30 seconds.',
      fix: 'Move the hook earlier, or tease the hook melody/rhythm in the intro.',
      priority: 1,
    }));
  } else if (hookTime > 15 && hookTime <= 30) {
    ins.push(insight({
      code: 'hook_timing_ok',
      severity: 'info',
      group: 'hook',
      title: `Hook at ${hookTime.toFixed(1)}s — acceptable`,
      detail: `Hook is at ${hookTime.toFixed(1)}s, within the 15-30s acceptable range.`,
      why: 'Earlier hooks (under 15s) tend to perform better on streaming.',
      fix: 'Consider adding a hook preview or teaser in the first 15 seconds.',
      priority: 7,
    }));
  } else if (hookTime > 0 && hookTime <= 15) {
    ins.push(insight({
      code: 'hook_early',
      severity: 'positive',
      group: 'hook',
      title: `Hook appears early at ${hookTime.toFixed(1)}s`,
      detail: `The main hook is detected at ${hookTime.toFixed(1)}s — ideal for streaming retention.`,
      why: 'Early hooks maximize the chance listeners stay past the critical first 15 seconds.',
      fix: '',
      priority: 10,
    }));
  }

  // Hook clarity
  if (m.hook_candidates.length > 0) {
    const best = m.hook_candidates[0];
    if (best.confidence < 0.3 && m.duration > 30) {
      ins.push(insight({
        code: 'hook_unclear',
        severity: 'warning',
        group: 'hook',
        title: 'No clear hook detected',
        detail: `Best hook candidate has only ${pct(best.confidence)} confidence. The track lacks a distinct repeating high-energy section.`,
        why: 'A clear, memorable hook is the single most important element for streaming success.',
        fix: 'Create a distinct melodic or rhythmic phrase that repeats at least 2-3 times in the track.',
        priority: 2,
      }));
    }

    // Hook based on energy only (no repetition)
    if (best.based_on_energy && !best.based_on_repetition && m.duration > 60) {
      ins.push(insight({
        code: 'hook_not_repeating',
        severity: 'warning',
        group: 'hook',
        title: 'Hook moment is loud but not repeating',
        detail: `The detected hook at ${best.time.toFixed(1)}s is energy-based but doesn't repeat melodically.`,
        why: 'True hooks are memorable because they repeat — energy alone is not enough.',
        fix: 'Repeat the hook section at least 2-3 times throughout the arrangement.',
        priority: 3,
      }));
    }
  } else if (m.duration > 30) {
    ins.push(insight({
      code: 'no_hook_detected',
      severity: 'critical',
      group: 'hook',
      title: 'No hook moment detected',
      detail: 'The analysis could not identify any hook candidate in the track.',
      why: 'Without a memorable moment, the track will struggle on streaming platforms.',
      fix: 'Add a clear, repeating melodic or rhythmic hook that stands out from the rest of the arrangement.',
      priority: 1,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// LOUDNESS RULES
// ══════════════════════════════════════════════════════════════

function loudnessRules(m: MeasuredData, ins: Insight[]) {
  if (m.lufs > -8) {
    ins.push(insight({
      code: 'loudness_overcompressed',
      severity: 'warning',
      group: 'loudness',
      title: `Overcompressed master (LUFS: ${m.lufs.toFixed(1)})`,
      detail: `Integrated loudness is ${m.lufs.toFixed(1)} LUFS, above the -8 overcompression threshold.`,
      why: 'Streaming platforms normalize loudness — overcompressed tracks lose dynamics with no volume benefit.',
      fix: 'Reduce the limiter ceiling. Target -14 to -11 LUFS for streaming.',
      priority: 3,
    }));
  } else if (m.lufs < -20) {
    ins.push(insight({
      code: 'loudness_below_target',
      severity: 'warning',
      group: 'loudness',
      title: `Track is quiet (LUFS: ${m.lufs.toFixed(1)})`,
      detail: `Loudness is ${m.lufs.toFixed(1)} LUFS, below the -20 streaming minimum.`,
      why: 'Very quiet tracks get turned up by normalizers but may still sound weak compared to others.',
      fix: 'Apply gentle limiting or compression to bring loudness to -14 to -11 LUFS range.',
      priority: 4,
    }));
  } else if (m.lufs >= -16 && m.lufs <= -11) {
    ins.push(insight({
      code: 'loudness_optimal',
      severity: 'positive',
      group: 'loudness',
      title: `Optimal streaming loudness (LUFS: ${m.lufs.toFixed(1)})`,
      detail: `Loudness is ${m.lufs.toFixed(1)} LUFS — in the optimal range for Spotify/Apple Music.`,
      why: 'This range preserves dynamics while maintaining competitive loudness.',
      fix: '',
      priority: 10,
    }));
  }

  // Dynamic range
  if (m.dynamic_range < 5) {
    ins.push(insight({
      code: 'dynamic_range_low',
      severity: 'warning',
      group: 'loudness',
      title: `Very low dynamic range (${m.dynamic_range.toFixed(1)} dB)`,
      detail: `Dynamic range is only ${m.dynamic_range.toFixed(1)} dB.`,
      why: 'Low dynamic range makes the track sound flat and fatiguing to listen to.',
      fix: 'Reduce compression and limiting to allow more dynamics between quiet and loud sections.',
      priority: 5,
    }));
  }

  // Tempo stability
  if (m.tempo_stability < 0.6) {
    ins.push(insight({
      code: 'tempo_unstable',
      severity: 'warning',
      group: 'loudness',
      title: `Inconsistent tempo (${pct(m.tempo_stability)} stability)`,
      detail: `Beat timing varies significantly throughout the track.`,
      why: 'Unstable tempo can indicate timing issues in the performance or recording.',
      fix: 'Consider quantizing the performance or re-recording with a click track.',
      priority: 5,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// TRANSCRIPT RULES
// ══════════════════════════════════════════════════════════════

function transcriptRules(m: MeasuredData, ins: Insight[]) {
  const t = m.transcript;

  if (!t.text) {
    ins.push(insight({
      code: 'no_transcript',
      severity: 'info',
      group: 'transcript',
      title: 'No vocals/lyrics detected',
      detail: 'The transcription engine did not detect usable speech in the track.',
      why: 'Track appears instrumental — lyrics analysis will be skipped.',
      fix: '',
      priority: 8,
    }));
    return;
  }

  // Reliability flags
  const flags = t.reliability_flags || [];

  if (flags.includes('possible_hallucination')) {
    ins.push(insight({
      code: 'transcript_hallucination',
      severity: 'warning',
      group: 'transcript',
      title: 'Possible transcription hallucination detected',
      detail: `A single word dominates the transcript — Whisper may be repeating artifacts.`,
      why: 'Hallucinated transcripts will produce meaningless lyrics analysis.',
      fix: 'Provide lyrics manually for accurate analysis.',
      priority: 3,
    }));
  }

  if (flags.includes('low_confidence')) {
    ins.push(insight({
      code: 'transcript_low_confidence',
      severity: 'warning',
      group: 'transcript',
      title: `Low transcription confidence (${pct(t.confidence)})`,
      detail: `Whisper model confidence is ${pct(t.confidence)} — transcription may contain errors.`,
      why: 'Low-confidence transcripts produce unreliable lyrics analysis.',
      fix: 'Provide accurate lyrics manually for better analysis.',
      priority: 4,
    }));
  }

  if (flags.includes('uncertain_language')) {
    ins.push(insight({
      code: 'transcript_uncertain_language',
      severity: 'info',
      group: 'transcript',
      title: `Uncertain language detection (${pct(t.language_confidence)})`,
      detail: `Detected language "${t.language}" with only ${pct(t.language_confidence)} confidence.`,
      why: 'Incorrect language detection can affect transcription quality.',
      fix: '',
      priority: 7,
    }));
  }

  if (t.repeated_phrase_ratio > 0.5) {
    ins.push(insight({
      code: 'transcript_high_repetition',
      severity: 'info',
      group: 'transcript',
      title: `High phrase repetition in lyrics (${pct(t.repeated_phrase_ratio)})`,
      detail: `${pct(t.repeated_phrase_ratio)} of consecutive word pairs are repeated in the text.`,
      why: 'High repetition may indicate a hook-heavy track or transcription issues.',
      fix: '',
      priority: 8,
    }));
  }

  if (t.word_count > 0 && t.word_count < 30) {
    ins.push(insight({
      code: 'transcript_few_words',
      severity: 'info',
      group: 'transcript',
      title: `Very few words transcribed (${t.word_count})`,
      detail: `Only ${t.word_count} words were detected in the entire track.`,
      why: 'Very sparse lyrics may indicate the track is mostly instrumental with ad-libs.',
      fix: '',
      priority: 8,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// STRUCTURE RULES
// ══════════════════════════════════════════════════════════════

function structureRules(m: MeasuredData, ins: Insight[]) {
  const sections = m.section_candidates;

  // Section contrast
  if (sections.length > 1) {
    const energies = sections.map(s => s.energy);
    const maxE = Math.max(...energies);
    const minE = Math.min(...energies);
    const contrast = maxE > 0 ? (maxE - minE) / maxE : 0;

    if (contrast < 0.3) {
      ins.push(insight({
        code: 'low_section_contrast',
        severity: 'warning',
        group: 'structure',
        title: `Low dynamic contrast between sections (${pct(contrast)})`,
        detail: `Energy difference between loudest and quietest sections is only ${pct(contrast)}.`,
        why: 'Flat dynamics make the track feel monotonous — listeners need tension and release.',
        fix: 'Increase the energy gap between verses and choruses: drop elements in verses, add layers in choruses.',
        priority: 3,
      }));
    } else if (contrast > 0.7) {
      ins.push(insight({
        code: 'high_section_contrast',
        severity: 'positive',
        group: 'structure',
        title: `Strong dynamic contrast (${pct(contrast)})`,
        detail: `Good energy differentiation between sections.`,
        why: 'Clear verse/chorus contrast keeps listeners engaged through tension and release.',
        fix: '',
        priority: 10,
      }));
    }
  }

  // Section repetition score
  if (m.section_repetition_score !== undefined) {
    if (m.section_repetition_score < 0.15 && m.duration > 60) {
      ins.push(insight({
        code: 'low_section_repetition',
        severity: 'warning',
        group: 'structure',
        title: `Low section repetition (${pct(m.section_repetition_score)})`,
        detail: `Only ${pct(m.section_repetition_score)} of sections share a melodic fingerprint with another section.`,
        why: 'Lack of repetition makes the track harder to remember and reduces sing-along potential.',
        fix: 'Repeat the chorus or main section at least 2-3 times.',
        priority: 4,
      }));
    } else if (m.section_repetition_score > 0.5) {
      ins.push(insight({
        code: 'good_section_repetition',
        severity: 'positive',
        group: 'structure',
        title: `Good section repetition (${pct(m.section_repetition_score)})`,
        detail: `${pct(m.section_repetition_score)} of sections repeat — clear structure.`,
        why: 'Repeating sections help listeners learn the song and increase engagement.',
        fix: '',
        priority: 10,
      }));
    }
  }

  // No drop detected
  if (m.drop_candidates.length === 0 && m.duration > 60) {
    ins.push(insight({
      code: 'no_drop',
      severity: 'info',
      group: 'structure',
      title: 'No significant energy drop detected',
      detail: 'The track maintains relatively consistent energy without a clear breakdown moment.',
      why: 'A well-placed energy drop adds drama and makes the return feel more powerful.',
      fix: 'Consider adding a breakdown before the final chorus for impact.',
      priority: 7,
    }));
  }

  // First chorus timing
  if (m.first_chorus_candidate_time !== null && m.first_chorus_candidate_time > 60) {
    ins.push(insight({
      code: 'chorus_late',
      severity: 'warning',
      group: 'structure',
      title: `First chorus candidate at ${m.first_chorus_candidate_time.toFixed(0)}s`,
      detail: `The first chorus-like section appears at ${m.first_chorus_candidate_time.toFixed(0)}s.`,
      why: 'Late choruses risk losing listeners who expect payoff within the first minute.',
      fix: 'Restructure to reach the first chorus within 30-45 seconds.',
      priority: 3,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// GENRE CONFIDENCE RULES
// ══════════════════════════════════════════════════════════════

function genreConfidenceRules(m: MeasuredData, ins: Insight[]) {
  const gc = m.genre_confidence ?? (m.genre_candidates.length > 0 ? m.genre_candidates[0].confidence : 0);

  if (gc < 0.5) {
    ins.push(insight({
      code: 'genre_uncertain',
      severity: 'info',
      group: 'genre',
      title: `Genre detection uncertain (${pct(gc)} confidence)`,
      detail: `Detected "${m.primary_genre}" but with low confidence — the track may blend genres.`,
      why: 'Ambiguous genre can make playlist placement harder.',
      fix: '',
      priority: 8,
    }));
  }

  // BPM sweet spot
  if (m.bpm.bpm >= 100 && m.bpm.bpm <= 140) {
    ins.push(insight({
      code: 'bpm_sweet_spot',
      severity: 'positive',
      group: 'genre',
      title: `BPM ${m.bpm.bpm} in streaming sweet spot (100-140)`,
      detail: `This tempo range works well for most modern commercial genres.`,
      why: 'BPM 100-140 covers Pop, EDM, Hip-Hop, and most mainstream genres.',
      fix: '',
      priority: 10,
    }));
  }

  // Key detection confidence
  if (m.key.confidence < 0.5) {
    ins.push(insight({
      code: 'key_uncertain',
      severity: 'info',
      group: 'genre',
      title: `Key detection uncertain (${pct(m.key.confidence)})`,
      detail: `Detected ${m.key.key} but with low confidence — the track may be atonal or use frequent key changes.`,
      why: 'Inaccurate key detection can affect pitch analysis and compatibility recommendations.',
      fix: '',
      priority: 9,
    }));
  }
}

// ══════════════════════════════════════════════════════════════
// MIX RULES
// ══════════════════════════════════════════════════════════════

function mixRules(m: MeasuredData, ins: Insight[]) {
  const fb = m.spectral.freq_bands;
  const bassTotal = (fb.sub_bass + fb.bass) * 100;
  const highTotal = (fb.high + fb.upper_mid + fb.brilliance) * 100;

  if (bassTotal > 50) {
    ins.push(insight({
      code: 'bass_heavy',
      severity: 'warning',
      group: 'mix',
      title: `Bass-heavy mix (${bassTotal.toFixed(0)}% of energy)`,
      detail: `${bassTotal.toFixed(0)}% of total spectral energy is in bass frequencies.`,
      why: 'Excessive bass energy will sound muddy on small speakers and earbuds.',
      fix: 'High-pass filter non-bass instruments, use sidechain compression on bass against kick.',
      priority: 4,
    }));
  }

  if (highTotal < 10) {
    ins.push(insight({
      code: 'high_freq_lacking',
      severity: 'warning',
      group: 'mix',
      title: `Low high-frequency presence (${highTotal.toFixed(0)}%)`,
      detail: `Only ${highTotal.toFixed(0)}% of spectral energy is above 2kHz.`,
      why: 'Track may sound dull and lack clarity, especially vocals.',
      fix: 'Add air/presence EQ (8-12kHz), check if high frequencies were lost in compression.',
      priority: 5,
    }));
  }
}

// ── Hit Score Calculator ────────────────────────────────────

function calculateHitScore(p: {
  hookTime: number;
  introWeak: boolean;
  energyVariation: number;
  earlyEnergyRatio: number;
  peakEnergy: number;
  rms: number;
  bpm: number;
  dynamicRange: number;
  tempoStability: number;
  duration: number;
  spectralFlux: number;
  lufs: number;
}): number {
  let score = 50;

  if (p.hookTime > 0) {
    if (p.hookTime < 15) score += 15;
    else if (p.hookTime < 30) score += 10;
    else if (p.hookTime < 45) score += 5;
  }

  if (p.introWeak) score -= 20;

  if (p.energyVariation > 0.5) score += 15;
  else if (p.energyVariation > 0.3) score += 8;

  if (p.earlyEnergyRatio < 0.5) score -= 15;
  else if (p.earlyEnergyRatio < 0.7) score -= 8;

  if (p.peakEnergy > 0.15) score += 10;
  else if (p.peakEnergy > 0.10) score += 5;

  if (p.bpm >= 100 && p.bpm <= 140) score += 5;
  if (p.dynamicRange > 10) score += 5;
  if (p.tempoStability > 0.8) score += 5;

  if (p.duration > 300) score -= 5;
  else if (p.duration < 30) score -= 10;

  if (p.spectralFlux > 0.02) score += 5;
  else if (p.spectralFlux < 0.005) score -= 3;

  if (p.lufs > -10) score += 3;
  else if (p.lufs < -20) score -= 5;

  return Math.max(0, Math.min(100, score));
}

// ── Helpers ─────────────────────────────────────────────────

function insight(p: {
  code: string;
  severity: InsightSeverity;
  group: InsightGroup;
  title: string;
  detail: string;
  why: string;
  fix: string;
  priority: number;
}): Insight {
  return {
    code: p.code,
    severity: p.severity,
    group: p.group,
    title: p.title,
    detail: p.detail,
    why_this_matters: p.why,
    suggested_fix: p.fix,
    priority: p.priority,
  };
}

function pct(v: number): string {
  return `${(v * 100).toFixed(0)}%`;
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function round3(v: number): number { return Math.round(v * 1000) / 1000; }
function round4(v: number): number { return Math.round(v * 10000) / 10000; }
