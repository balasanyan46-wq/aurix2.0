import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/growth_component.dart';

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
  group('GrowthComponent', () {
    late GrowthComponent sut;

    setUp(() {
      sut = GrowthComponent(normalizer: MinMaxNormalizer());
    });

    test('should return value in 0..1 range with previous data', () {
      final current = _snap(listenersMonthly: 2000, streams: 10000);
      final previous = _snap(listenersMonthly: 1000, streams: 5000);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
      ];
      expect(sut.compute(current, previous, all), inInclusiveRange(0.0, 1.0));
    });

    test('should use log-scale when no previous data', () {
      final current = _snap(listenersMonthly: 1000, streams: 5000);
      final all = [
        (current: current, previous: null as MetricsSnapshot?),
      ];
      final result = sut.compute(current, null, all);
      // Single artist => minmax returns 0.0 (span=0)
      expect(result, 0.0);
    });

    test('should use log-scale when previous has zero metrics', () {
      final current = _snap(listenersMonthly: 1000, streams: 5000);
      final previous = _snap(listenersMonthly: 0, streams: 0);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
      ];
      final result = sut.compute(current, previous, all);
      expect(result, inInclusiveRange(0.0, 1.0));
    });

    test('should compute positive growth correctly', () {
      // 100% growth in listeners and streams
      final current = _snap(artistId: 'a1', listenersMonthly: 2000, streams: 10000);
      final previous = _snap(artistId: 'a1', listenersMonthly: 1000, streams: 5000);
      // 0% growth
      final currentB = _snap(artistId: 'a2', listenersMonthly: 1000, streams: 5000);
      final previousB = _snap(artistId: 'a2', listenersMonthly: 1000, streams: 5000);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
        (current: currentB, previous: previousB as MetricsSnapshot?),
      ];
      final resultA = sut.compute(current, previous, all);
      final resultB = sut.compute(currentB, previousB, all);
      expect(resultA, greaterThan(resultB));
    });

    test('should handle negative growth', () {
      // Decline: 500 from 1000
      final current = _snap(artistId: 'a1', listenersMonthly: 500, streams: 2500);
      final previous = _snap(artistId: 'a1', listenersMonthly: 1000, streams: 5000);
      // Growth: 2000 from 1000
      final currentB = _snap(artistId: 'a2', listenersMonthly: 2000, streams: 10000);
      final previousB = _snap(artistId: 'a2', listenersMonthly: 1000, streams: 5000);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
        (current: currentB, previous: previousB as MetricsSnapshot?),
      ];
      final declining = sut.compute(current, previous, all);
      final growing = sut.compute(currentB, previousB, all);
      expect(declining, lessThan(growing));
    });

    test('should handle mix of artists with and without previous data', () {
      final currentA = _snap(artistId: 'a1', listenersMonthly: 5000, streams: 20000);
      final currentB = _snap(artistId: 'a2', listenersMonthly: 2000, streams: 10000);
      final previousB = _snap(artistId: 'a2', listenersMonthly: 1000, streams: 5000);
      final all = [
        (current: currentA, previous: null as MetricsSnapshot?),
        (current: currentB, previous: previousB as MetricsSnapshot?),
      ];
      final resultA = sut.compute(currentA, null, all);
      final resultB = sut.compute(currentB, previousB, all);
      expect(resultA, inInclusiveRange(0.0, 1.0));
      expect(resultB, inInclusiveRange(0.0, 1.0));
    });

    test('should return 0.0 for single artist with no previous', () {
      final current = _snap();
      final all = [(current: current, previous: null as MetricsSnapshot?)];
      expect(sut.compute(current, null, all), 0.0);
    });
  });
}
