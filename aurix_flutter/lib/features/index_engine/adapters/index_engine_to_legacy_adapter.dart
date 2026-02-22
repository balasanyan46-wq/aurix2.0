import 'package:aurix_flutter/features/index/data/models/artist.dart' as legacy;
import 'package:aurix_flutter/features/index/data/models/index_score.dart' as legacy;
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart' as legacy;
import 'package:aurix_flutter/features/index/domain/badge_engine.dart';
import 'package:aurix_flutter/features/index_engine/data/models/artist.dart' as engine;
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart' as engine;
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart' as engine;
import 'package:aurix_flutter/features/index_engine/index_engine_service.dart';

/// Converts Index Engine output to legacy Index models for UI.
class IndexEngineToLegacyAdapter {
  final IndexEngineService service;
  final BadgeEngine _badgeEngine = BadgeEngine();

  IndexEngineToLegacyAdapter(this.service);

  legacy.Artist toLegacyArtist(engine.Artist a) {
    return legacy.Artist(
      id: a.id,
      name: a.name,
      avatarUrl: a.avatarUrl,
      genrePrimary: a.genrePrimary,
      location: a.region,
      aurixReleaseCount: 1,
      createdAt: a.createdAt,
    );
  }

  legacy.MetricsSnapshot toLegacySnapshot(engine.MetricsSnapshot s) {
    return legacy.MetricsSnapshot(
      artistId: s.artistId,
      periodStart: s.periodStart,
      periodEnd: s.periodEnd,
      listenersMonthly: s.listenersMonthly,
      streams: s.streams,
      saves: s.saves,
      shares: s.shares,
      completionRate: s.completionRate,
      releaseCountPeriod: s.releaseCountPeriod,
      collabCountPeriod: s.collabCountPeriod,
      liveEventsPeriod: s.liveEventsPeriod,
      strikes: s.strikes,
    );
  }

  List<legacy.IndexScore> toLegacyScores(
    List<engine.IndexScore> engineScores,
    List<legacy.MetricsSnapshot> legacySnapshots,
  ) {
    final legacyScores = engineScores.map((s) => legacy.IndexScore(
      artistId: s.artistId,
      score: s.score,
      rankOverall: s.rankOverall,
      rankInGenre: s.rankInGenre,
      trendDelta: s.trendDelta,
      badges: const [],
      updatedAt: s.updatedAt,
    )).toList();
    return _badgeEngine.applyBadges(legacyScores, legacySnapshots);
  }
}
