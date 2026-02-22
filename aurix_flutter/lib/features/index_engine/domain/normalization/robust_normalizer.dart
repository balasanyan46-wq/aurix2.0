import 'dart:math' as math;
import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// Robust: clip by percentiles (p5..p95) to reduce impact of outliers.
class RobustNormalizer implements Normalizer {
  final double lowerPercentile;
  final double upperPercentile;

  const RobustNormalizer({
    this.lowerPercentile = 5.0,
    this.upperPercentile = 95.0,
  });

  @override
  double normalize(double value, List<double> allValues) {
    if (allValues.isEmpty) return 0.0;
    final sorted = List<double>.from(allValues)..sort();
    final p5Idx = (sorted.length * lowerPercentile / 100).floor().clamp(0, sorted.length - 1);
    final p95Idx = (sorted.length * upperPercentile / 100).floor().clamp(0, sorted.length - 1);
    final min = sorted[math.min(p5Idx, p95Idx)];
    final max = sorted[math.max(p5Idx, p95Idx)];
    final span = max - min;
    if (span <= 0) return 0.0;
    return ((value - min) / span).clamp(0.0, 1.0);
  }
}
