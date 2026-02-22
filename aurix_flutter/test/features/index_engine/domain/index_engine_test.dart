import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/index_calculator.dart';

void main() {
  group('IndexEngine', () {
    late IndexCalculator calculator;

    setUp(() {
      calculator = IndexCalculator(config: const IndexConfig());
    });

    test('score is always in 0..1000', () {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 1, 1);
      final periodEnd = now;
      final snapshots = [
        MetricsSnapshot(
          artistId: 'a1',
          periodStart: periodStart,
          periodEnd: periodEnd,
          listenersMonthly: 10000,
          streams: 50000,
          saves: 2000,
          shares: 500,
          completionRate: 0.8,
          releaseCountPeriod: 2,
          collabCountPeriod: 1,
          liveEventsPeriod: 2,
          strikes: 0,
        ),
        MetricsSnapshot(
          artistId: 'a2',
          periodStart: periodStart,
          periodEnd: periodEnd,
          listenersMonthly: 100,
          streams: 500,
          saves: 10,
          shares: 2,
          completionRate: 0.3,
          releaseCountPeriod: 0,
          collabCountPeriod: 0,
          liveEventsPeriod: 0,
          strikes: 5,
        ),
      ];
      final scores = calculator.calculateScores(snapshots, periodStart, periodEnd);
      for (final s in scores) {
        expect(s.score, inInclusiveRange(0, 1000));
      }
    });

    test('penalty reduces score', () {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 1, 1);
      final periodEnd = now;
      final noStrikes = MetricsSnapshot(
        artistId: 'a1',
        periodStart: periodStart,
        periodEnd: periodEnd,
        listenersMonthly: 5000,
        streams: 20000,
        saves: 800,
        shares: 200,
        completionRate: 0.7,
        releaseCountPeriod: 2,
        collabCountPeriod: 1,
        liveEventsPeriod: 1,
        strikes: 0,
      );
      final withStrikes = MetricsSnapshot(
        artistId: 'a2',
        periodStart: periodStart,
        periodEnd: periodEnd,
        listenersMonthly: 5000,
        streams: 20000,
        saves: 800,
        shares: 200,
        completionRate: 0.7,
        releaseCountPeriod: 2,
        collabCountPeriod: 1,
        liveEventsPeriod: 1,
        strikes: 3,
      );
      final scores = calculator.calculateScores([noStrikes, withStrikes], periodStart, periodEnd);
      final s1 = scores.firstWhere((s) => s.artistId == 'a1');
      final s2 = scores.firstWhere((s) => s.artistId == 'a2');
      expect(s2.score, lessThan(s1.score));
      expect(s2.penaltyApplied, greaterThan(s1.penaltyApplied));
    });

    test('higher savesRate increases engagement component', () {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 1, 1);
      final periodEnd = now;
      final lowSaves = MetricsSnapshot(
        artistId: 'a1',
        periodStart: periodStart,
        periodEnd: periodEnd,
        listenersMonthly: 1000,
        streams: 10000,
        saves: 100,
        shares: 20,
        completionRate: 0.4,
        releaseCountPeriod: 1,
        collabCountPeriod: 0,
        liveEventsPeriod: 0,
        strikes: 0,
      );
      final highSaves = MetricsSnapshot(
        artistId: 'a2',
        periodStart: periodStart,
        periodEnd: periodEnd,
        listenersMonthly: 1000,
        streams: 10000,
        saves: 2500,
        shares: 500,
        completionRate: 0.9,
        releaseCountPeriod: 1,
        collabCountPeriod: 0,
        liveEventsPeriod: 0,
        strikes: 0,
      );
      final scores = calculator.calculateScores([lowSaves, highSaves], periodStart, periodEnd);
      final s1 = scores.firstWhere((s) => s.artistId == 'a1');
      final s2 = scores.firstWhere((s) => s.artistId == 'a2');
      expect(s2.breakdown['engagement']!, greaterThan(s1.breakdown['engagement']!));
    });
  });
}
