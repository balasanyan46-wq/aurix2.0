import 'dart:convert';

/// Result of AI track potential analysis.
class TrackAnalysis {
  final double score;
  final double hookScore;
  final double vibeScore;
  final double originalityScore;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<String> recommendations;
  final String verdict;

  const TrackAnalysis({
    required this.score,
    required this.hookScore,
    required this.vibeScore,
    required this.originalityScore,
    required this.strengths,
    required this.weaknesses,
    required this.recommendations,
    required this.verdict,
  });

  /// Parse from AI JSON response. Handles edge cases.
  factory TrackAnalysis.fromJson(Map<String, dynamic> j) => TrackAnalysis(
    score: _toDouble(j['score']),
    hookScore: _toDouble(j['hookScore']),
    vibeScore: _toDouble(j['vibeScore']),
    originalityScore: _toDouble(j['originalityScore']),
    strengths: _toStringList(j['strengths']),
    weaknesses: _toStringList(j['weaknesses']),
    recommendations: _toStringList(j['recommendations']),
    verdict: j['verdict'] as String? ?? '',
  );

  /// Try to parse JSON from raw AI response (may contain markdown fences).
  static TrackAnalysis? tryParse(String raw) {
    try {
      // Strip markdown code fences if present
      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '').replaceFirst(RegExp(r'\n?```$'), '');
      }
      final j = jsonDecode(cleaned);
      if (j is Map<String, dynamic>) return TrackAnalysis.fromJson(j);
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toJson() => {
    'score': score,
    'hookScore': hookScore,
    'vibeScore': vibeScore,
    'originalityScore': originalityScore,
    'strengths': strengths,
    'weaknesses': weaknesses,
    'recommendations': recommendations,
    'verdict': verdict,
  };

  bool get isHit => score >= 7.0;
  bool get isPotentialHit => score >= 8.5;

  static double _toDouble(dynamic v) {
    if (v is double) return v.clamp(0, 10);
    if (v is int) return v.toDouble().clamp(0, 10);
    if (v is String) return (double.tryParse(v) ?? 0).clamp(0, 10);
    return 0;
  }

  static List<String> _toStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
