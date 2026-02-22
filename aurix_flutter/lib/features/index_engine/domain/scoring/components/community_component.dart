import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Community: collabCountPeriod + liveEventsPeriod.
class CommunityComponent {
  final Normalizer normalizer;

  const CommunityComponent({required this.normalizer});

  double compute(
    MetricsSnapshot current,
    List<MetricsSnapshot> all,
  ) {
    final rawValue = (current.collabCountPeriod * 2 + current.liveEventsPeriod).toDouble();
    final allValues = all.map((s) => (s.collabCountPeriod * 2 + s.liveEventsPeriod).toDouble()).toList();
    return normalizer.normalize(rawValue, allValues).clamp(0.0, 1.0);
  }
}
