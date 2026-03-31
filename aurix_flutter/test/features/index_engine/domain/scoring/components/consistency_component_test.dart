import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/consistency_component.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int releaseCountPeriod = 0,
}) {
  final now = DateTime.now();
  return MetricsSnapshot(
    artistId: artistId,
    periodStart: now.subtract(const Duration(days: 30)),
    periodEnd: now,
    listenersMonthly: 1000,
    streams: 5000,
    saves: 100,
    shares: 20,
    completionRate: 0.5,
    releaseCountPeriod: releaseCountPeriod,
    collabCountPeriod: 0,
    liveEventsPeriod: 0,
    strikes: 0,
  );
}

void main() {
  group('ConsistencyComponent', () {
    late ConsistencyComponent sut;

    setUp(() {
      sut = ConsistencyComponent(normalizer: MinMaxNormalizer());
    });

    test('should return value in 0..1 range', () {
      final current = _snap(releaseCountPeriod: 3);
      final all = [
        current,
        _snap(artistId: 'a2', releaseCountPeriod: 0),
        _snap(artistId: 'a3', releaseCountPeriod: 10),
      ];
      expect(sut.compute(current, all), inInclusiveRange(0.0, 1.0));
    });

    test('should return 1.0 for highest release count', () {
      final current = _snap(releaseCountPeriod: 10);
      final all = [
        current,
        _snap(artistId: 'a2', releaseCountPeriod: 0),
      ];
      expect(sut.compute(current, all), 1.0);
    });

    test('should return 0.0 for lowest release count', () {
      final current = _snap(releaseCountPeriod: 0);
      final all = [
        current,
        _snap(artistId: 'a2', releaseCountPeriod: 5),
      ];
      expect(sut.compute(current, all), 0.0);
    });

    test('should return 0.0 when all release counts are zero', () {
      final current = _snap(releaseCountPeriod: 0);
      final all = [
        current,
        _snap(artistId: 'a2', releaseCountPeriod: 0),
      ];
      expect(sut.compute(current, all), 0.0);
    });

    test('should rank mid-range artist correctly', () {
      final current = _snap(releaseCountPeriod: 5);
      final all = [
        _snap(artistId: 'a0', releaseCountPeriod: 0),
        current,
        _snap(artistId: 'a2', releaseCountPeriod: 10),
      ];
      expect(sut.compute(current, all), 0.5);
    });

    test('should handle single artist', () {
      final current = _snap(releaseCountPeriod: 5);
      expect(sut.compute(current, [current]), 0.0);
    });
  });
}
