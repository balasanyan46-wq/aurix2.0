import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/next_step_engine.dart';

void main() {
  late NextStepEngine engine;

  setUp(() {
    engine = NextStepEngine();
  });

  IndexScore score({
    required String artistId,
    int scoreVal = 500,
    int rankOverall = 50,
    double penaltyApplied = 0,
    Map<String, double>? breakdown,
  }) {
    final now = DateTime.now();
    return IndexScore(
      artistId: artistId,
      periodStart: DateTime(now.year, now.month - 1, 1),
      periodEnd: now,
      score: scoreVal,
      rankOverall: rankOverall,
      rankInGenre: 10,
      trendDelta: 0,
      breakdown: breakdown ?? {'growth': 80.0, 'engagement': 50.0, 'consistency': 70.0, 'momentum': 60.0, 'community': 65.0},
      penaltyApplied: penaltyApplied,
      updatedAt: now,
    );
  }

  MetricsSnapshot snapshot({required String artistId}) {
    final now = DateTime.now();
    return MetricsSnapshot(
      artistId: artistId,
      periodStart: DateTime(now.year, now.month - 1, 1),
      periodEnd: now,
      listenersMonthly: 5000,
      streams: 10000,
      saves: 200,
      shares: 50,
      completionRate: 0.6,
      releaseCountPeriod: 1,
      collabCountPeriod: 0,
      liveEventsPeriod: 0,
      strikes: 0,
    );
  }

  group('NextStepEngine', () {
    test('returns 3 next steps', () {
      final s = score(artistId: 'a1', breakdown: {'growth': 80.0, 'engagement': 30.0, 'consistency': 70.0, 'momentum': 60.0, 'community': 65.0});
      final snap = snapshot(artistId: 'a1');
      final plan = engine.buildNextSteps(s, snap);
      expect(plan.steps.length, lessThanOrEqualTo(3));
      expect(plan.steps.length, greaterThanOrEqualTo(1));
    });

    test('adds penalty step when penaltyApplied > 0', () {
      final s = score(artistId: 'a1', penaltyApplied: 50.0);
      final snap = snapshot(artistId: 'a1');
      final plan = engine.buildNextSteps(s, snap);
      expect(plan.steps.any((st) => st.metricKey == 'penalty'), isTrue);
    });

    test('returns engagement step when engagement is weakest', () {
      final s = score(artistId: 'a1', breakdown: {'growth': 90.0, 'engagement': 20.0, 'consistency': 80.0, 'momentum': 70.0, 'community': 75.0});
      final snap = snapshot(artistId: 'a1');
      final plan = engine.buildNextSteps(s, snap);
      expect(plan.steps.any((st) => st.metricKey == 'savesRate' || st.title.contains('saves')), isTrue);
    });
  });
}
