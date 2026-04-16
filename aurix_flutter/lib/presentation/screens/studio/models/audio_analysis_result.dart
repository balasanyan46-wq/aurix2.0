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

/// Frequency band energy breakdown.
class FreqBands {
  final double subBass;
  final double bass;
  final double lowMid;
  final double mid;
  final double upperMid;
  final double high;
  final double brilliance;

  const FreqBands({
    this.subBass = 0,
    this.bass = 0,
    this.lowMid = 0,
    this.mid = 0,
    this.upperMid = 0,
    this.high = 0,
    this.brilliance = 0,
  });

  factory FreqBands.fromJson(Map<String, dynamic> j) => FreqBands(
        subBass: (j['sub_bass'] as num?)?.toDouble() ?? 0,
        bass: (j['bass'] as num?)?.toDouble() ?? 0,
        lowMid: (j['low_mid'] as num?)?.toDouble() ?? 0,
        mid: (j['mid'] as num?)?.toDouble() ?? 0,
        upperMid: (j['upper_mid'] as num?)?.toDouble() ?? 0,
        high: (j['high'] as num?)?.toDouble() ?? 0,
        brilliance: (j['brilliance'] as num?)?.toDouble() ?? 0,
      );

  List<MapEntry<String, double>> get entries => [
        MapEntry('Sub', subBass),
        MapEntry('Bass', bass),
        MapEntry('Low', lowMid),
        MapEntry('Mid', mid),
        MapEntry('Hi-Mid', upperMid),
        MapEntry('High', high),
        MapEntry('Air', brilliance),
      ];
}

/// Key moment in the track identified by AI.
class KeyMoment {
  final String time;
  final String type;
  final String comment;

  const KeyMoment({required this.time, required this.type, required this.comment});

  factory KeyMoment.fromJson(Map<String, dynamic> j) => KeyMoment(
        time: j['time']?.toString() ?? '0:00',
        type: j['type'] as String? ?? '',
        comment: j['comment'] as String? ?? '',
      );
}

/// Viral moment suggestion from AI.
class ViralMoment {
  final String time;
  final String idea;

  const ViralMoment({required this.time, required this.idea});

  factory ViralMoment.fromJson(Map<String, dynamic> j) => ViralMoment(
        time: j['time']?.toString() ?? '0:00',
        idea: j['idea'] as String? ?? '',
      );
}

/// Lyrics structure part from lyrics analysis.
class LyricsPart {
  final String type;
  final String text;

  const LyricsPart({required this.type, required this.text});

  factory LyricsPart.fromJson(Map<String, dynamic> j) => LyricsPart(
        type: j['type'] as String? ?? 'verse',
        text: j['text'] as String? ?? '',
      );
}

/// Lyrics intelligence from separate GPT analysis.
class LyricsIntelligence {
  final List<LyricsPart> structure;
  final String hook;
  final List<String> themes;
  final String emotion;
  final List<String> strongestLines;
  final List<String> weakestLines;
  final List<String> repetitionPatterns;

  const LyricsIntelligence({
    this.structure = const [],
    this.hook = '',
    this.themes = const [],
    this.emotion = '',
    this.strongestLines = const [],
    this.weakestLines = const [],
    this.repetitionPatterns = const [],
  });

  factory LyricsIntelligence.fromJson(Map<String, dynamic> j) => LyricsIntelligence(
        structure: (j['structure'] as List<dynamic>?)
                ?.map((s) => LyricsPart.fromJson(s is Map<String, dynamic> ? s : Map<String, dynamic>.from(s as Map)))
                .toList() ?? [],
        hook: j['hook'] as String? ?? '',
        themes: _strList(j['themes']),
        emotion: j['emotion'] as String? ?? '',
        strongestLines: _strList(j['strongest_lines']),
        weakestLines: _strList(j['weakest_lines']),
        repetitionPatterns: _strList(j['repetition_patterns']),
      );

  bool get isEmpty => hook.isEmpty && structure.isEmpty;

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}

/// AI lyrics insight from main analysis.
class LyricsInsight {
  final String mainTheme;
  final String hookQuality;
  final String weakParts;
  final String energyMatch;

  const LyricsInsight({
    this.mainTheme = '',
    this.hookQuality = '',
    this.weakParts = '',
    this.energyMatch = '',
  });

  factory LyricsInsight.fromJson(Map<String, dynamic> j) => LyricsInsight(
        mainTheme: j['main_theme'] as String? ?? '',
        hookQuality: j['hook_quality'] as String? ?? '',
        weakParts: j['weak_parts'] as String? ?? '',
        energyMatch: j['energy_match'] as String? ?? '',
      );

  bool get isEmpty => mainTheme.isEmpty && hookQuality.isEmpty;
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

  // Hit predictor scores
  final int hitScore;
  final int viralProbability;

  // V5 fields
  final double lufs;
  final double spectralFlux;
  final FreqBands freqBands;
  final List<double> waveformPeaks;

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
  final String freqBalanceVerdict;
  final List<FixTimestamp> fixTimestamps;
  final String finalOpinion;
  final String? lyrics;
  final String lyricsAnalysis;
  final String genre;

  // V6 — new producer fields
  final double hookScore;
  final double structureScore;
  final double emotionScore;
  final double originalityScore;
  final List<KeyMoment> keyMoments;
  final List<ViralMoment> viralMoments;
  final LyricsInsight lyricsInsight;
  final List<String> fixRecommendations;
  final LyricsIntelligence? lyricsIntelligence;

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
    required this.lufs,
    required this.spectralFlux,
    required this.freqBands,
    required this.waveformPeaks,
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
    required this.freqBalanceVerdict,
    required this.fixTimestamps,
    required this.finalOpinion,
    this.lyrics,
    this.lyricsAnalysis = '',
    this.genre = '',
    this.hookScore = 0,
    this.structureScore = 0,
    this.emotionScore = 0,
    this.originalityScore = 0,
    this.keyMoments = const [],
    this.viralMoments = const [],
    this.lyricsInsight = const LyricsInsight(),
    this.fixRecommendations = const [],
    this.lyricsIntelligence,
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

