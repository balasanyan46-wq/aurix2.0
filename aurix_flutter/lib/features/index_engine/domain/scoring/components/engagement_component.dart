import 'dart:math' as math;
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Engagement: saves rate, shares rate, completion rate.
class EngagementComponent {
  final Normalizer normalizer;

  const EngagementComponent({required this.normalizer});

  double compute(
    MetricsSnapshot current,
    List<MetricsSnapshot> all,
  ) {
    final streams = math.max(current.streams, 1);
    final savesRate = current.saves / streams;
    final sharesRate = current.shares / streams;
    final rawValue = savesRate * 10 + sharesRate * 50 + current.completionRate;
    final allValues = all.map((s) {
      final str = math.max(s.streams, 1);
      return (s.saves / str) * 10 + (s.shares / str) * 50 + s.completionRate;
    }).toList();
    return normalizer.normalize(rawValue, allValues).clamp(0.0, 1.0);
  }
}
