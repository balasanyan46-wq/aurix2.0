import 'package:aurix_flutter/features/index_engine/data/models/anomaly_signal.dart';
import 'package:aurix_flutter/features/index_engine/data/models/artist.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';
import 'package:aurix_flutter/features/index_engine/data/repositories/index_repository.dart';
import 'package:aurix_flutter/features/index_engine/domain/ranking/ranker.dart';
import 'package:aurix_flutter/features/index_engine/domain/scoring/index_calculator.dart';

/// Facade for Index Engine. Compute scores, leaderboard, breakdown.
class IndexEngineService {
  final IndexEngineRepository _repository;
  final IndexCalculator _calculator;
  final Ranker _ranker;

  IndexEngineService(this._repository)
      : _calculator = IndexCalculator(),
        _ranker = Ranker();

  Map<String, IndexScore>? _lastScores;
  Map<String, IndexScore>? _prevScores;
  DateTime? _lastPeriodStart;
  DateTime? _lastPeriodEnd;

  /// Compute scores for period. Caches result.
  Future<List<IndexScore>> computePeriodScores(
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final prevStart = DateTime(periodStart.year, periodStart.month - 1, periodStart.day);
    final prevEnd = DateTime(periodEnd.year, periodEnd.month - 1, periodEnd.day);
    final snapshots = await _repository.getSnapshots(from: prevStart, to: periodEnd);
    final artists = await _repository.getArtists();
    final artistById = {for (final a in artists) a.id: a};

    final prevSnapshots = snapshots
        .where((s) => s.periodStart.isBefore(prevEnd) && s.periodEnd.isAfter(prevStart))
        .toList();
    final prevScoresRaw = prevSnapshots.isNotEmpty
        ? _calculator.calculateScores(prevSnapshots, prevStart, prevEnd)
        : <IndexScore>[];
    _prevScores = {for (final s in prevScoresRaw) s.artistId: s};

    final scores = _calculator.calculateScores(snapshots, periodStart, periodEnd);
    final ranked = _ranker.rank(scores, artistById, _prevScores ?? {});
    _lastScores = {for (final s in ranked) s.artistId: s};
    _lastPeriodStart = periodStart;
    _lastPeriodEnd = periodEnd;
    return ranked;
  }

  /// Get leaderboard. Reuses last compute or triggers new one.
  Future<List<({IndexScore score, Artist artist})>> getLeaderboard(
    DateTime periodStart,
    DateTime periodEnd, {
    String? genre,
  }) async {
    List<IndexScore> scores;
    if (_lastPeriodStart == periodStart && _lastPeriodEnd == periodEnd && _lastScores != null) {
      scores = _lastScores!.values.toList()..sort((a, b) => a.rankOverall.compareTo(b.rankOverall));
    } else {
      scores = await computePeriodScores(periodStart, periodEnd);
    }
    final artists = await _repository.getArtists();
    final artistById = {for (final a in artists) a.id: a};
    var result = scores.map((s) {
      final a = artistById[s.artistId]!;
      return (score: s, artist: a);
    }).toList();
    if (genre != null) {
      result = result.where((e) => e.artist.genrePrimary == genre).toList();
    }
    return result;
  }

  /// Get score for one artist.
  Future<IndexScore?> getArtistScore(
    String artistId,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    if (_lastPeriodStart != periodStart || _lastPeriodEnd != periodEnd) {
      await computePeriodScores(periodStart, periodEnd);
    }
    return _lastScores?[artistId];
  }

  /// Get breakdown for artist.
  Future<Map<String, double>?> getBreakdown(
    String artistId,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final score = await getArtistScore(artistId, periodStart, periodEnd);
    return score?.breakdown;
  }

  List<AnomalySignal> get anomalySignals => _calculator.anomalySignals;
}
