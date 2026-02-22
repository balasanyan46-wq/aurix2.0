import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badge_engine.dart';

void main() {
  late BadgeEngine engine;

  setUp(() {
    engine = BadgeEngine();
  });

  IndexScore score({
    required String artistId,
    int score = 500,
    int rankOverall = 50,
    int rankInGenre = 5,
    int trendDelta = 0,
    double penaltyApplied = 0,
  }) {
    final now = DateTime.now();
    return IndexScore(
      artistId: artistId,
      periodStart: DateTime(now.year, now.month - 1, 1),
      periodEnd: now,
      score: score,
      rankOverall: rankOverall,
      rankInGenre: rankInGenre,
      trendDelta: trendDelta,
      breakdown: {},
      penaltyApplied: penaltyApplied,
      updatedAt: now,
    );
  }

  MetricsSnapshot snapshot({
    required String artistId,
    int streams = 10000,
    int saves = 500,
    int shares = 200,
    int releaseCountPeriod = 1,
  }) {
    final now = DateTime.now();
    return MetricsSnapshot(
      artistId: artistId,
      periodStart: DateTime(now.year, now.month - 1, 1),
      periodEnd: now,
      listenersMonthly: 5000,
      streams: streams,
      saves: saves,
      shares: shares,
      completionRate: 0.7,
      releaseCountPeriod: releaseCountPeriod,
      collabCountPeriod: 0,
      liveEventsPeriod: 0,
      strikes: 0,
    );
  }

  group('BadgeEngine', () {
    test('returns top10_overall when rankOverall <= 10', () {
      final s = score(artistId: 'a1', rankOverall: 5);
      final snap = snapshot(artistId: 'a1');
      final badges = engine.computeBadges(s, snap);
      expect(badges.any((b) => b.id == 'top10_overall'), isTrue);
    });

    test('returns top100_overall when rankOverall <= 100', () {
      final s = score(artistId: 'a1', rankOverall: 50);
      final snap = snapshot(artistId: 'a1');
      final badges = engine.computeBadges(s, snap);
      expect(badges.any((b) => b.id == 'top100_overall'), isTrue);
    });

    test('returns top10_genre when rankInGenre <= 10', () {
      final s = score(artistId: 'a1', rankInGenre: 5);
      final snap = snapshot(artistId: 'a1');
      final badges = engine.computeBadges(s, snap);
      expect(badges.any((b) => b.id == 'top10_genre'), isTrue);
    });

    test('returns rising_star when trendDelta >= threshold', () {
      final s = score(artistId: 'a1', trendDelta: 60);
      final snap = snapshot(artistId: 'a1');
      final badges = engine.computeBadges(s, snap);
      expect(badges.any((b) => b.id == 'rising_star'), isTrue);
    });
  });
}
