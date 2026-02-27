import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index/domain/index_calculator.dart';
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart';

void main() {
  late IndexCalculator calculator;

  setUp(() {
    calculator = IndexCalculator();
  });

  MetricsSnapshot snapshot({
    required String artistId,
    required DateTime periodStart,
    required DateTime periodEnd,
    int listenersMonthly = 1000,
    int streams = 10000,
    int saves = 100,
    int shares = 20,
    double completionRate = 0.7,
    int releaseCountPeriod = 1,
    int collabCountPeriod = 0,
    int liveEventsPeriod = 0,
    int strikes = 0,
  }) {
    return MetricsSnapshot(
      artistId: artistId,
      periodStart: periodStart,
      periodEnd: periodEnd,
      listenersMonthly: listenersMonthly,
      streams: streams,
      saves: saves,
      shares: shares,
      completionRate: completionRate,
      releaseCountPeriod: releaseCountPeriod,
      collabCountPeriod: collabCountPeriod,
      liveEventsPeriod: liveEventsPeriod,
      strikes: strikes,
    );
  }

  group('IndexCalculator', () {
    test('score is within 0..1000', () {
      final periodStart = DateTime(2025, 1, 1);
      final periodEnd = DateTime(2025, 2, 28);
      final snapshots = [
        snapshot(artistId: 'a1', periodStart: periodStart, periodEnd: periodEnd),
      ];
      final scores = calculator.calculateScores(snapshots, periodStart, periodEnd);
      expect(scores, isNotEmpty);
      for (final s in scores) {
        expect(s.score, greaterThanOrEqualTo(0));
        expect(s.score, lessThanOrEqualTo(1000));
      }
    });

    test('higher engagement increases score', () {
      final periodStart = DateTime(2025, 1, 1);
      final periodEnd = DateTime(2025, 2, 28);
      final prevStart = DateTime(2024, 12, 1);
      final prevEnd = DateTime(2024, 12, 31);

      // Low engagement: few saves/shares
      final lowEng = [
        snapshot(artistId: 'low', periodStart: prevStart, periodEnd: prevEnd),
        snapshot(artistId: 'low', periodStart: periodStart, periodEnd: periodEnd, saves: 10, shares: 2, streams: 10000),
      ];
      // High engagement: many saves/shares
      final highEng = [
        snapshot(artistId: 'high', periodStart: prevStart, periodEnd: prevEnd),
        snapshot(artistId: 'high', periodStart: periodStart, periodEnd: periodEnd, saves: 500, shares: 100, streams: 10000),
      ];

      final snapshots = [...lowEng, ...highEng];
      final scores = calculator.calculateScores(snapshots, periodStart, periodEnd);
      final lowScore = scores.firstWhere((s) => s.artistId == 'low');
      final highScore = scores.firstWhere((s) => s.artistId == 'high');
      expect(highScore.score, greaterThan(lowScore.score));
    });
  });
}
