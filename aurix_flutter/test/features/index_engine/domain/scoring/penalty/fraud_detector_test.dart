import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/fraud_detector.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int listenersMonthly = 1000,
  int streams = 5000,
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
    strikes: 0,
  );
}

void main() {
  group('FraudDetector', () {
    late FraudDetector sut;
    late IndexConfig config;

    setUp(() {
      config = const IndexConfig(
        streamsGrowthThreshold: 5.0,
        listenersGrowthThreshold: 5.0,
      );
      sut = FraudDetector(config: config);
    });

    test('should return 0.0 when no previous data', () {
      final current = _snap();
      expect(sut.detect(current, null, 0.8), 0.0);
    });

    test('should return 0.0 for normal growth', () {
      // ratio = 2000/1000 = 2.0, below threshold of 5.0
      final current = _snap(listenersMonthly: 2000, streams: 10000);
      final previous = _snap(listenersMonthly: 1000, streams: 5000);
      expect(sut.detect(current, previous, 0.8), 0.0);
    });

    test('should detect streams spike above threshold', () {
      // streamsRatio = 30000/5000 = 6.0 > 5.0
      final current = _snap(streams: 30000);
      final previous = _snap(streams: 5000);
      final suspicion = sut.detect(current, previous, 0.8);
      expect(suspicion, greaterThan(0.0));
    });

    test('should detect listeners spike above threshold', () {
      // listenersRatio = 6000/1000 = 6.0 > 5.0
      final current = _snap(listenersMonthly: 6000);
      final previous = _snap(listenersMonthly: 1000);
      final suspicion = sut.detect(current, previous, 0.8);
      expect(suspicion, greaterThan(0.0));
    });

    test('should accumulate suspicion for both spikes', () {
      // Both ratios > 5.0 => 0.5 + 0.5 = 1.0
      final current = _snap(listenersMonthly: 6000, streams: 30000);
      final previous = _snap(listenersMonthly: 1000, streams: 5000);
      final suspicion = sut.detect(current, previous, 0.8);
      expect(suspicion, 1.0);
    });

    test('should add low-engagement penalty when suspicious', () {
      // streamsRatio = 6.0 > 5.0 => suspicion = 0.5
      // engagement < 0.3 => suspicion += 0.3 => 0.8
      final current = _snap(streams: 30000);
      final previous = _snap(streams: 5000);
      final suspicion = sut.detect(current, previous, 0.2);
      expect(suspicion, 0.8);
    });

    test('should not add low-engagement penalty when no spike detected', () {
      final current = _snap();
      final previous = _snap();
      // No spike, even if engagement is low
      expect(sut.detect(current, previous, 0.1), 0.0);
    });

    test('should clamp suspicion to 1.0', () {
      // Both spikes (0.5+0.5) + low engagement (+0.3) => 1.3, clamped to 1.0
      final current = _snap(listenersMonthly: 6000, streams: 30000);
      final previous = _snap(listenersMonthly: 1000, streams: 5000);
      final suspicion = sut.detect(current, previous, 0.1);
      expect(suspicion, 1.0);
    });

    test('should record anomaly signals', () {
      final current = _snap(streams: 30000);
      final previous = _snap(streams: 5000);
      sut.detect(current, previous, 0.8);
      expect(sut.signals, hasLength(1));
      expect(sut.signals.first.type, 'streams_spike');
      expect(sut.signals.first.artistId, 'a1');
    });

    test('should record multiple anomaly signals', () {
      final current = _snap(listenersMonthly: 6000, streams: 30000);
      final previous = _snap(listenersMonthly: 1000, streams: 5000);
      sut.detect(current, previous, 0.8);
      expect(sut.signals, hasLength(2));
      final types = sut.signals.map((s) => s.type).toSet();
      expect(types, containsAll(['streams_spike', 'listeners_spike']));
    });

    test('should clear signals', () {
      final current = _snap(streams: 30000);
      final previous = _snap(streams: 5000);
      sut.detect(current, previous, 0.8);
      expect(sut.signals, isNotEmpty);
      sut.clearSignals();
      expect(sut.signals, isEmpty);
    });

    test('should handle zero previous streams (floored to 1)', () {
      // prevStreams = max(0, 1) = 1; ratio = 5000/1 = 5000
      final current = _snap(streams: 5000);
      final previous = _snap(streams: 0);
      final suspicion = sut.detect(current, previous, 0.8);
      expect(suspicion, greaterThan(0.0));
    });

    test('should handle zero previous listeners (floored to 1)', () {
      final current = _snap(listenersMonthly: 1000);
      final previous = _snap(listenersMonthly: 0);
      final suspicion = sut.detect(current, previous, 0.8);
      expect(suspicion, greaterThan(0.0));
    });

    test('should handle growth at exactly the threshold', () {
      // Ratio = 5.0 which is NOT > 5.0, so no spike
      final current = _snap(streams: 25000);
      final previous = _snap(streams: 5000);
      expect(sut.detect(current, previous, 0.8), 0.0);
    });

    test('should accumulate signals across multiple detect calls', () {
      final current = _snap(streams: 30000);
      final previous = _snap(streams: 5000);
      sut.detect(current, previous, 0.8);
      sut.detect(current, previous, 0.8);
      expect(sut.signals, hasLength(2));
    });
  });
}
