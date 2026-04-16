// ══════════════════════════════════════════════════════════════
// Improved Track Service
// Analysis-guided track improvement flow:
// original analysis → improvement payload → generation prompt
// ══════════════════════════════════════════════════════════════

import { Injectable, Logger } from '@nestjs/common';
import {
  TrackAnalysisResponse,
  MeasuredData,
  DerivedInsights,
  AiExplanation,
  Insight,
} from './analysis.dto';

// ── Types ───────────────────────────────────────────────────

export type GenerationMode = 'soft_improve' | 'hit_rebuild' | 'alt_vision';

export interface ImprovementPayload {
  source_track_reference: {
    analysis_id: number;
    filename: string;
  };
  genre: string;
  bpm: { value: number; confidence: number };
  key: { value: string; confidence: number };
  duration: number;
  lyrics: string | null;
  main_hook_time: number | null;
  first_vocal_time: number | null;
  first_chorus_candidate_time: number | null;
  section_repetition_score: number;
  intro_metrics: {
    ratio: number;
    vocal_presence: boolean;
    transition_strength: number;
  };
  confidence: {
    overall: number;
    hook: number;
    structure: number;
    transcript: number;
  };
  improvement_points: Array<{
    code: string;
    title: string;
    severity: string;
    suggested_fix: string;
    priority: number;
  }>;
  generation_mode: GenerationMode;
  preservation_rules: string[];
  targets: {
    hook_target_window: string;
    intro_strategy: string;
    chorus_energy_target: string;
    structure_clarity_target: string;
  };
}

export interface GenerationResult {
  status: 'queued';
  mode: GenerationMode;
  payload: ImprovementPayload;
  prompt_used: string;
  preview_notes: string[];
}

// ── Service ─────────────────────────────────────────────────

@Injectable()
export class ImprovedTrackService {
  private readonly logger = new Logger(ImprovedTrackService.name);

  // ══════════════════════════════════════════════════════════
  // A. Build improvement payload from analysis
  // ══════════════════════════════════════════════════════════

  buildImprovementPayload(
    analysisId: number,
    filename: string,
    analysis: TrackAnalysisResponse,
    mode: GenerationMode,
  ): ImprovementPayload {
    const m = analysis.measured_data;
    const d = analysis.derived_insights;

    // Extract actionable improvement points (warning + critical only)
    const improvementPoints = d.insights
      .filter(i => i.severity === 'critical' || i.severity === 'warning')
      .sort((a, b) => a.priority - b.priority)
      .slice(0, 8)
      .map(i => ({
        code: i.code,
        title: i.title,
        severity: i.severity,
        suggested_fix: i.suggested_fix,
        priority: i.priority,
      }));

    // Build targets based on current state + mode
    const targets = this.buildTargets(m, d, mode);
    const preservationRules = this.buildPreservationRules(m, mode);

    return {
      source_track_reference: { analysis_id: analysisId, filename },
      genre: m.primary_genre || d.genre,
      bpm: { value: m.bpm.bpm, confidence: m.bpm.agreement },
      key: { value: m.key.key, confidence: m.key.confidence },
      duration: m.duration,
      lyrics: m.transcript.text,
      main_hook_time: m.main_hook_candidate?.time ?? null,
      first_vocal_time: m.first_vocal_time ?? null,
      first_chorus_candidate_time: m.first_chorus_candidate_time ?? null,
      section_repetition_score: m.section_repetition_score ?? 0,
      intro_metrics: {
        ratio: m.intro_metrics.ratio,
        vocal_presence: m.intro_metrics.intro_vocal_presence,
        transition_strength: m.intro_metrics.intro_transition_strength,
      },
      confidence: {
        overall: d.confidence.overall_analysis_confidence,
        hook: d.confidence.hook_confidence,
        structure: d.confidence.structure_confidence,
        transcript: d.confidence.transcript_confidence,
      },
      improvement_points: improvementPoints,
      generation_mode: mode,
      preservation_rules: preservationRules,
      targets,
    };
  }

  // ══════════════════════════════════════════════════════════
  // B. Build generation prompt from payload
  // ══════════════════════════════════════════════════════════

