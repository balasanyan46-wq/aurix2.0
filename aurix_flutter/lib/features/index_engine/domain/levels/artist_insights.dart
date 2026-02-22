import 'package:aurix_flutter/features/index_engine/domain/levels/artist_level.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badge.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/next_step.dart';

/// Aggregated insights: Level + Badges + NextSteps.
class ArtistInsights {
  final ArtistLevel level;
  final double progressToNext;
  final int pointsToNext;
  final List<Badge> badges;
  final NextStepPlan nextStepPlan;

  const ArtistInsights({
    required this.level,
    required this.progressToNext,
    required this.pointsToNext,
    required this.badges,
    required this.nextStepPlan,
  });
}
