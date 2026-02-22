import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Momentum: acceleration (currentGrowth - previousGrowth). Trend proxy.
class MomentumComponent {
  final Normalizer normalizer;

  const MomentumComponent({required this.normalizer});

  double compute(
    MetricsSnapshot current,
    MetricsSnapshot? previous,
    List<({MetricsSnapshot current, MetricsSnapshot? previous})> all,
  ) {
    if (previous == null) return 0.5;
    final currentGrowth = previous.streams > 0
        ? (current.streams - previous.streams) / previous.streams
        : 0.0;
    final rawValue = currentGrowth;
    final allValues = all.where((e) => e.previous != null).map((e) {
      final prev = e.previous!;
      return prev.streams > 0 ? (e.current.streams - prev.streams) / prev.streams : 0.0;
    }).toList();
    if (allValues.isEmpty) return 0.5;
    return normalizer.normalize(rawValue, allValues).clamp(0.0, 1.0);
  }
}
