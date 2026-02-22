import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart';

/// Assigns badges based on IndexScore and MetricsSnapshot.
class BadgeEngine {
  static const String top10 = 'top10';
  static const String rising = 'rising';
  static const String consistent = 'consistent';
  static const String viral = 'viral';

  static const int risingThreshold = 30;
  static const int consistentReleases = 2;
  static const int viralSharesFactor = 500; // shares per 100k streams

  List<IndexScore> applyBadges(
    List<IndexScore> scores,
    List<MetricsSnapshot> snapshots,
  ) {
    final byArtist = <String, MetricsSnapshot>{};
    for (final s in snapshots) {
      final existing = byArtist[s.artistId];
      if (existing == null || s.periodEnd.isAfter(existing.periodEnd)) {
        byArtist[s.artistId] = s;
      }
    }

    final byArtistReleases = <String, int>{};
    for (final s in snapshots) {
      byArtistReleases[s.artistId] = (byArtistReleases[s.artistId] ?? 0) + s.releaseCountPeriod;
    }

    return scores.asMap().entries.map((e) {
      final rank = e.key + 1;
      final score = e.value;
      final snap = byArtist[score.artistId];
      final badges = <String>[];

      if (rank <= 10) badges.add(top10);
      if (score.trendDelta >= risingThreshold) badges.add(rising);
      final releases = byArtistReleases[score.artistId] ?? 0;
      if (releases >= consistentReleases) badges.add(consistent);
      if (snap != null && snap.streams > 10000) {
        final shareRate = snap.shares / (snap.streams / 100000);
        if (shareRate >= viralSharesFactor) badges.add(viral);
      }

      return IndexScore(
        artistId: score.artistId,
        score: score.score,
        rankOverall: rank,
        rankInGenre: score.rankInGenre,
        trendDelta: score.trendDelta,
        badges: badges,
        updatedAt: score.updatedAt,
      );
    }).toList();
  }
}
