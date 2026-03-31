import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/community_component.dart';

MetricsSnapshot _snap({
  String artistId = 'a1',
  int collabCountPeriod = 0,
  int liveEventsPeriod = 0,
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
    releaseCountPeriod: 1,
    collabCountPeriod: collabCountPeriod,
    liveEventsPeriod: liveEventsPeriod,
    strikes: 0,
  );
}

void main() {
  group('CommunityComponent', () {
    late CommunityComponent sut;

    setUp(() {
      sut = CommunityComponent(normalizer: MinMaxNormalizer());
    });

    test('should return value in 0..1 range', () {
      final current = _snap(collabCountPeriod: 3, liveEventsPeriod: 2);
      final all = [
        current,
        _snap(artistId: 'a2', collabCountPeriod: 0, liveEventsPeriod: 0),
        _snap(artistId: 'a3', collabCountPeriod: 5, liveEventsPeriod: 5),
      ];
      final result = sut.compute(current, all);
      expect(result, inInclusiveRange(0.0, 1.0));
    });

    test('should return 1.0 for highest community score', () {
      final current = _snap(collabCountPeriod: 10, liveEventsPeriod: 10);
      final all = [
        current,
        _snap(artistId: 'a2', collabCountPeriod: 0, liveEventsPeriod: 0),
      ];
      final result = sut.compute(current, all);
      expect(result, 1.0);
    });

    test('should return 0.0 for lowest community score', () {
      final current = _snap(collabCountPeriod: 0, liveEventsPeriod: 0);
      final all = [
        current,
        _snap(artistId: 'a2', collabCountPeriod: 5, liveEventsPeriod: 5),
      ];
      final result = sut.compute(current, all);
      expect(result, 0.0);
    });

    test('should return 0.0 when all values are zero', () {
      final current = _snap(collabCountPeriod: 0, liveEventsPeriod: 0);
      final all = [
        current,
        _snap(artistId: 'a2', collabCountPeriod: 0, liveEventsPeriod: 0),
      ];
      final result = sut.compute(current, all);
      expect(result, 0.0);
    });

    test('should weight collabs at 2x live events', () {
      // collabCountPeriod * 2 + liveEventsPeriod
      // a1: 5 * 2 + 0 = 10
      // a2: 0 * 2 + 10 = 10
      // Both should be equal
      final a1 = _snap(artistId: 'a1', collabCountPeriod: 5, liveEventsPeriod: 0);
      final a2 = _snap(artistId: 'a2', collabCountPeriod: 0, liveEventsPeriod: 10);
      final all = [a1, a2];
      expect(sut.compute(a1, all), sut.compute(a2, all));
    });

    test('should handle single artist in list', () {
      final current = _snap(collabCountPeriod: 5, liveEventsPeriod: 3);
      // Single element => span = 0 => 0.0 from MinMax
      final result = sut.compute(current, [current]);
      expect(result, 0.0);
    });
  });
}
