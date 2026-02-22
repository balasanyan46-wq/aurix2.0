/// Interface for metric normalization. Input: values across artists. Output: 0..1.
abstract class Normalizer {
  double normalize(double value, List<double> allValues);
}