  buildGenerationPrompt(payload: ImprovementPayload): string {
    switch (payload.generation_mode) {
      case 'soft_improve':
        return this.buildSoftImprovePrompt(payload);
      case 'hit_rebuild':
        return this.buildHitRebuildPrompt(payload);
      case 'alt_vision':
        return this.buildAltVisionPrompt(payload);
    }
  }

  // ══════════════════════════════════════════════════════════
  // C. Generate improved track (mock)
  // ══════════════════════════════════════════════════════════

  generateImprovedTrackMock(
    analysisId: number,
    filename: string,
    analysis: TrackAnalysisResponse,
    mode: GenerationMode,
  ): GenerationResult {
    const payload = this.buildImprovementPayload(analysisId, filename, analysis, mode);
    const prompt = this.buildGenerationPrompt(payload);

    const previewNotes = this.buildPreviewNotes(payload);

    this.logger.log(
      `[ImprovedTrack] analysis_id=${analysisId} mode=${mode} ` +
      `genre=${payload.genre} bpm=${payload.bpm.value} key=${payload.key.value} ` +
      `improvements=${payload.improvement_points.length} ` +
      `prompt_length=${prompt.length}`,
    );

    this.logger.log(
      `[ImprovedTrack] payload_summary: ` +
      `hook=${payload.main_hook_time ?? 'none'}s, ` +
      `vocal=${payload.first_vocal_time ?? 'none'}s, ` +
      `chorus=${payload.first_chorus_candidate_time ?? 'none'}s, ` +
      `rep_score=${payload.section_repetition_score}, ` +
      `intro_ratio=${payload.intro_metrics.ratio}, ` +
      `confidence=${payload.confidence.overall}`,
    );

    this.logger.log(
      `[ImprovedTrack] prompt_summary: mode=${mode}, ` +
      `preservation_rules=${payload.preservation_rules.length}, ` +
      `targets=${Object.keys(payload.targets).length}, ` +
      `first_100_chars="${prompt.slice(0, 100)}..."`,
    );

    return {
      status: 'queued',
      mode,
      payload,
      prompt_used: prompt,
      preview_notes: previewNotes,
    };
  }

  // ══════════════════════════════════════════════════════════
  // PRIVATE — Targets
  // ══════════════════════════════════════════════════════════

  private buildTargets(
    m: MeasuredData,
    d: DerivedInsights,
    mode: GenerationMode,
  ): ImprovementPayload['targets'] {
    // Hook target
    let hookTarget: string;
    const hookTime = d.hook_time;
    if (hookTime <= 15) {
      hookTarget = 'maintain_early_hook';
    } else if (hookTime <= 30) {
      hookTarget = mode === 'hit_rebuild' ? 'move_hook_under_15s' : 'keep_current_hook_timing';
    } else {
      hookTarget = 'move_hook_under_15s';
    }

    // Intro strategy
    let introStrategy: string;
    if (d.intro_weak) {
      introStrategy = mode === 'soft_improve'
        ? 'add_energy_to_intro'
        : 'shorten_intro_or_add_hook_teaser';
    } else if (!m.intro_metrics.intro_vocal_presence && m.first_vocal_time && m.first_vocal_time > 10) {
      introStrategy = 'add_vocal_element_to_intro';
    } else {
      introStrategy = 'maintain_intro';
    }

    // Chorus energy
    let chorusEnergy: string;
    const sections = m.section_candidates;
    if (sections.length > 1) {
      const energies = sections.map(s => s.energy);
      const maxE = Math.max(...energies);
      const minE = Math.min(...energies);
      const contrast = maxE > 0 ? (maxE - minE) / maxE : 0;
      if (contrast < 0.3) {
        chorusEnergy = 'increase_chorus_energy_contrast';
      } else {
        chorusEnergy = 'maintain_chorus_energy';
      }
    } else {
      chorusEnergy = 'create_clear_chorus_section';
    }

    // Structure clarity
    let structureClarity: string;
    const repScore = m.section_repetition_score ?? 0;
    if (repScore < 0.2) {
      structureClarity = 'add_repeating_sections';
    } else if (repScore > 0.5) {
      structureClarity = 'maintain_clear_structure';
    } else {
      structureClarity = mode === 'hit_rebuild' ? 'strengthen_verse_chorus_pattern' : 'keep_current_structure';
    }

    return {
      hook_target_window: hookTarget,
      intro_strategy: introStrategy,
      chorus_energy_target: chorusEnergy,
      structure_clarity_target: structureClarity,
    };
  }