    // Parse lyrics intelligence (from separate GPT call)
    LyricsIntelligence? lyricsIntel;
    if (resp['lyricsAnalysis'] is Map) {
      lyricsIntel = LyricsIntelligence.fromJson(
          Map<String, dynamic>.from(resp['lyricsAnalysis'] as Map));
    }

    // Parse lyrics insight (from main AI analysis)
    LyricsInsight lyricsInsight = const LyricsInsight();
    if (ai['lyrics_insight'] is Map) {
      lyricsInsight = LyricsInsight.fromJson(
          Map<String, dynamic>.from(ai['lyrics_insight'] as Map));
    }

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
      lufs: (metrics['lufs'] as num?)?.toDouble() ?? -14,
      spectralFlux: (metrics['spectral_flux'] as num?)?.toDouble() ?? 0,
      freqBands: metrics['freq_bands'] is Map
          ? FreqBands.fromJson(Map<String, dynamic>.from(metrics['freq_bands'] as Map))
          : const FreqBands(),
      waveformPeaks: (metrics['waveform_peaks'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      score: (ai['score'] as num?)?.toDouble() ?? apiScore,
      verdict: _str(ai['verdict']),
      genreGuess: _str(ai['genre']).isNotEmpty ? _str(ai['genre']) : _str(resp['genre']),
      viralProbabilityAi: aiViralProb,
      mainProblem: _str(ai['main_problem']),
      killerIssue: _str(ai['killer_issue']),
      canBeHit: ai['can_be_hit'] == true,
      hitRecipe: _str(ai['hit_recipe']),
      strengths: _strList(ai['strengths']),
      problems: _strList(ai['problems']),
      improvementsDetailed: (ai['improvements'] as List<dynamic>?)
              ?.map((f) {
                if (f is Map<String, dynamic>) return Improvement.fromJson(f);
                if (f is Map) return Improvement.fromJson(Map<String, dynamic>.from(f));
                return Improvement(time: 0, action: f.toString());
              })
              .toList() ??
          [],
      hookPotential: (ai['hook_potential'] as num?)?.toDouble() ?? 0,
      productionQuality: (ai['production_quality'] as num?)?.toDouble() ?? 0,
      viralPotential: (ai['viral_potential'] as num?)?.toDouble() ?? 0,
      playlistChance: (ai['playlist_chance'] as num?)?.toDouble() ?? 0,
      bestTiktokSegment: _str(ai['best_tiktok_segment']),
      mixNotes: _str(ai['mix_notes']),
      marketFit: _str(ai['market_fit']),
      structureVerdict: _str(ai['structure_verdict']),
      hookAnalysis: _str(ai['hook_analysis']),
      dropAnalysis: _str(ai['drop_analysis']),
      introAnalysis: _str(ai['intro_analysis']),
      listenerDropout: _str(ai['listener_dropout']),
      retentionKiller: _str(ai['retention_killer']),
      freqBalanceVerdict: _str(ai['freq_balance_verdict']),
      fixTimestamps: (ai['fix_timestamps'] as List<dynamic>?)
              ?.map((f) {
                if (f is Map<String, dynamic>) return FixTimestamp.fromJson(f);
                if (f is Map) return FixTimestamp.fromJson(Map<String, dynamic>.from(f));
                return FixTimestamp(time: 0, issue: f.toString(), fix: '');
              })
              .toList() ??
          [],
      finalOpinion: _str(ai['final_opinion']),
      lyrics: resp['lyrics']?.toString() ?? metrics['lyrics']?.toString(),
      lyricsAnalysis: _str(ai['lyrics_analysis']),
      genre: _str(resp['genre']).isNotEmpty ? _str(resp['genre']) : _str(ai['genre']),
      // V6 fields
      hookScore: (ai['hookScore'] as num?)?.toDouble() ?? 0,
      structureScore: (ai['structureScore'] as num?)?.toDouble() ?? 0,
      emotionScore: (ai['emotionScore'] as num?)?.toDouble() ?? 0,
      originalityScore: (ai['originalityScore'] as num?)?.toDouble() ?? 0,
      keyMoments: (ai['key_moments'] as List<dynamic>?)
              ?.map((m) {
                if (m is Map<String, dynamic>) return KeyMoment.fromJson(m);
                if (m is Map) return KeyMoment.fromJson(Map<String, dynamic>.from(m));
                return KeyMoment(time: '0:00', type: '', comment: m.toString());
              })
              .toList() ??
          [],
      viralMoments: (ai['viral_moments'] as List<dynamic>?)
              ?.map((m) {
                if (m is Map<String, dynamic>) return ViralMoment.fromJson(m);
                if (m is Map) return ViralMoment.fromJson(Map<String, dynamic>.from(m));
                return ViralMoment(time: '0:00', idea: m.toString());
              })
              .toList() ??
          [],
      lyricsInsight: lyricsInsight,
      fixRecommendations: _strList(ai['fix_recommendations']),
      lyricsIntelligence: lyricsIntel,
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

  String get lufsFormatted => '${lufs.toStringAsFixed(1)} LUFS';

  String get lufsVerdict {
    if (lufs > -8) return 'Перекомпрессирован';
    if (lufs > -12) return 'Громко (клуб)';
    if (lufs > -16) return 'Норма (стрим)';
    return 'Тихо — нужен мастеринг';
  }

  static String _str(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
