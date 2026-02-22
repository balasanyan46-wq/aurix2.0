/// Configuration for Index calculation. Formula can be changed without rewriting logic.
class IndexConfig {
  final double growthWeight;
  final double engagementWeight;
  final double consistencyWeight;
  final double momentumWeight;
  final double communityWeight;
  final String normalization;
  final double? maxContributionPerComponent;
  final double streamsGrowthThreshold;
  final double listenersGrowthThreshold;
  final double suspicionToPenaltyFactor;
  final double strikePenaltyPerUnit;
  final double maxPenalty;
  final int scoreScale;
  final double? smoothingAlpha;

  const IndexConfig({
    this.growthWeight = 0.30,
    this.engagementWeight = 0.25,
    this.consistencyWeight = 0.20,
    this.momentumWeight = 0.15,
    this.communityWeight = 0.10,
    this.normalization = 'minmax',
    this.maxContributionPerComponent,
    this.streamsGrowthThreshold = 5.0,
    this.listenersGrowthThreshold = 5.0,
    this.suspicionToPenaltyFactor = 0.2,
    this.strikePenaltyPerUnit = 0.05,
    this.maxPenalty = 0.35,
    this.scoreScale = 1000,
    this.smoothingAlpha,
  });
}
