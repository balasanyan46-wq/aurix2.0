import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badge.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badges_config.dart';

/// Computes badges from IndexScore + MetricsSnapshot. Not tied to UI.
class BadgeEngine {
  final BadgesConfig config;

  BadgeEngine({BadgesConfig? config}) : config = config ?? const BadgesConfig();

  List<Badge> computeBadges(
    IndexScore score,
    MetricsSnapshot snapshot, {
    MetricsSnapshot? prev,
  }) {
    final badges = <Badge>[];

    if (score.rankOverall <= config.top10OverallRank) {
      badges.add(const Badge(
        id: 'top10_overall',
        title: 'Top 10',
        description: 'В топ-10 общего рейтинга',
        iconKey: 'emoji_events',
        rarity: 'epic',
        ruleType: 'rank',
      ));
    }
    if (score.rankOverall <= config.top100OverallRank) {
      badges.add(const Badge(
        id: 'top100_overall',
        title: 'Top 100',
        description: 'В топ-100 общего рейтинга',
        iconKey: 'military_tech',
        rarity: 'rare',
        ruleType: 'rank',
      ));
    }
    if (score.rankInGenre <= config.top10GenreRank) {
      badges.add(const Badge(
        id: 'top10_genre',
        title: 'Top 10 жанра',
        description: 'В топ-10 своего жанра',
        iconKey: 'local_fire_department',
        rarity: 'rare',
        ruleType: 'rank',
      ));
    }
    if (score.trendDelta >= config.risingStarTrendDelta) {
      badges.add(const Badge(
        id: 'rising_star',
        title: 'Rising Star',
        description: 'Быстрый рост индекса',
        iconKey: 'trending_up',
        rarity: 'rare',
        ruleType: 'growth',
      ));
    }
    if (snapshot.releaseCountPeriod >= config.consistentReleaseCount) {
      badges.add(const Badge(
        id: 'consistent_release',
        title: 'Consistent',
        description: 'Регулярные релизы',
        iconKey: 'repeat',
        rarity: 'common',
        ruleType: 'consistency',
      ));
    }

    final streams = snapshot.streams > 0 ? snapshot.streams : 1;
    final sharesRate = snapshot.shares / streams;
    if (sharesRate >= config.viralSharesRateThreshold) {
      badges.add(const Badge(
        id: 'viral',
        title: 'Viral',
        description: 'Высокий share rate',
        iconKey: 'volunteer_activism',
        rarity: 'rare',
        ruleType: 'engagement',
      ));
    }

    final savesRate = snapshot.saves / streams;
    if (savesRate >= config.highEngagementSavesRateThreshold) {
      badges.add(const Badge(
        id: 'high_engagement',
        title: 'High Engagement',
        description: 'Высокий saves rate',
        iconKey: 'favorite',
        rarity: 'common',
        ruleType: 'engagement',
      ));
    }

    if (score.penaltyApplied == 0 && score.trendDelta > 0) {
      badges.add(const Badge(
        id: 'clean_growth',
        title: 'Clean Growth',
        description: 'Органический рост без аномалий',
        iconKey: 'verified',
        rarity: 'epic',
        ruleType: 'growth',
      ));
    }

    return badges;
  }
}
