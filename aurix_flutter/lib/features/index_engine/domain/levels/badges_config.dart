/// Configurable thresholds for badge rules.
class BadgesConfig {
  final int top10OverallRank;
  final int top100OverallRank;
  final int top10GenreRank;
  final int risingStarTrendDelta;
  final int consistentReleaseCount;
  final double viralSharesRateThreshold;
  final double highEngagementSavesRateThreshold;

  const BadgesConfig({
    this.top10OverallRank = 10,
    this.top100OverallRank = 100,
    this.top10GenreRank = 10,
    this.risingStarTrendDelta = 50,
    this.consistentReleaseCount = 2,
    this.viralSharesRateThreshold = 0.005,
    this.highEngagementSavesRateThreshold = 0.05,
  });
}
