import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/penalty/fraud_detector.dart';

/// Penalty: strikes + suspicion -> final penalty 0..1.
class PenaltyEngine {
  final IndexConfig config;
  final FraudDetector fraudDetector;

  PenaltyEngine({required this.config, required this.fraudDetector});

  double compute(
    double baseScore,
    MetricsSnapshot current,
    MetricsSnapshot? previous,
    double engagementScore,
  ) {
    final suspicion = fraudDetector.detect(current, previous, engagementScore);
    final strikePenalty = current.strikes * config.strikePenaltyPerUnit;
    final suspicionPenalty = suspicion * config.suspicionToPenaltyFactor;
    final penalty = (strikePenalty + suspicionPenalty).clamp(0.0, config.maxPenalty);
    return penalty;
  }
}
