import 'package:aurix_flutter/features/index_engine/data/models/anomaly_signal.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/robust_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/community_component.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/consistency_component.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/engagement_component.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/growth_component.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/components/momentum_component.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/fraud_detector.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/penalty_engine.dart';

/// Computes Index 0..1000 from weighted components. score = scale * sum(components) * (1 - penalty).
class IndexCalculator {
  final IndexConfig config;
  late final Normalizer _normalizer;
  late final GrowthComponent _growth;
  late final EngagementComponent _engagement;
  late final ConsistencyComponent _consistency;
  late final MomentumComponent _momentum;
  late final CommunityComponent _community;
  late final FraudDetector _fraudDetector;
  late final PenaltyEngine _penaltyEngine;

  IndexCalculator({IndexConfig? config})
      : config = config ?? const IndexConfig() {
    _normalizer = config?.normalization == 'robust'
        ? RobustNormalizer()
        : MinMaxNormalizer();
    _growth = GrowthComponent(normalizer: _normalizer);
    _engagement = EngagementComponent(normalizer: _normalizer);
    _consistency = ConsistencyComponent(normalizer: _normalizer);
    _momentum = MomentumComponent(normalizer: _normalizer);
    _community = CommunityComponent(normalizer: _normalizer);
    _fraudDetector = FraudDetector(config: this.config);
    _penaltyEngine = PenaltyEngine(config: this.config, fraudDetector: _fraudDetector);
  }

  List<IndexScore> calculateScores(
    List<MetricsSnapshot> snapshots,
    DateTime periodStart,
    DateTime periodEnd,
  ) {
    _fraudDetector.clearSignals();
    final byArtist = <String, List<MetricsSnapshot>>{};
    for (final s in snapshots) {
      if (s.periodStart.isBefore(periodEnd) && s.periodEnd.isAfter(periodStart)) {
        byArtist.putIfAbsent(s.artistId, () => []).add(s);
      }
    }
    final allCurrent = <MetricsSnapshot>[];
    final allPairs = <({MetricsSnapshot current, MetricsSnapshot? previous})>[];
    for (final list in byArtist.values) {
      final sorted = List<MetricsSnapshot>.from(list)..sort((a, b) => b.periodEnd.compareTo(a.periodEnd));
      final current = sorted.isNotEmpty ? sorted.first : null;
      final previous = sorted.length > 1 ? sorted[1] : null;
      if (current != null) {
        allCurrent.add(current);
        allPairs.add((current: current, previous: previous));
      }
    }
    final results = <IndexScore>[];
    for (final pair in allPairs) {
      final growth = _growth.compute(pair.current, pair.previous, allPairs);
      final engagement = _engagement.compute(pair.current, allCurrent);
      final consistency = _consistency.compute(pair.current, allCurrent);
      final momentum = _momentum.compute(pair.current, pair.previous, allPairs);
      final community = _community.compute(pair.current, allCurrent);
      var raw = config.growthWeight * growth +
          config.engagementWeight * engagement +
          config.consistencyWeight * consistency +
          config.momentumWeight * momentum +
          config.communityWeight * community;
      raw = raw.clamp(0.0, 1.0);
      final penalty = _penaltyEngine.compute(raw, pair.current, pair.previous, engagement);
      final baseScore = raw * config.scoreScale;
      final score = (baseScore * (1 - penalty)).round().clamp(0, config.scoreScale);
      results.add(IndexScore(
        artistId: pair.current.artistId,
        periodStart: periodStart,
        periodEnd: periodEnd,
        score: score,
        rankOverall: 0,
        rankInGenre: 0,
        trendDelta: 0,
        breakdown: {
          'growth': growth,
          'engagement': engagement,
          'consistency': consistency,
          'momentum': momentum,
          'community': community,
        },
        penaltyApplied: penalty,
        updatedAt: periodEnd,
      ));
    }
    return results;
  }

  List<AnomalySignal> get anomalySignals => _fraudDetector.signals;
}