  // ══════════════════════════════════════════════════════════
  // PRIVATE — Preservation rules
  // ══════════════════════════════════════════════════════════

  private buildPreservationRules(m: MeasuredData, mode: GenerationMode): string[] {
    const rules: string[] = [];

    // Always preserve
    rules.push('keep_emotional_tone');
    if (m.transcript.text) {
      rules.push('keep_core_lyrical_idea');
      if (m.transcript.language) {
        rules.push(`preserve_language:${m.transcript.language}`);
      }
    }

    switch (mode) {
      case 'soft_improve':
        rules.push('keep_bpm_range');
        rules.push('keep_key');
        rules.push('keep_genre');
        rules.push('keep_overall_arrangement');
        rules.push('preserve_vocal_style');
        break;

      case 'hit_rebuild':
        rules.push('keep_bpm_range');
        rules.push('keep_genre_family');
        // key can change, arrangement changes allowed
        break;

      case 'alt_vision':
        // Minimal preservation — only emotional core + lyrics
        rules.push('keep_core_melody_motif');
        break;
    }

    return rules;
  }

  // ══════════════════════════════════════════════════════════
  // PRIVATE — Prompt builders per mode
  // ══════════════════════════════════════════════════════════

  private buildSoftImprovePrompt(p: ImprovementPayload): string {
    const lines: string[] = [];

    lines.push('=== TASK: SOFT IMPROVEMENT ===');
    lines.push('Improve this existing track while preserving its identity. Do NOT replace the song — enhance it.');
    lines.push('');

    this.appendTrackContext(lines, p);

    lines.push('');
    lines.push('=== IMPROVEMENT MODE: SOFT ===');
    lines.push('Approach: Fix specific issues while keeping the overall feel, arrangement, tempo, and key intact.');
    lines.push('Think of this as a remix/remaster, not a rewrite.');
    lines.push('');

    this.appendImprovements(lines, p);
    this.appendTargets(lines, p);
    this.appendPreservation(lines, p);

    lines.push('');
    lines.push('=== GENERATION CONSTRAINTS ===');
    lines.push(`- BPM: ${p.bpm.value} (keep exact)`);
    lines.push(`- Key: ${p.key.value} (keep exact)`);
    lines.push(`- Genre: ${p.genre} (keep exact)`);
    lines.push(`- Duration: similar to original (~${Math.round(p.duration)}s)`);
    lines.push('- Vocal style: maintain original character');
    lines.push('- Mix: apply fixes but keep sonic signature');

    return lines.join('\n');
  }

  private buildHitRebuildPrompt(p: ImprovementPayload): string {
    const lines: string[] = [];

    lines.push('=== TASK: HIT REBUILD ===');
    lines.push('Rebuild this track for maximum streaming performance. Prioritize retention, hook clarity, and commercial appeal.');
    lines.push('You may restructure the arrangement, change the key, and rework production — but keep the emotional core.');
    lines.push('');

    this.appendTrackContext(lines, p);

    lines.push('');
    lines.push('=== IMPROVEMENT MODE: HIT REBUILD ===');
    lines.push('Approach: Aggressive restructuring for streaming success. Focus on:');
    lines.push('1. Hook within first 15 seconds');
    lines.push('2. Strong, energy-rich intro (no dead air)');
    lines.push('3. Clear verse-chorus contrast');
    lines.push('4. Chorus that repeats 3+ times');
    lines.push('5. Streaming-optimized duration (2:30-3:30)');
    lines.push('');

    this.appendImprovements(lines, p);
    this.appendTargets(lines, p);
    this.appendPreservation(lines, p);

    lines.push('');
    lines.push('=== GENERATION CONSTRAINTS ===');
    lines.push(`- BPM: ${p.bpm.value} (±5 allowed)`);
    lines.push(`- Key: flexible (original: ${p.key.value})`);
    lines.push(`- Genre: ${p.genre} or close subgenre`);
    lines.push(`- Duration: 2:30-3:30 for streaming`);
    lines.push('- Production: modern, loud (-11 to -14 LUFS), competitive');
    lines.push('- Structure: intro(≤8s) → verse → chorus → verse → chorus → bridge → final chorus → outro');

    return lines.join('\n');
  }

