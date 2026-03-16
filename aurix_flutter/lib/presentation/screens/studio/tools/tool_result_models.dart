enum StudioToolCanonicalId {
  growthPlan,
  budgetPlan,
  releasePackaging,
  contentPlan,
  pitchPack,
}

enum StudioResultStatus { ok, error }

class ResultMeta {
  final String requestId;
  final String generatedAt;
  final String model;

  const ResultMeta({
    required this.requestId,
    required this.generatedAt,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
        'request_id': requestId,
        'generated_at': generatedAt,
        'model': model,
      };
}

class ResultHero {
  final String title;
  final String subtitle;

  const ResultHero({
    required this.title,
    required this.subtitle,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
      };
}

class ResultPriority {
  final String title;
  final String why;
  final List<String> actions;
  final String effort;
  final String impact;

  const ResultPriority({
    required this.title,
    required this.why,
    required this.actions,
    required this.effort,
    required this.impact,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'why': why,
        'actions': actions,
        'effort': effort,
        'impact': impact,
      };
}

class ResultFirstAction {
  final String title;
  final int etaMinutes;
  final List<String> steps;

  const ResultFirstAction({
    required this.title,
    required this.etaMinutes,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'eta_minutes': etaMinutes,
        'steps': steps,
      };
}

class ResultRisk {
  final String title;
  final String signal;
  final String fix;

  const ResultRisk({
    required this.title,
    required this.signal,
    required this.fix,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'signal': signal,
        'fix': fix,
      };
}

class ToolResultError {
  final String code;
  final String message;
  final String? requestId;

  const ToolResultError({
    required this.code,
    required this.message,
    this.requestId,
  });
}

class NormalizedToolResult {
  final StudioToolCanonicalId toolId;
  final String version;
  final ResultMeta meta;
  final ResultHero hero;
  final List<String> summaryLines;
  final List<ResultPriority> priorities;
  final List<ResultFirstAction> firstActions;
  final List<ResultRisk> risksOrMistakes;
  final List<Map<String, dynamic>> specificSections;

  const NormalizedToolResult({
    required this.toolId,
    required this.version,
    required this.meta,
    required this.hero,
    required this.summaryLines,
    required this.priorities,
    required this.firstActions,
    required this.risksOrMistakes,
    required this.specificSections,
  });

  Map<String, dynamic> toJson() => {
        'tool_id': toolId.name,
        'version': version,
        'meta': meta.toJson(),
        'hero': hero.toJson(),
        'summary_lines': summaryLines,
        'priorities': priorities.map((e) => e.toJson()).toList(),
        'first_actions': firstActions.map((e) => e.toJson()).toList(),
        'risks_or_mistakes': risksOrMistakes.map((e) => e.toJson()).toList(),
        'specific_sections': specificSections,
      };
}

class ToolNormalizationOutcome {
  final StudioResultStatus status;
  final NormalizedToolResult? result;
  final ToolResultError? error;
  final Map<String, dynamic>? rawEnvelope;

  const ToolNormalizationOutcome._({
    required this.status,
    this.result,
    this.error,
    this.rawEnvelope,
  });

  const ToolNormalizationOutcome.ok(
    NormalizedToolResult value, {
    Map<String, dynamic>? rawEnvelope,
  }) : this._(
          status: StudioResultStatus.ok,
          result: value,
          rawEnvelope: rawEnvelope,
        );

  const ToolNormalizationOutcome.error(
    ToolResultError value, {
    Map<String, dynamic>? rawEnvelope,
  }) : this._(
          status: StudioResultStatus.error,
          error: value,
          rawEnvelope: rawEnvelope,
        );

  bool get isOk => status == StudioResultStatus.ok && result != null;
}
