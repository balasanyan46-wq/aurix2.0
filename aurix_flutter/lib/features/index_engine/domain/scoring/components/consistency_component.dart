import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Consistency: releaseCountPeriod, optionally streak (mocked).
class ConsistencyComponent {
  final Normalizer normalizer;

  const ConsistencyComponent({required this.normalizer});

  double compute(
    MetricsSnapshot current,
    List<MetricsSnapshot> all,
  ) {
    final rawValue = current.releaseCountPeriod.toDouble();
    final allValues = all.map((s) => s.releaseCountPeriod.toDouble()).toList();
    return normalizer.normalize(rawValue, allValues).clamp(0.0, 1.0);
  }
}
