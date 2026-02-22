/// Snapshot of artist metrics for a period (month/week).
class MetricsSnapshot {
  final String artistId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int listenersMonthly;
  final int streams;
  final int saves;
  final int shares;
  final double completionRate;
  final int releaseCountPeriod;
  final int collabCountPeriod;
  final int liveEventsPeriod;
  final int strikes;

  const MetricsSnapshot({
    required this.artistId,
    required this.periodStart,
    required this.periodEnd,
    required this.listenersMonthly,
    required this.streams,
    required this.saves,
    required this.shares,
    required this.completionRate,
    required this.releaseCountPeriod,
    required this.collabCountPeriod,
    required this.liveEventsPeriod,
    this.strikes = 0,
  });
}
