import 'dart:math' as math;
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Growth: listeners + streams growth vs previous period. Log-scale for fairness.
class GrowthComponent {
  final Normalizer normalizer;

  const GrowthComponent({required this.normalizer});

  double compute(
    MetricsSnapshot current,
    MetricsSnapshot? previous,
    List<({MetricsSnapshot current, MetricsSnapshot? previous})> all,
  ) {
    double rawValue;
    if (previous == null || (previous.listenersMonthly == 0 && previous.streams == 0)) {
      rawValue = math.log(1 + current.listenersMonthly) + math.log(1 + current.streams) * 0.5;
    } else {
      final listenersGrowth = previous.listenersMonthly > 0
          ? (current.listenersMonthly - previous.listenersMonthly) / previous.listenersMonthly
          : 0.0;
      final streamsGrowth = previous.streams > 0
          ? (current.streams - previous.streams) / previous.streams
          : 0.0;
      rawValue = (listenersGrowth + streamsGrowth) / 2;
    }
    final allValues = all.map<double>((e) {
      if (e.previous == null) {
        return math.log(1 + e.current.listenersMonthly) + math.log(1 + e.current.streams) * 0.5;
      }
      final lg = e.previous!.listenersMonthly > 0
          ? (e.current.listenersMonthly - e.previous!.listenersMonthly) / e.previous!.listenersMonthly
          : 0.0;
      final sg = e.previous!.streams > 0
          ? (e.current.streams - e.previous!.streams) / e.previous!.streams
          : 0.0;
      return (lg + sg) / 2;
    }).toList();
    return normalizer.normalize(rawValue, allValues).clamp(0.0, 1.0);
  }
}
