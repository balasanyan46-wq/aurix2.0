import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/momentum_component.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int streams = 5000,
}) {
  final now = DateTime.now();
  return MetricsSnapshot(
    artistId: artistId,
    periodStart: now.subtract(const Duration(days: 30)),
    periodEnd: now,
    listenersMonthly: 1000,
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
  group('MomentumComponent', () {
    late MomentumComponent sut;

    setUp(() {
      sut = MomentumComponent(normalizer: MinMaxNormalizer());
    });

    test('should return 0.5 when no previous data', () {
      final current = _snap();
      final all = [(current: current, previous: null as MetricsSnapshot?)];
      expect(sut.compute(current, null, all), 0.5);
    });

    test('should return 0.5 when all artists have no previous data', () {
      final a1 = _snap(artistId: 'a1');
      final a2 = _snap(artistId: 'a2');
      final all = [
        (current: a1, previous: null as MetricsSnapshot?),
        (current: a2, previous: null as MetricsSnapshot?),
      ];
      // allValues with previous is empty => returns 0.5
      expect(sut.compute(a1, null, all), 0.5);
    });

    test('should return value in 0..1 range', () {
      final current = _snap(streams: 10000);
      final previous = _snap(streams: 5000);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
      ];
      expect(sut.compute(current, previous, all), inInclusiveRange(0.0, 1.0));
    });

    test('should rank higher momentum above lower', () {
      // a1: 100% growth => (10000 - 5000) / 5000 = 1.0
      final a1 = _snap(artistId: 'a1', streams: 10000);
      final a1Prev = _snap(artistId: 'a1', streams: 5000);
      // a2: 0% growth => (5000 - 5000) / 5000 = 0.0
      final a2 = _snap(artistId: 'a2', streams: 5000);
      final a2Prev = _snap(artistId: 'a2', streams: 5000);
      final all = [
        (current: a1, previous: a1Prev as MetricsSnapshot?),
        (current: a2, previous: a2Prev as MetricsSnapshot?),
      ];
      expect(sut.compute(a1, a1Prev, all), greaterThan(sut.compute(a2, a2Prev, all)));
    });

    test('should handle declining streams', () {
      // Decline: (2000 - 5000) / 5000 = -0.6
      final current = _snap(streams: 2000);
      final previous = _snap(streams: 5000);
      // Growth: (10000 - 5000) / 5000 = 1.0
      final currentB = _snap(artistId: 'a2', streams: 10000);
      final previousB = _snap(artistId: 'a2', streams: 5000);
      final all = [
        (current: current, previous: previous as MetricsSnapshot?),
        (current: currentB, previous: previousB as MetricsSnapshot?),
      ];
      expect(sut.compute(current, previous, all), 0.0);
      expect(sut.compute(currentB, previousB, all), 1.0);
    });

    test('should handle zero previous streams gracefully', () {
      final current = _snap(streams: 5000);
      final previous = _snap(streams: 0);
      // prev.streams > 0 is false => rawValue = 0.0
      final all = [(current: current, previous: previous as MetricsSnapshot?)];
      expect(sut.compute(current, previous, all), inInclusiveRange(0.0, 1.0));
    });

    test('should handle single artist with previous', () {
      final current = _snap(streams: 10000);
      final previous = _snap(streams: 5000);
      final all = [(current: current, previous: previous as MetricsSnapshot?)];
      // Single value => span = 0 => 0.0 from MinMax
      expect(sut.compute(current, previous, all), 0.0);
    });
  });
}
