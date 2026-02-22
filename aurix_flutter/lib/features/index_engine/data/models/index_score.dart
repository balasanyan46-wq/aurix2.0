/// Engine Index score with full breakdown and penalty info.
class IndexScore {
  final String artistId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int score;
  final int rankOverall;
  final int rankInGenre;
  final int trendDelta;
  final Map<String, double> breakdown;
  final double penaltyApplied;
  final DateTime updatedAt;

  const IndexScore({
    required this.artistId,
    required this.periodStart,
    required this.periodEnd,
    required this.score,
    required this.rankOverall,
    required this.rankInGenre,
    required this.trendDelta,
    required this.breakdown,
    required this.penaltyApplied,
    required this.updatedAt,
  });
}