  private buildAltVisionPrompt(p: ImprovementPayload): string {
    const lines: string[] = [];

    lines.push('=== TASK: ALTERNATIVE VISION ===');
    lines.push('Reimagine this track in a different creative direction. Keep the emotional core and lyrical idea,');
    lines.push('but explore a new genre, tempo, or production style. Think "what if this song was born in a different universe?"');
    lines.push('');

    this.appendTrackContext(lines, p);

    lines.push('');
    lines.push('=== IMPROVEMENT MODE: ALT VISION ===');
    lines.push('Approach: Creative reimagining. You have freedom to:');
    lines.push('- Change genre entirely');
    lines.push('- Change tempo and key');
    lines.push('- Rework production style');
    lines.push('- Restructure arrangement');
    lines.push('');
    lines.push('But you MUST:');
    lines.push('- Preserve the emotional tone (sad stays sad, hype stays hype)');
    lines.push('- Keep the core melodic motif or hook idea');
    if (p.lyrics) {
      lines.push(`- Keep the lyrical theme and language (${p.preservation_rules.find(r => r.startsWith('preserve_language'))?.split(':')[1] || 'original'})`);
    }
    lines.push('');

    // Suggest alternative directions based on current genre
    lines.push('=== SUGGESTED DIRECTIONS ===');
    const alts = this.suggestAltDirections(p.genre);
    for (const alt of alts) {
      lines.push(`- ${alt}`);
    }
    lines.push('');

    this.appendImprovements(lines, p);

    lines.push('');
    lines.push('=== GENERATION CONSTRAINTS ===');
    lines.push('- BPM: free choice (original was ' + p.bpm.value + ')');
    lines.push('- Key: free choice');
    lines.push('- Genre: different from original');
    lines.push(`- Duration: flexible`);
    lines.push('- Production: high quality, genre-appropriate');

    return lines.join('\n');
  }

  // ══════════════════════════════════════════════════════════
  // PRIVATE — Prompt helpers
  // ══════════════════════════════════════════════════════════

  private appendTrackContext(lines: string[], p: ImprovementPayload) {
    lines.push('=== ORIGINAL TRACK ===');
    lines.push(`Genre: ${p.genre}`);
    lines.push(`BPM: ${p.bpm.value} (confidence: ${pct(p.bpm.confidence)})`);
    lines.push(`Key: ${p.key.value} (confidence: ${pct(p.key.confidence)})`);
    lines.push(`Duration: ${fmtTime(p.duration)}`);

    if (p.main_hook_time !== null) {
      lines.push(`Main hook: ${p.main_hook_time}s`);
    } else {
      lines.push('Main hook: not detected (weak/absent)');
    }

    if (p.first_vocal_time !== null) {
      lines.push(`First vocal: ${p.first_vocal_time}s`);
    }

    if (p.first_chorus_candidate_time !== null) {
      lines.push(`First chorus: ~${p.first_chorus_candidate_time}s`);
    }

    lines.push(`Section repetition: ${pct(p.section_repetition_score)}`);
    lines.push(`Intro energy ratio: ${pct(p.intro_metrics.ratio)} | vocal in intro: ${p.intro_metrics.vocal_presence ? 'yes' : 'no'} | transition: ${pct(p.intro_metrics.transition_strength)}`);
    lines.push(`Analysis confidence: ${pct(p.confidence.overall)}`);

    if (p.lyrics) {
      lines.push('');
      lines.push('Lyrics (transcribed):');
      lines.push(p.lyrics.slice(0, 800));
    }
  }

