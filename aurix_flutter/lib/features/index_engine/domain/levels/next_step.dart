/// Actionable suggestion to improve index.
class NextStep {
  final String title;
  final String description;
  final String metricKey;
  final num targetDelta;
  final String actionType;
  final int priority;

  const NextStep({
    required this.title,
    required this.description,
    required this.metricKey,
    required this.targetDelta,
    required this.actionType,
    this.priority = 0,
  });
}

/// Optional plan with delta to Top 10.
class NextStepPlan {
  final List<NextStep> steps;
  final int? toTop10Delta;
  final String? forecast;

  const NextStepPlan({
    required this.steps,
    this.toTop10Delta,
    this.forecast,
  });
}
