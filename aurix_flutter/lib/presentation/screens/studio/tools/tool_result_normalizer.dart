import 'dart:convert';

import 'package:aurix_flutter/presentation/screens/studio/tools/tool_result_models.dart';

class ToolResultNormalizer {
  static ToolNormalizationOutcome normalize(String expectedToolKey, dynamic rawResponse) {
    final parsed = _parseEnvelope(rawResponse);
    if (parsed == null) {
      return const ToolNormalizationOutcome.error(
        ToolResultError(
          code: 'INVALID_ENVELOPE',
          message: 'AI вернул неподдерживаемый формат ответа',
        ),
      );
    }
    final expected = _canonicalFromToolKey(expectedToolKey);
    if (expected == null) {
      return ToolNormalizationOutcome.error(
        const ToolResultError(code: 'UNKNOWN_TOOL', message: 'Неизвестный инструмент Studio AI'),
        rawEnvelope: parsed,
      );
    }
    final version = parsed['version']?.toString().trim();
    if (version == null || version != '2') {
      return ToolNormalizationOutcome.error(
        const ToolResultError(
          code: 'INVALID_ENVELOPE_VERSION',
          message: 'AI вернул неподдерживаемую версию контракта',
        ),
        rawEnvelope: parsed,
      );
    }

    final status = parsed['status']?.toString().trim().toLowerCase();
    if (status != 'ok' && status != 'error') {
      return ToolNormalizationOutcome.error(
        const ToolResultError(
          code: 'INVALID_STATUS',
          message: 'AI вернул ответ в неподдерживаемом формате',
        ),
        rawEnvelope: parsed,
      );
    }

    final toolId = _canonicalFromContract(parsed['tool_id']?.toString());
    if (toolId == null || toolId != expected) {
      return ToolNormalizationOutcome.error(
        const ToolResultError(code: 'TOOL_ID_MISMATCH', message: 'AI вернул результат не того инструмента'),
        rawEnvelope: parsed,
      );
    }
    if (status == 'error') {
      return ToolNormalizationOutcome.error(
        ToolResultError(
          code: parsed['code']?.toString() ?? 'BACKEND_ERROR',
          message: parsed['message']?.toString() ?? 'AI не смог собрать нормальный результат',
          requestId: _pickString(parsed['meta'], 'request_id'),
        ),
        rawEnvelope: parsed,
      );
    }

    final data = parsed['data'];
    if (data is! Map<String, dynamic>) {
      return ToolNormalizationOutcome.error(
        const ToolResultError(code: 'MISSING_DATA', message: 'AI вернул пустой структурный результат'),
        rawEnvelope: parsed,
      );
    }
    if (_containsBlockedRaw(data)) {
      return ToolNormalizationOutcome.error(
        ToolResultError(
          code: 'INVALID_MODEL_OUTPUT',
          message: 'AI вернул неочищенный сырой ответ. Нажми Пересобрать.',
          requestId: _pickString(parsed['meta'], 'request_id'),
        ),
        rawEnvelope: parsed,
      );
    }
    try {
      final normalized = _byTool(
        toolId: toolId,
        data: data,
        version: version,
        meta: _parseMeta(parsed['meta']),
      );
      return ToolNormalizationOutcome.ok(normalized, rawEnvelope: parsed);
    } on FormatException catch (e) {
      return ToolNormalizationOutcome.error(
        ToolResultError(
          code: 'INVALID_MODEL_OUTPUT',
          message: e.message.isEmpty ? 'AI не смог собрать нормальный результат' : e.message,
          requestId: _pickString(parsed['meta'], 'request_id'),
        ),
        rawEnvelope: parsed,
      );
    }
  }