  private appendImprovements(lines: string[], p: ImprovementPayload) {
    if (p.improvement_points.length === 0) {
      lines.push('=== NO CRITICAL ISSUES DETECTED ===');
      return;
    }

    lines.push('=== ISSUES TO FIX ===');
    for (const ip of p.improvement_points) {
      const icon = ip.severity === 'critical' ? '[!!!]' : '[!]';
      lines.push(`${icon} ${ip.title}`);
      if (ip.suggested_fix) {
        lines.push(`    Fix: ${ip.suggested_fix}`);
      }
    }
  }

  private appendTargets(lines: string[], p: ImprovementPayload) {
    lines.push('');
    lines.push('=== TARGETS ===');
    lines.push(`Hook: ${formatTarget(p.targets.hook_target_window)}`);
    lines.push(`Intro: ${formatTarget(p.targets.intro_strategy)}`);
    lines.push(`Chorus energy: ${formatTarget(p.targets.chorus_energy_target)}`);
    lines.push(`Structure: ${formatTarget(p.targets.structure_clarity_target)}`);
  }

  private appendPreservation(lines: string[], p: ImprovementPayload) {
    lines.push('');
    lines.push('=== PRESERVATION RULES ===');
    for (const rule of p.preservation_rules) {
      lines.push(`- ${formatTarget(rule)}`);
    }
  }

  private suggestAltDirections(genre: string): string[] {
    const mapping: Record<string, string[]> = {
      'Pop': ['Lo-Fi / Chill version', 'Acoustic stripped-back', 'EDM / Dance remix', 'R&B reinterpretation'],
      'Trap': ['Lo-Fi / Chill rework', 'Pop crossover', 'Phonk reimagining', 'Acoustic version'],
      'Hip-Hop / Rap': ['R&B version', 'Pop crossover', 'Lo-Fi / Chill', 'Jazz-hop remix'],
      'R&B': ['Pop version', 'Lo-Fi / Chill', 'Acoustic', 'EDM / Dance remix'],
      'EDM / Dance': ['Pop acoustic version', 'Lo-Fi / Chill remix', 'Trap rework', 'Indie electronic'],
      'Lo-Fi / Chill': ['Pop production', 'R&B version', 'EDM / Dance build', 'Jazz fusion'],
      'Rock': ['Acoustic unplugged', 'Electronic/synth version', 'Pop rock crossover', 'Lo-Fi / Chill remake'],
      'Phonk': ['Trap version', 'Lo-Fi / Chill', 'EDM / Dance crossover', 'Dark pop'],
    };

    return mapping[genre] || [
      'Acoustic / stripped version',
      'Electronic / synth rework',
      'Lo-Fi / Chill reimagining',
      'Pop crossover version',
    ];
  }

  private buildPreviewNotes(p: ImprovementPayload): string[] {
    const notes: string[] = [];

    notes.push(`Mode: ${formatTarget(p.generation_mode)}`);
    notes.push(`Genre: ${p.genre} → ${p.generation_mode === 'alt_vision' ? 'new direction' : 'same'}`);
    notes.push(`BPM: ${p.bpm.value} → ${p.generation_mode === 'alt_vision' ? 'flexible' : p.bpm.value}`);

    if (p.improvement_points.length > 0) {
      const topFix = p.improvement_points[0];
      notes.push(`Primary fix: ${topFix.title}`);
    }

    notes.push(`Hook strategy: ${formatTarget(p.targets.hook_target_window)}`);
    notes.push(`Intro strategy: ${formatTarget(p.targets.intro_strategy)}`);

    if (p.lyrics) {
      notes.push(`Lyrics: preserved (${p.lyrics.split(/\s+/).length} words)`);
    } else {
      notes.push('Lyrics: instrumental');
    }

    notes.push(`Preservation: ${p.preservation_rules.length} rules`);

    return notes;
  }
}

// ── Helpers ─────────────────────────────────────────────────

function pct(v: number): string {
  return `${(v * 100).toFixed(0)}%`;
}

function fmtTime(seconds: number): string {
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function formatTarget(code: string): string {
  return code.replace(/_/g, ' ').replace(/:/g, ': ');
}
