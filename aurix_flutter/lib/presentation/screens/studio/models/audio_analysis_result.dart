import 'dart:convert';
import 'dart:ui' show Color;

/// Single point in the energy-over-time structure.
class StructurePoint {
  final double time;
  final double energy;

  const StructurePoint({required this.time, required this.energy});

  factory StructurePoint.fromJson(Map<String, dynamic> j) => StructurePoint(
        time: (j['time'] as num?)?.toDouble() ?? 0,
        energy: (j['energy'] as num?)?.toDouble() ?? 0,
      );
}

/// Section detected from audio analysis.
class AudioSection {
  final double start;
  final double end;
  final String type;
  final double energy;

  const AudioSection({
    required this.start,
    required this.end,
    required this.type,
    required this.energy,
  });

  factory AudioSection.fromJson(Map<String, dynamic> j) => AudioSection(
        start: (j['start'] as num?)?.toDouble() ?? 0,
        end: (j['end'] as num?)?.toDouble() ?? 0,
        type: j['type'] as String? ?? 'unknown',
        energy: (j['energy'] as num?)?.toDouble() ?? 0,
      );
}

/// Timestamp-specific fix suggestion from AI.
class FixTimestamp {
  final double time;
  final String issue;
  final String fix;

  const FixTimestamp({required this.time, required this.issue, required this.fix});

  factory FixTimestamp.fromJson(Map<String, dynamic> j) => FixTimestamp(
        time: (j['time'] as num?)?.toDouble() ?? 0,
        issue: j['issue'] as String? ?? '',
        fix: j['fix'] as String? ?? '',
      );
}

/// Improvement with timestamp from AI.
class Improvement {
  final double time;
  final String action;

  const Improvement({required this.time, required this.action});

  factory Improvement.fromJson(Map<String, dynamic> j) => Improvement(
        time: (j['time'] as num?)?.toDouble() ?? 0,
        action: j['action'] as String? ?? '',
      );
}

/// Full result from POST /api/ai/analyze-track.
class AudioAnalysisResult {
  // Raw metrics from Python
  final double bpm;
  final double duration;
  final double energy;
  final double brightness;
  final double tempoStability;
  final double spectralContrast;
  final double onsetDensity;
  final double dynamicRange;
  final String estimatedKey;
  final List<AudioSection> sections;
  final List<StructurePoint> structure;
  final double hookTime;
  final double dropTime;
  final bool introWeak;

  // Hit predictor metrics
  final double energyVariation;
  final double peakEnergy;
  final double energyStd;
  final double earlyEnergy;

  // Hit predictor scores (from Python + NestJS)
  final int hitScore;
  final int viralProbability;

  // AI analysis
  final double score;
  final String verdict;
  final String genreGuess;
  final int viralProbabilityAi;
  final String mainProblem;
  final String killerIssue;
  final bool canBeHit;
  final String hitRecipe;
  final List<String> strengths;
  final List<String> problems;
  final List<Improvement> improvementsDetailed;
  final double hookPotential;
  final double productionQuality;
  final double viralPotential;
  final double playlistChance;
  final String bestTiktokSegment;
  final String mixNotes;
  final String marketFit;
  final String structureVerdict;
  final String hookAnalysis;
  final String dropAnalysis;
  final String introAnalysis;
  final String listenerDropout;
  final String retentionKiller;
  final List<FixTimestamp> fixTimestamps;
  final String finalOpinion;
  final String? lyrics;
  final String lyricsAnalysis;
  final String genre;

  const AudioAnalysisResult({
    required this.bpm,
    required this.duration,
    required this.energy,
    required this.brightness,
    required this.tempoStability,
    required this.spectralContrast,
    required this.onsetDensity,
    required this.dynamicRange,
    required this.estimatedKey,
    required this.sections,
    required this.structure,
    required this.hookTime,
    required this.dropTime,
    required this.introWeak,
    required this.energyVariation,
    required this.peakEnergy,
    required this.energyStd,
    required this.earlyEnergy,
    required this.hitScore,
    required this.viralProbability,
    required this.score,
    required this.verdict,
    required this.genreGuess,
    required this.viralProbabilityAi,
    required this.mainProblem,
    required this.killerIssue,
    required this.canBeHit,
    required this.hitRecipe,
    required this.strengths,
    required this.problems,
    required this.improvementsDetailed,
    required this.hookPotential,
    required this.productionQuality,
    required this.viralPotential,
    required this.playlistChance,
    required this.bestTiktokSegment,
    required this.mixNotes,
    required this.marketFit,
    required this.structureVerdict,
    required this.hookAnalysis,
    required this.dropAnalysis,
    required this.introAnalysis,
    required this.listenerDropout,
    required this.retentionKiller,
    required this.fixTimestamps,
    required this.finalOpinion,
    this.lyrics,
    this.lyricsAnalysis = '',
    this.genre = '',
  });