  static Map<String, dynamic>? _parseEnvelope(dynamic raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is! String) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is String) {
        final inner = jsonDecode(decoded);
        if (inner is Map) return Map<String, dynamic>.from(inner);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static bool _containsBlockedRaw(dynamic value, {String? keyHint}) {
    if (keyHint == 'raw_text') return true;
    if (value is String) {
      final text = value.toLowerCase();
      if (text.contains('```json') || text.contains('```')) return true;
      if (value.length > 5000) return true;
      return false;
    }
    if (value is List) {
      for (final item in value) {
        if (_containsBlockedRaw(item)) return true;
      }
      return false;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (_containsBlockedRaw(entry.value, keyHint: entry.key.toString())) return true;
      }
      return false;
    }
    return false;
  }

  static ResultMeta _parseMeta(dynamic raw) {
    if (raw is! Map) {
      return ResultMeta(
        requestId: 'n/a',
        generatedAt: DateTime.now().toUtc().toIso8601String(),
        model: 'unknown',
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return ResultMeta(
      requestId: map['request_id']?.toString() ?? 'n/a',
      generatedAt: map['generated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      model: map['model']?.toString() ?? 'unknown',
    );
  }

  static StudioToolCanonicalId? _canonicalFromToolKey(String key) {
    switch (key) {
      case 'growth-plan':
        return StudioToolCanonicalId.growthPlan;
      case 'budget-plan':
        return StudioToolCanonicalId.budgetPlan;
      case 'release-packaging':
        return StudioToolCanonicalId.releasePackaging;
      case 'content-plan-14':
        return StudioToolCanonicalId.contentPlan;
      case 'playlist-pitch-pack':
        return StudioToolCanonicalId.pitchPack;
      default:
        return null;
    }
  }

  static StudioToolCanonicalId? _canonicalFromContract(String? value) {
    switch ((value ?? '').trim()) {
      case 'growth_plan':
      case 'growth-plan':
        return StudioToolCanonicalId.growthPlan;
      case 'budget_manager':
      case 'budget_plan':
      case 'budget-plan':
        return StudioToolCanonicalId.budgetPlan;
      case 'release_packaging':
      case 'packaging':
      case 'release-packaging':
        return StudioToolCanonicalId.releasePackaging;
      case 'content_plan':
      case 'content-plan-14':
      case 'reels_content_plan':
        return StudioToolCanonicalId.contentPlan;
      case 'playlist_pitch':
      case 'pitch_pack':
      case 'playlist-pitch-pack':
        return StudioToolCanonicalId.pitchPack;
      default:
        return null;
    }
  }

  static NormalizedToolResult _byTool({
    required StudioToolCanonicalId toolId,
    required Map<String, dynamic> data,
    required String version,
    required ResultMeta meta,
  }) {
    final summary = data['summary'];
    if (summary is! String || summary.trim().isEmpty) {
      throw const FormatException('Поле "summary" обязательно');
    }
    final prioritiesRaw = data['priorities'];
    if (prioritiesRaw is! List || prioritiesRaw.isEmpty) {
      throw const FormatException('Список "priorities" должен содержать минимум 1 элемент');
    }

    final heroMap = data['hero'] is Map<String, dynamic> ? data['hero'] as Map<String, dynamic> : const <String, dynamic>{};
    final hero = ResultHero(
      title: (heroMap['title']?.toString().trim().isNotEmpty ?? false) ? heroMap['title'].toString().trim() : _defaultTitle(toolId),
      subtitle: (heroMap['subtitle']?.toString().trim().isNotEmpty ?? false) ? heroMap['subtitle'].toString().trim() : 'AI structured result',
    );

    final priorities = prioritiesRaw.map((item) {
      if (item is String) {
        final title = item.trim();
        if (title.isEmpty) throw const FormatException('Некорректный элемент в priorities');
        return ResultPriority(
          title: title,
          why: 'Приоритет от AI',
          actions: const [],
          effort: 'medium',
          impact: 'medium',
        );
      }
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final title = map['title']?.toString().trim() ?? '';
        final why = map['why']?.toString().trim() ?? '';
        if (title.isEmpty || why.isEmpty) throw const FormatException('Некорректный объект в priorities');
        final stepsRaw = map['steps'];
        final actions = stepsRaw is List ? stepsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList() : <String>[];
        return ResultPriority(
          title: title,
          why: why,
          actions: actions,
          effort: 'medium',
          impact: 'medium',
        );
      }
      throw const FormatException('Некорректный элемент в priorities');
    }).toList(growable: false);

    final firstActions = _optionalStringList(data['first_actions'])
        .map((e) => ResultFirstAction(title: e, etaMinutes: 30, steps: const []))
        .toList(growable: false);

    final risks = <ResultRisk>[];
    final risksRaw = data['risks'];
    if (risksRaw is List) {
      for (final item in risksRaw) {
        if (item is String && item.trim().isNotEmpty) {
          risks.add(ResultRisk(title: item.trim(), signal: 'Не указан', fix: 'Уточнить вручную'));
          continue;
        }
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final risk = map['risk']?.toString().trim() ?? '';
          final signal = map['signal']?.toString().trim() ?? '';
          final fix = map['fix']?.toString().trim() ?? '';
          if (risk.isNotEmpty && signal.isNotEmpty && fix.isNotEmpty) {
            risks.add(ResultRisk(title: risk, signal: signal, fix: fix));
          }
        }
      }
    }

    final specificSections = <Map<String, dynamic>>[];
    final altScenario = data['alt_scenario']?.toString();
    if (altScenario != null && altScenario.trim().isNotEmpty) {
      specificSections.add({'title': 'Альтернативный сценарий', 'items': [altScenario.trim()]});
    }

    return NormalizedToolResult(
      toolId: toolId,
      version: version,
      meta: meta,
      hero: hero,
      summaryLines: [summary.trim()],
      priorities: priorities,
      firstActions: firstActions,
      risksOrMistakes: risks,
      specificSections: specificSections,
    );
  }

  static String _defaultTitle(StudioToolCanonicalId toolId) {
    switch (toolId) {
      case StudioToolCanonicalId.growthPlan:
        return 'Growth plan';
      case StudioToolCanonicalId.budgetPlan:
        return 'Budget plan';
      case StudioToolCanonicalId.releasePackaging:
        return 'Packaging';
      case StudioToolCanonicalId.contentPlan:
        return 'Content plan';
      case StudioToolCanonicalId.pitchPack:
        return 'Pitch pack';
    }
  }

  static List<String> _optionalStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList(growable: false);
  }

  static String? _pickString(dynamic raw, String key) {
    if (raw is Map && raw[key] is String) return raw[key] as String;
    return null;
  }
}
