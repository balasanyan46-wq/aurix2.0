import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart';

/// Aurix Index calculator. Score 0..1000 from weighted components:
/// Growth 30%, Engagement 25%, Consistency 20%, Momentum 15%, Community 10%.
/// Penalties: strikes reduce score.
class IndexCalculator {
  static const double growthWeight = 0.30;
  static const double engagementWeight = 0.25;
  static const double consistencyWeight = 0.20;
  static const double momentumWeight = 0.15;
  static const double communityWeight = 0.10;
  static const int strikePenalty = 50;

  List<IndexScore> calculateScores(
    List<MetricsSnapshot> snapshots,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    final byArtist = <String, List<MetricsSnapshot>>{};
    for (final s in snapshots) {
      if (s.periodStart.isBefore(periodEnd) && s.periodEnd.isAfter(periodStart)) {
        byArtist.putIfAbsent(s.artistId, () => []).add(s);
      }
    }

    final results = <IndexScore>[];
    for (final e in byArtist.entries) {
      final sorted = List<MetricsSnapshot>.from(e.value)..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
      final current = sorted.isEmpty ? null : sorted.first;
      final previous = sorted.length > 1 ? sorted[1] : null;
      if (current == null) continue;

      final growth = _normGrowth(byArtist.values, current, previous);
      final engagement = _normEngagement(byArtist.values, current);
      final consistency = _normConsistency(byArtist.values, current);
      final momentum = _normMomentum(byArtist.values, current, previous);
      final community = _normCommunity(byArtist.values, current);

      var raw = growthWeight * growth +
          engagementWeight * engagement +
          consistencyWeight * consistency +
          momentumWeight * momentum +
          communityWeight * community;
      raw = raw.clamp(0.0, 1.0);

      var score = (raw * 1000).round();
      score -= current.strikes * strikePenalty;
      score = score.clamp(0, 1000);

      results.add(IndexScore(
        artistId: e.key,
        score: score,
        rankOverall: 0,
        rankInGenre: 0,
        trendDelta: previous != null ? (score - _estimatePreviousScore(current, previous)).clamp(-999, 999) : 0,
        badges: [],
        updatedAt: periodEnd,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  int _estimatePreviousScore(MetricsSnapshot current, MetricsSnapshot previous) {
    final growth = previous.listenersMonthly > 0
        ? (current.listenersMonthly - previous.listenersMonthly) / previous.listenersMonthly
        : 0.0;
    final eng = (current.saves + current.shares) / (current.streams + 1) * 100;
    final cons = (current.releaseCountPeriod + 1) / 4.0;
    final raw = (growth.clamp(0.0, 1.0) * 0.3 + (eng.clamp(0.0, 10.0) / 10 * 0.25) + (cons.clamp(0.0, 1.0) * 0.2) + 0.25);
    return (raw.clamp(0.0, 1.0) * 1000).round();
  }

  double _normGrowth(Iterable<List<MetricsSnapshot>> all, MetricsSnapshot cur, MetricsSnapshot? prev) {
    if (prev == null || prev.listenersMonthly == 0) return 0.5;
    final rates = all.map((list) {
      final c = list.isEmpty ? null : list.first;
      final p = list.length > 1 ? list[1] : null;
      if (c == null || p == null || p.listenersMonthly == 0) return 0.0;
      return (c.listenersMonthly - p.listenersMonthly) / p.listenersMonthly;
    }).where((r) => r.isFinite).toList();
    if (rates.isEmpty) return 0.5;
    final min = rates.reduce((a, b) => a < b ? a : b);
    final max = rates.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    if (span <= 0) return 0.5;
    final rate = (cur.listenersMonthly - prev.listenersMonthly) / prev.listenersMonthly;
    return ((rate - min) / span).clamp(0.0, 1.0);
  }

  double _normEngagement(Iterable<List<MetricsSnapshot>> all, MetricsSnapshot cur) {
    final vals = all.map((list) {
      final c = list.isEmpty ? null : list.first;
      if (c == null) return 0.0;
      return (c.saves + c.shares * 2) / (c.streams + 1) * 1000 + c.completionRate * 10;
    }).toList();
    return _normCur(vals, (cur.saves + cur.shares * 2) / (cur.streams + 1) * 1000 + cur.completionRate * 10);
  }

  double _normConsistency(Iterable<List<MetricsSnapshot>> all, MetricsSnapshot cur) {
    final vals = all.map((list) {
      final c = list.isEmpty ? null : list.first;
      return (c?.releaseCountPeriod ?? 0) / 4.0;
    }).toList();
    return _normCur(vals, cur.releaseCountPeriod / 4.0);
  }

  double _normMomentum(Iterable<List<MetricsSnapshot>> all, MetricsSnapshot cur, MetricsSnapshot? prev) {
    if (prev == null) return 0.5;
    final delta = cur.streams - prev.streams;
    final vals = all.map((list) {
      if (list.length < 2) return 0.0;
      return (list[0].streams - list[1].streams).toDouble();
    }).toList();
    return _normCur(vals, delta.toDouble());
  }

  double _normCommunity(Iterable<List<MetricsSnapshot>> all, MetricsSnapshot cur) {
    final vals = all.map((list) {
      final c = list.isEmpty ? null : list.first;
      if (c == null) return 0.0;
      return (c.collabCountPeriod * 2 + c.liveEventsPeriod).toDouble();
    }).toList();
    return _normCur(vals, (cur.collabCountPeriod * 2 + cur.liveEventsPeriod).toDouble());
  }

  double _normCur(List<double> vals, double cur) {
    if (vals.isEmpty) return 0.5;
    vals.sort();
    final min = vals.first;
    final max = vals.last;
    final span = max - min;
    if (span <= 0) return 0.5;
    return ((cur - min) / span).clamp(0.0, 1.0);
  }
}