  /// Parse from API response.
  factory AudioAnalysisResult.fromApiResponse(Map<String, dynamic> resp) {
    final metrics = resp['audioMetrics'] as Map<String, dynamic>? ?? {};
    final aiRaw = resp['aiAnalysis'] as String? ?? '{}';
    final apiScore = (resp['score'] as num?)?.toDouble() ?? 5.0;
    final apiHitScore = (resp['hitScore'] as num?)?.toInt() ?? (metrics['hit_score'] as num?)?.toInt() ?? 50;
    final apiViralProb = (resp['viralProbability'] as num?)?.toInt() ?? 0;

    // Parse AI JSON
    Map<String, dynamic> ai = {};
    try {
      var cleaned = aiRaw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```\w*\n?'), '')
            .replaceFirst(RegExp(r'\n?```$'), '');
      }
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) ai = parsed;
    } catch (_) {}

    final aiViralProb = (ai['viral_probability'] as num?)?.toInt() ?? apiViralProb;

    return AudioAnalysisResult(
      bpm: (metrics['bpm'] as num?)?.toDouble() ?? 0,
      duration: (metrics['duration'] as num?)?.toDouble() ?? 0,
      energy: (metrics['energy'] as num?)?.toDouble() ?? 0,
      brightness: (metrics['brightness'] as num?)?.toDouble() ?? 0,
      tempoStability: (metrics['tempo_stability'] as num?)?.toDouble() ?? 0,
      spectralContrast: (metrics['spectral_contrast'] as num?)?.toDouble() ?? 0,
      onsetDensity: (metrics['onset_density'] as num?)?.toDouble() ?? 0,
      dynamicRange: (metrics['dynamic_range'] as num?)?.toDouble() ?? 0,
      estimatedKey: metrics['estimated_key'] as String? ?? '?',
      sections: (metrics['sections'] as List<dynamic>?)
              ?.map((s) => AudioSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      structure: (metrics['structure'] as List<dynamic>?)
              ?.map((s) => StructurePoint.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      hookTime: (metrics['hook_time'] as num?)?.toDouble() ?? 0,
      dropTime: (metrics['drop_time'] as num?)?.toDouble() ?? 0,
      introWeak: metrics['intro_weak'] as bool? ?? false,
      energyVariation: (metrics['energy_variation'] as num?)?.toDouble() ?? 0,
      peakEnergy: (metrics['peak_energy'] as num?)?.toDouble() ?? 0,
      energyStd: (metrics['energy_std'] as num?)?.toDouble() ?? 0,
      earlyEnergy: (metrics['early_energy'] as num?)?.toDouble() ?? 0,
      hitScore: apiHitScore,
      viralProbability: aiViralProb > 0 ? aiViralProb : apiViralProb,
      score: (ai['score'] as num?)?.toDouble() ?? apiScore,
      verdict: ai['verdict'] as String? ?? '',
      genreGuess: ai['genre'] as String? ?? ai['genre_guess'] as String? ?? resp['genre'] as String? ?? '',
      viralProbabilityAi: aiViralProb,
      mainProblem: ai['main_problem'] as String? ?? '',
      killerIssue: ai['killer_issue'] as String? ?? '',
      canBeHit: ai['can_be_hit'] as bool? ?? false,
      hitRecipe: ai['hit_recipe'] as String? ?? '',
      strengths: _strList(ai['strengths']),
      problems: _strList(ai['problems']),
      improvementsDetailed: (ai['improvements'] as List<dynamic>?)
              ?.map((f) {
                if (f is Map<String, dynamic>) return Improvement.fromJson(f);
                return Improvement(time: 0, action: f.toString());
              })
              .toList() ??
          [],
      hookPotential: (ai['hook_potential'] as num?)?.toDouble() ?? 0,
      productionQuality: (ai['production_quality'] as num?)?.toDouble() ?? 0,
      viralPotential: (ai['viral_potential'] as num?)?.toDouble() ?? 0,
      playlistChance: (ai['playlist_chance'] as num?)?.toDouble() ?? 0,
      bestTiktokSegment: ai['best_tiktok_segment'] as String? ?? '',
      mixNotes: ai['mix_notes'] as String? ?? '',
      marketFit: ai['market_fit'] as String? ?? '',
      structureVerdict: ai['structure_verdict'] as String? ?? '',
      hookAnalysis: ai['hook_analysis'] as String? ?? '',
      dropAnalysis: ai['drop_analysis'] as String? ?? '',
      introAnalysis: ai['intro_analysis'] as String? ?? '',
      listenerDropout: ai['listener_dropout'] as String? ?? '',
      retentionKiller: ai['retention_killer'] as String? ?? '',
      fixTimestamps: (ai['fix_timestamps'] as List<dynamic>?)
              ?.map((f) => FixTimestamp.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      finalOpinion: ai['final_opinion'] as String? ?? '',
      lyrics: resp['lyrics'] as String? ?? metrics['lyrics'] as String?,
      lyricsAnalysis: ai['lyrics_analysis'] as String? ?? '',
      genre: resp['genre'] as String? ?? ai['genre'] as String? ?? '',
    );
  }

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = (duration % 60).toInt();
    return '${m}:${s.toString().padLeft(2, '0')}';
  }

  String get hitVerdict {
    if (hitScore >= 70) return 'Потенциальный хит';
    if (hitScore >= 40) return 'Есть потенциал';
    return 'Трек не зайдёт';
  }

  Color get hitColor {
    if (hitScore >= 70) return const Color(0xFF22C55E);
    if (hitScore >= 40) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
