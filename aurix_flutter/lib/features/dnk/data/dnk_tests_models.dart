class DnkTestCatalogItem {
  final String slug;
  final String title;
  final String description;
  final String whatGives;
  final String exampleResult;
  final Map<String, dynamic> exampleJson;

  const DnkTestCatalogItem({
    required this.slug,
    required this.title,
    required this.description,
    required this.whatGives,
    required this.exampleResult,
    required this.exampleJson,
  });

  factory DnkTestCatalogItem.fromJson(Map<String, dynamic> j) => DnkTestCatalogItem(
        slug: (j['slug'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        whatGives: (j['what_gives'] ?? '').toString(),
        exampleResult: (j['example_result'] ?? '').toString(),
        exampleJson: (j['example_json'] is Map<String, dynamic>)
            ? (j['example_json'] as Map<String, dynamic>)
            : <String, dynamic>{},
      );
}

class DnkTestOption {
  final String key;
  final String text;

  const DnkTestOption({required this.key, required this.text});

  factory DnkTestOption.fromJson(Map<String, dynamic> j) => DnkTestOption(
        key: (j['key'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
      );
}

class DnkTestQuestion {
  final String id;
  final String type;
  final String text;
  final String testSlug;
  final bool isFollowup;
  final List<String>? scaleLabels;
  final List<DnkTestOption>? options;

  const DnkTestQuestion({
    required this.id,
    required this.type,
    required this.text,
    required this.testSlug,
    required this.isFollowup,
    this.scaleLabels,
    this.options,
  });

  factory DnkTestQuestion.fromJson(Map<String, dynamic> j) => DnkTestQuestion(
        id: (j['id'] ?? '').toString(),
        type: (j['type'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        testSlug: (j['test_slug'] ?? '').toString(),
        isFollowup: j['is_followup'] == true,
        scaleLabels: (j['scale_labels'] is List)
            ? (j['scale_labels'] as List).map((e) => e.toString()).toList()
            : null,
        options: (j['options'] is List)
            ? (j['options'] as List)
                .whereType<Map<String, dynamic>>()
                .map(DnkTestOption.fromJson)
                .toList()
            : null,
      );
}

class DnkTestStartResponse {
  final String sessionId;
  final String testSlug;
  final List<DnkTestQuestion> questions;

  const DnkTestStartResponse({
    required this.sessionId,
    required this.testSlug,
    required this.questions,
  });

  factory DnkTestStartResponse.fromJson(Map<String, dynamic> j) => DnkTestStartResponse(
        sessionId: (j['session_id'] ?? '').toString(),
        testSlug: (j['test_slug'] ?? '').toString(),
        questions: (j['questions'] is List)
            ? (j['questions'] as List)
                .whereType<Map<String, dynamic>>()
                .map(DnkTestQuestion.fromJson)
                .toList()
            : const [],
      );
}

class DnkTestFollowupResponse {
  final bool ok;
  final DnkTestQuestion? followup;

  const DnkTestFollowupResponse({required this.ok, this.followup});

  factory DnkTestFollowupResponse.fromJson(Map<String, dynamic> j) => DnkTestFollowupResponse(
        ok: j['ok'] == true,
        followup: (j['followup'] is Map<String, dynamic>)
            ? DnkTestQuestion.fromJson(j['followup'] as Map<String, dynamic>)
            : null,
      );
}

class DnkTestResult {
  final String resultId;
  final String sessionId;
  final String testSlug;
  final Map<String, double> scoreAxes;
  final String summary;
  final List<String> strengths;
  final List<String> risks;
  final List<String> actions7Days;
  final List<String> contentPrompts;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> confidence;
  final int regenCount;

  const DnkTestResult({
    required this.resultId,
    required this.sessionId,
    required this.testSlug,
    required this.scoreAxes,
    required this.summary,
    required this.strengths,
    required this.risks,
    required this.actions7Days,
    required this.contentPrompts,
    required this.payload,
    required this.confidence,
    required this.regenCount,
  });

  factory DnkTestResult.fromJson(Map<String, dynamic> j) {
    final rawAxes = (j['score_axes'] is Map<String, dynamic>)
        ? (j['score_axes'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final parsedAxes = <String, double>{};
    for (final e in rawAxes.entries) {
      if (e.value is num) parsedAxes[e.key] = (e.value as num).toDouble();
    }
    List<String> toStringList(dynamic x) =>
        x is List ? x.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList() : const [];

    return DnkTestResult(
      resultId: (j['result_id'] ?? j['id'] ?? '').toString(),
      sessionId: (j['session_id'] ?? '').toString(),
      testSlug: (j['test_slug'] ?? '').toString(),
      scoreAxes: parsedAxes,
      summary: (j['summary'] ?? '').toString(),
      strengths: toStringList(j['strengths']),
      risks: toStringList(j['risks']),
      actions7Days: toStringList(j['actions_7_days']),
      contentPrompts: toStringList(j['content_prompts']),
      payload: (j['payload'] is Map<String, dynamic>) ? (j['payload'] as Map<String, dynamic>) : <String, dynamic>{},
      confidence: (j['confidence'] is Map<String, dynamic>) ? (j['confidence'] as Map<String, dynamic>) : <String, dynamic>{},
      regenCount: (j['regen_count'] is num) ? (j['regen_count'] as num).toInt() : 0,
    );
  }
}

class DnkTestProgressItem {
  final String testSlug;
  final bool completed;
  final String? sessionId;
  final String? resultId;
  final DateTime? completedAt;

  const DnkTestProgressItem({
    required this.testSlug,
    required this.completed,
    this.sessionId,
    this.resultId,
    this.completedAt,
  });

  factory DnkTestProgressItem.fromJson(Map<String, dynamic> j) => DnkTestProgressItem(
        testSlug: (j['test_slug'] ?? '').toString(),
        completed: j['completed'] == true,
        sessionId: j['session_id']?.toString(),
        resultId: j['result_id']?.toString(),
        completedAt: DateTime.tryParse((j['completed_at'] ?? '').toString()),
      );
}
