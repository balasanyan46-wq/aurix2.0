import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/engagement_component.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int streams = 10000,
  int saves = 100,
  int shares = 20,
  double completionRate = 0.5,
}) {
  final now = DateTime.now();
  return MetricsSnapshot(
    artistId: artistId,
    periodStart: now.subtract(const Duration(days: 30)),
    periodEnd: now,
    listenersMonthly: 1000,
    streams: streams,
    saves: saves,
    shares: shares,
    completionRate: completionRate,
    releaseCountPeriod: 1,
    collabCountPeriod: 0,
    liveEventsPeriod: 0,
    strikes: 0,
  );
}

void main() {
  group('EngagementComponent', () {
    late EngagementComponent sut;

    setUp(() {
      sut = EngagementComponent(normalizer: MinMaxNormalizer());
    });

    test('should return value in 0..1 range', () {
      final current = _snap();
      final all = [
        current,
        _snap(artistId: 'a2', saves: 0, shares: 0, completionRate: 0.0),
        _snap(artistId: 'a3', saves: 5000, shares: 1000, completionRate: 1.0),
      ];
      expect(sut.compute(current, all), inInclusiveRange(0.0, 1.0));
    });

    test('should return 1.0 for highest engagement', () {
      final current = _snap(saves: 5000, shares: 1000, completionRate: 1.0);
      final all = [
        current,
        _snap(artistId: 'a2', saves: 0, shares: 0, completionRate: 0.0),
      ];
      expect(sut.compute(current, all), 1.0);
    });

    test('should return 0.0 for lowest engagement', () {
      final current = _snap(saves: 0, shares: 0, completionRate: 0.0);
      final all = [
        current,
        _snap(artistId: 'a2', saves: 5000, shares: 1000, completionRate: 1.0),
      ];
      expect(sut.compute(current, all), 0.0);
    });

    test('should treat zero streams as 1 to avoid division by zero', () {
      final current = _snap(streams: 0, saves: 10, shares: 5, completionRate: 0.5);
      final all = [
        current,
        _snap(artistId: 'a2', streams: 0, saves: 0, shares: 0, completionRate: 0.0),
      ];
      // Should not throw; streams floored to 1
      expect(sut.compute(current, all), inInclusiveRange(0.0, 1.0));
    });

    test('should weight shares more heavily than saves', () {
      // savesRate * 10 + sharesRate * 50 + completionRate
      // a1: (100/10000)*10 + (200/10000)*50 + 0 = 0.1 + 1.0 = 1.1
      // a2: (500/10000)*10 + (0/10000)*50 + 0 = 0.5 + 0 = 0.5
      final a1 = _snap(artistId: 'a1', saves: 100, shares: 200, completionRate: 0.0);
      final a2 = _snap(artistId: 'a2', saves: 500, shares: 0, completionRate: 0.0);
      final all = [a1, a2];
      expect(sut.compute(a1, all), greaterThan(sut.compute(a2, all)));
    });

    test('should factor in completion rate', () {
      final a1 = _snap(artistId: 'a1', saves: 100, shares: 20, completionRate: 1.0);
      final a2 = _snap(artistId: 'a2', saves: 100, shares: 20, completionRate: 0.0);
      final all = [a1, a2];
      expect(sut.compute(a1, all), greaterThan(sut.compute(a2, all)));
    });

    test('should handle single artist', () {
      final current = _snap();
      expect(sut.compute(current, [current]), 0.0);
    });

    test('should handle all-zero engagement across artists', () {
      final current = _snap(saves: 0, shares: 0, completionRate: 0.0);
      final all = [
        current,
        _snap(artistId: 'a2', saves: 0, shares: 0, completionRate: 0.0),
      ];
      expect(sut.compute(current, all), 0.0);
    });
  });
}
