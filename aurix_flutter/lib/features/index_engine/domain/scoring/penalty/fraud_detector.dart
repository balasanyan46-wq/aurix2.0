import 'dart:math' as math;
import 'package:aurix_flutter/features/index_engine/data/models/anomaly_signal.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_config.dart';

/// Detects anomalies: sharp spikes with low engagement -> suspicion.
class FraudDetector {
  final IndexConfig config;
  final List<AnomalySignal> _signals = [];

  FraudDetector({required this.config});

  List<AnomalySignal> get signals => List.unmodifiable(_signals);

  void clearSignals() => _signals.clear();

  /// Returns suspicion score 0..1. High = likely fraud.
  double detect(MetricsSnapshot current, MetricsSnapshot? previous, double engagementScore) {
    if (previous == null) return 0.0;
    final prevStreams = math.max(previous.streams, 1);
    final prevListeners = math.max(previous.listenersMonthly, 1);
    final streamsRatio = current.streams / prevStreams;
    final listenersRatio = current.listenersMonthly / prevListeners;
    double suspicion = 0.0;
    final now = DateTime.now();
    if (streamsRatio > config.streamsGrowthThreshold) {
      suspicion += 0.5;
      _signals.add(AnomalySignal(
        artistId: current.artistId,
        type: 'streams_spike',
        value: streamsRatio,
        threshold: config.streamsGrowthThreshold,
        suspicionScore: suspicion,
        timestamp: now,
      ));
    }
    if (listenersRatio > config.listenersGrowthThreshold) {
      suspicion += 0.5;
      _signals.add(AnomalySignal(
        artistId: current.artistId,
        type: 'listeners_spike',
        value: listenersRatio,
        threshold: config.listenersGrowthThreshold,
        suspicionScore: suspicion,
        timestamp: now,
      ));
    }
    if (suspicion > 0 && engagementScore < 0.3) {
      suspicion += 0.3;
    }
    return suspicion.clamp(0.0, 1.0);
  }
}
