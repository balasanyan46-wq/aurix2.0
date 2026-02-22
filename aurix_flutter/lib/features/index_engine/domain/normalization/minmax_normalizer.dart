import 'package:aurix_flutter/features/index_engine/domain/normalization/normalizer.dart';

/// MinMax: norm = (x - min) / (max - min). If max==min => 0.0.
class MinMaxNormalizer implements Normalizer {
  @override
  double normalize(double value, List<double> allValues) {
    if (allValues.isEmpty) return 0.0;
    final min = allValues.reduce((a, b) => a < b ? a : b);
    final max = allValues.reduce((a, b) => a > b ? a : b);
    final span = max - min;
    if (span <= 0) return 0.0;
    return ((value - min) / span).clamp(0.0, 1.0);
  }
}
