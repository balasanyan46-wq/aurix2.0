import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart' as engine;
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart' as engine;
import 'package:aurix_flutter/features/index_engine/domain/levels/artist_insights.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badge_engine.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/level_engine.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/next_step_engine.dart';

final levelEngineProvider = Provider<LevelEngine>((ref) => LevelEngine());
final badgeEngineProvider = Provider<BadgeEngine>((ref) => BadgeEngine());
final nextStepEngineProvider = Provider<NextStepEngine>((ref) => NextStepEngine());

final artistInsightsProvider = FutureProvider.family<ArtistInsights?, String>((ref, artistId) async {
  final service = ref.watch(indexEngineServiceProvider);
  final engineRepo = ref.watch(indexEngineRepositoryProvider);
  final levelEngine = ref.watch(levelEngineProvider);
  final badgeEngine = ref.watch(badgeEngineProvider);
  final nextStepEngine = ref.watch(nextStepEngineProvider);

  final now = DateTime.now();
  final periodStart = DateTime(now.year, now.month - 1, 1);
  final periodEnd = now;

  final score = await service.getArtistScore(artistId, periodStart, periodEnd);
  if (score == null) return null;

  final snapshots = await engineRepo.getSnapshots(from: periodStart, to: periodEnd);
  final artistSnapshots = snapshots.where((s) => s.artistId == artistId).toList()
    ..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
  final currentSnapshot = artistSnapshots.isNotEmpty ? artistSnapshots.first : null;
  final prevSnapshot = artistSnapshots.length > 1 ? artistSnapshots[1] : null;

  if (currentSnapshot == null) return null;

  final level = levelEngine.getLevel(score.score);
  final progress = levelEngine.progressToNextLevel(score.score);
  final pointsToNext = levelEngine.pointsToNextLevel(score.score);
  final badges = badgeEngine.computeBadges(score, currentSnapshot, prev: prevSnapshot);

  final leaderboard = await service.getLeaderboard(periodStart, periodEnd);
  final top10Score = leaderboard.length >= 10
      ? leaderboard[9].score.score
      : null;
  final nextStepPlan = nextStepEngine.buildNextSteps(
    score,
    currentSnapshot,
    prev: prevSnapshot,
    top10Score: top10Score,
  );

  return ArtistInsights(
    level: level,
    progressToNext: progress,
    pointsToNext: pointsToNext,
    badges: badges,
    nextStepPlan: nextStepPlan,
  );
});
