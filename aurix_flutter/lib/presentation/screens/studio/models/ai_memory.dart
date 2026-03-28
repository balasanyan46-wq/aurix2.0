import 'dart:convert';

/// Stores recent AI results for personalization and continuity.
class AiMemory {
  List<AiMemoryEntry> entries;

  AiMemory({List<AiMemoryEntry>? entries}) : entries = entries ?? [];

  static const int maxEntries = 30;

  void add(String characterId, String idea, String result) {
    entries.add(AiMemoryEntry(
      characterId: characterId,
      idea: idea,
      result: result,
      ts: DateTime.now(),
    ));
    if (entries.length > maxEntries) {
      entries = entries.sublist(entries.length - maxEntries);
    }
  }

  /// Last N entries for a specific character.
  List<AiMemoryEntry> forCharacter(String id, [int n = 3]) {
    return entries.where((e) => e.characterId == id).toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
  }

  /// Build summary for AI context — last ideas across all characters.
  String toAiContext({int limit = 5}) {
    if (entries.isEmpty) return '';
    final recent = entries.reversed.take(limit).toList();
    final lines = recent.map((e) => '- [${e.characterLabel}] ${e.idea}').toList();
    return 'Последние запросы артиста:\n${lines.join('\n')}';
  }

  /// All unique ideas (for artist screen).
  List<String> get recentIdeas {
    final seen = <String>{};
    return entries.reversed
        .where((e) => e.idea.isNotEmpty && seen.add(e.idea))
        .take(10)
        .map((e) => e.idea)
        .toList();
  }

  Map<String, dynamic> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory AiMemory.fromJson(Map<String, dynamic> j) => AiMemory(
    entries: (j['entries'] as List?)
        ?.map((e) => AiMemoryEntry.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );

  String encode() => jsonEncode(toJson());
  static AiMemory decode(String s) => AiMemory.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class AiMemoryEntry {
  final String characterId;
  final String idea;
  final String result;
  final DateTime ts;

  const AiMemoryEntry({
    required this.characterId,
    required this.idea,
    required this.result,
    required this.ts,
  });

  String get characterLabel => switch (characterId) {
    'producer' => 'Продюсер',
    'writer' => 'Автор',
    'visual' => 'Визуал',
    'smm' => 'SMM',
    _ => characterId,
  };

  Map<String, dynamic> toJson() => {
    'characterId': characterId,
    'idea': idea,
    'result': result,
    'ts': ts.toIso8601String(),
  };

  factory AiMemoryEntry.fromJson(Map<String, dynamic> j) => AiMemoryEntry(
    characterId: j['characterId'] as String? ?? '',
    idea: j['idea'] as String? ?? '',
    result: j['result'] as String? ?? '',
    ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
  );
}
