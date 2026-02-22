/// Aurix Index score for an artist.
class IndexScore {
  final String artistId;
  final int score;
  final int rankOverall;
  final int rankInGenre;
  final int trendDelta;
  final List<String> badges;
  final DateTime updatedAt;

  const IndexScore({
    required this.artistId,
    required this.score,
    required this.rankOverall,
    required this.rankInGenre,
    required this.trendDelta,
    required this.badges,
    required this.updatedAt,
  });
}
