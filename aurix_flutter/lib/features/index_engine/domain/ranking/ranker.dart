import 'package:aurix_flutter/features/index_engine/data/models/artist.dart';
import 'package:aurix_flutter/features/index_engine/data/models/index_score.dart';

/// Assigns rankOverall and rankInGenre. Computes trendDelta from previous scores.
class Ranker {
  List<IndexScore> rank(
    List<IndexScore> scores,
    Map<String, Artist> artistById,
    Map<String, IndexScore> previousScores,
  ) {
    scores = List.from(scores)..sort((a, b) => b.score.compareTo(a.score));
    final byGenre = <String, List<IndexScore>>{};
    for (final s in scores) {
      final artist = artistById[s.artistId];
      final genre = artist?.genrePrimary ?? 'Unknown';
      byGenre.putIfAbsent(genre, () => []).add(s);
    }
    for (final list in byGenre.values) {
      list.sort((a, b) => b.score.compareTo(a.score));
    }
    final genreRank = <String, int>{};
    for (final e in byGenre.entries) {
      for (var i = 0; i < e.value.length; i++) {
        genreRank['${e.value[i].artistId}:${e.key}'] = i + 1;
      }
    }
    final result = <IndexScore>[];
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      final artist = artistById[s.artistId];
      final genre = artist?.genrePrimary ?? 'Unknown';
      final prev = previousScores[s.artistId];
      final trendDelta = prev != null ? (s.score - prev.score).clamp(-999, 999) : 0;
      result.add(IndexScore(
        artistId: s.artistId,
        periodStart: s.periodStart,
        periodEnd: s.periodEnd,
        score: s.score,
        rankOverall: i + 1,
        rankInGenre: genreRank['${s.artistId}:$genre'] ?? (i + 1),
        trendDelta: trendDelta,
        breakdown: s.breakdown,
        penaltyApplied: s.penaltyApplied,
        updatedAt: s.updatedAt,
      ));
    }
    return result;
  }
}
