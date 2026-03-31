import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/minmax_normalizer.dart';
import 'package:aurix_flutter/features/index_engine/domain/normalization/robust_normalizer.dart';

void main() {
  group('MinMaxNormalizer', () {
    late MinMaxNormalizer sut;

    setUp(() {
      sut = MinMaxNormalizer();
    });

    test('should return 0.0 for empty allValues', () {
      expect(sut.normalize(5.0, []), 0.0);
    });

    test('should return 0.0 when all values are identical', () {
      expect(sut.normalize(5.0, [5.0, 5.0, 5.0]), 0.0);
    });

    test('should return 0.0 for the minimum value', () {
      expect(sut.normalize(1.0, [1.0, 5.0, 10.0]), 0.0);
    });

    test('should return 1.0 for the maximum value', () {
      expect(sut.normalize(10.0, [1.0, 5.0, 10.0]), 1.0);
    });

    test('should return 0.5 for the midpoint value', () {
      expect(sut.normalize(5.5, [1.0, 10.0]), 0.5);
    });

    test('should clamp values above max to 1.0', () {
      expect(sut.normalize(15.0, [1.0, 10.0]), 1.0);
    });

    test('should clamp values below min to 0.0', () {
      expect(sut.normalize(-5.0, [1.0, 10.0]), 0.0);
    });

    test('should handle single-element list', () {
      // span = 0 => returns 0.0
      expect(sut.normalize(5.0, [5.0]), 0.0);
    });

    test('should handle negative values', () {
      final result = sut.normalize(0.0, [-10.0, 10.0]);
      expect(result, 0.5);
    });

    test('should handle very large values', () {
      final result = sut.normalize(500000.0, [0.0, 1000000.0]);
      expect(result, 0.5);
    });

    test('should produce correct intermediate value', () {
      // (3 - 1) / (5 - 1) = 0.5
      final result = sut.normalize(3.0, [1.0, 3.0, 5.0]);
      expect(result, 0.5);
    });
  });

  group('RobustNormalizer', () {
    late RobustNormalizer sut;

    setUp(() {
      sut = const RobustNormalizer();
    });

    test('should return 0.0 for empty allValues', () {
      expect(sut.normalize(5.0, []), 0.0);
    });

    test('should return 0.0 when all values are identical', () {
      expect(sut.normalize(5.0, [5.0, 5.0, 5.0]), 0.0);
    });

    test('should handle single-element list', () {
      // p5Idx = 0, p95Idx = 0, span = 0 => 0.0
      expect(sut.normalize(5.0, [5.0]), 0.0);
    });

    test('should normalize values within percentile range', () {
      // With many values, outliers are clipped
      final allValues = List.generate(100, (i) => i.toDouble());
      final result = sut.normalize(50.0, allValues);
      expect(result, inInclusiveRange(0.0, 1.0));
    });

    test('should clamp output to 0..1', () {
      final allValues = List.generate(100, (i) => i.toDouble());
      // Value well above range
      final high = sut.normalize(200.0, allValues);
      expect(high, 1.0);
      // Value well below range
      final low = sut.normalize(-50.0, allValues);
      expect(low, 0.0);
    });

    test('should reduce impact of outliers compared to minmax', () {
      // Most values cluster around 50, with a few extreme outliers.
      // Use only 3 outliers per side so that p5/p95 fall within the cluster.
      final allValues = [
        ...List.generate(94, (i) => 50.0 + i * 0.1),
        0.0, 0.0, 0.0,
        1000.0, 1000.0, 1000.0,
      ];
      final robust = sut.normalize(55.0, allValues);
      final minmax = MinMaxNormalizer().normalize(55.0, allValues);
      // Robust should give a higher score than minmax for a value near the cluster
      expect(robust, greaterThan(minmax));
    });

    test('should respect custom percentile bounds', () {
      final custom = const RobustNormalizer(
        lowerPercentile: 10.0,
        upperPercentile: 90.0,
      );
      final allValues = List.generate(100, (i) => i.toDouble());
      final result = custom.normalize(50.0, allValues);
      expect(result, inInclusiveRange(0.0, 1.0));
    });

    test('should handle two-element list', () {
      final result = sut.normalize(5.0, [0.0, 10.0]);
      // p5Idx = floor(2*5/100) = 0, p95Idx = floor(2*95/100) = 1
      // span = 10 - 0 = 10, (5-0)/10 = 0.5
      expect(result, 0.5);
    });
  });
}
