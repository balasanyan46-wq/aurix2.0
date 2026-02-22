/// Signal from fraud detection for debugging/audit.
class AnomalySignal {
  final String artistId;
  final String type;
  final double value;
  final double threshold;
  final double? suspicionScore;
  final DateTime timestamp;

  const AnomalySignal({
    required this.artistId,
    required this.type,
    required this.value,
    required this.threshold,
    this.suspicionScore,
    required this.timestamp,
  });
}
