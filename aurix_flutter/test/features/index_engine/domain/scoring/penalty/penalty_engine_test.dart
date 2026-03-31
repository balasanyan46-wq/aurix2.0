import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/fraud_detector.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/penalty_engine.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int listenersMonthly = 1000,
  int streams = 5000,
  int strikes = 0,
}) {
  final now = DateTime.now();
  return MetricsSnapshot(
    artistId: artistId,
    periodStart: now.subtract(const Duration(days: 30)),
    periodEnd: now,
    listenersMonthly: listenersMonthly,
    streams: streams,
    saves: 100,
    shares: 20,
    completionRate: 0.5,
    releaseCountPeriod: 1,
    collabCountPeriod: 0,
    liveEventsPeriod: 0,
    strikes: strikes,
  );
}

void main() {
  group('PenaltyEngine', () {
    late PenaltyEngine sut;
    late IndexConfig config;
    late FraudDetector fraudDetector;

    setUp(() {
      config = const IndexConfig(
        strikePenaltyPerUnit: 0.05,
        suspicionToPenaltyFactor: 0.2,
        maxPenalty: 0.35,
        streamsGrowthThreshold: 5.0,
        listenersGrowthThreshold: 5.0,
      );
      fraudDetector = FraudDetector(config: config);
      sut = PenaltyEngine(config: config, fraudDetector: fraudDetector);
    });

    test('should return 0.0 when no strikes and no suspicion', () {
      final current = _snap(strikes: 0);
      final previous = _snap();
      expect(sut.compute(0.5, current, previous, 0.8), 0.0);
    });

    test('should apply strike penalty proportional to strikes', () {
      final current = _snap(strikes: 2);
      final previous = _snap();
      // 2 * 0.05 = 0.10
      expect(sut.compute(0.5, current, previous, 0.8), closeTo(0.10, 0.001));
    });

    test('should apply suspicion penalty from fraud detection', () {
      // Trigger streams spike: ratio = 30000/5000 = 6.0 > 5.0
      // suspicion = 0.5 => suspicionPenalty = 0.5 * 0.2 = 0.1
      final current = _snap(strikes: 0, streams: 30000);
      final previous = _snap(streams: 5000);
      final penalty = sut.compute(0.5, current, previous, 0.8);
      expect(penalty, closeTo(0.1, 0.001));
    });

    test('should combine strikes and suspicion', () {
      // strikes: 2 => 0.10
      // streams spike: suspicion 0.5 => 0.10
      // total = 0.20
      final current = _snap(strikes: 2, streams: 30000);
      final previous = _snap(streams: 5000);
      final penalty = sut.compute(0.5, current, previous, 0.8);
      expect(penalty, closeTo(0.20, 0.001));
    });

    test('should cap penalty at maxPenalty', () {
      // strikes: 7 => 0.35, maxPenalty = 0.35
      final current = _snap(strikes: 7);
      final previous = _snap();
      expect(sut.compute(0.5, current, previous, 0.8), config.maxPenalty);
    });

    test('should cap combined penalty at maxPenalty', () {
      // strikes: 5 => 0.25
      // both spikes + low engagement => suspicion 1.0 => 0.2
      // total = 0.45, capped to 0.35
      final current = _snap(
        strikes: 5,
        streams: 30000,
        listenersMonthly: 6000,
      );
      final previous = _snap(streams: 5000, listenersMonthly: 1000);
      final penalty = sut.compute(0.5, current, previous, 0.1);
      expect(penalty, config.maxPenalty);
    });

    test('should return 0.0 with no previous data and no strikes', () {
      final current = _snap(strikes: 0);
      // FraudDetector returns 0.0 when previous is null
      expect(sut.compute(0.5, current, null, 0.8), 0.0);
    });

    test('should still apply strikes even with no previous data', () {
      final current = _snap(strikes: 3);
      // 3 * 0.05 = 0.15
      expect(sut.compute(0.5, current, null, 0.8), closeTo(0.15, 0.001));
    });

    test('should never return negative penalty', () {
      final current = _snap(strikes: 0);
      final previous = _snap();
      final penalty = sut.compute(0.0, current, previous, 1.0);
      expect(penalty, greaterThanOrEqualTo(0.0));
    });

    test('should handle extreme strike counts', () {
      // 100 * 0.05 = 5.0, capped to 0.35
      final current = _snap(strikes: 100);
      final previous = _snap();
      expect(sut.compute(0.5, current, previous, 0.8), config.maxPenalty);
    });
  });
}
