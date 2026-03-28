import 'dart:convert';

/// XP rewards for each action type.
enum XpAction {
  track(15, 'Создание трека', 'producer'),
  lyrics(10, 'Текст песни', 'writer'),
  pipeline(20, 'Полный pipeline', 'pipeline'),
  cover(15, 'Обложка', 'visual'),
  video(20, 'Видео / Reels', 'smm'),
  hitAnalysis(30, 'Потенциальный хит', 'analysis');

  final int xp;
  final String label;
  final String characterId;
  const XpAction(this.xp, this.label, this.characterId);

  /// Map character ID to XP action.
  static XpAction? fromCharacter(String id) => switch (id) {
    'producer' => XpAction.track,
    'writer' => XpAction.lyrics,
    'visual' => XpAction.cover,
    'smm' => XpAction.video,
    _ => null,
  };
}

/// A completed action with timestamp.
class CompletedAction {
  final String type; // XpAction.name
  final String label;
  final int xp;
  final DateTime ts;

  const CompletedAction({required this.type, required this.label, required this.xp, required this.ts});

  Map<String, dynamic> toJson() => {
    'type': type, 'label': label, 'xp': xp, 'ts': ts.toIso8601String(),
  };

  factory CompletedAction.fromJson(Map<String, dynamic> j) => CompletedAction(
    type: j['type'] as String? ?? '',
    label: j['label'] as String? ?? '',
    xp: j['xp'] as int? ?? 0,
    ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Artist identity — persisted locally, injected into every AI prompt.
class ArtistProfile {
  String name;
  String genre;
  String mood;
  List<String> references;
  List<String> goals;
  String styleDescription;
  String goal;
  int xp;
  int sessionsCount;
  List<CompletedAction> completedActions;
  DateTime createdAt;

  ArtistProfile({
    this.name = '',
    this.genre = '',
    this.mood = '',
    this.references = const [],
    this.goals = const [],
    this.styleDescription = '',
    this.goal = '',
    this.xp = 0,
    this.sessionsCount = 0,
    this.completedActions = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isEmpty => name.isEmpty && genre.isEmpty;

  /// Artist level based on XP.
  ArtistLevel get level {
    if (xp >= 250) return ArtistLevel.artist;
    if (xp >= 120) return ArtistLevel.breakthrough;
    if (xp >= 50) return ArtistLevel.growing;
    return ArtistLevel.beginner;
  }

  /// XP needed for current level range.
  int get _levelFloor => switch (level) {
    ArtistLevel.beginner => 0,
    ArtistLevel.growing => 50,
    ArtistLevel.breakthrough => 120,
    ArtistLevel.artist => 250,
  };

  int get _levelCeiling => switch (level) {
    ArtistLevel.beginner => 50,
    ArtistLevel.growing => 120,
    ArtistLevel.breakthrough => 250,
    ArtistLevel.artist => 250,
  };

  /// Progress within current level (0.0 – 1.0).
  double get levelProgress {
    if (level == ArtistLevel.artist) return 1.0;
    final range = _levelCeiling - _levelFloor;
    return ((xp - _levelFloor) / range).clamp(0.0, 1.0);
  }

  /// Next level or null if max.
  ArtistLevel? get nextLevel {
    final idx = ArtistLevel.values.indexOf(level);
    return idx < ArtistLevel.values.length - 1 ? ArtistLevel.values[idx + 1] : null;
  }

  /// Actions completed today.
  List<CompletedAction> get todayActions {
    final now = DateTime.now();
    return completedActions.where((a) =>
      a.ts.year == now.year && a.ts.month == now.month && a.ts.day == now.day,
    ).toList();
  }

  /// XP earned today.
  int get todayXp => todayActions.fold(0, (sum, a) => sum + a.xp);

  /// Which character IDs the artist has used.
  Set<String> get usedCharacters =>
      completedActions.map((a) => a.type).toSet();

  /// AI recommendation — next step.
  String getNextStep() {
    final used = usedCharacters;
    if (!used.contains('track')) return 'Создай концепцию трека с Продюсером';
    if (!used.contains('lyrics')) return 'Напиши текст с Автором';
    if (!used.contains('cover')) return 'Сделай обложку с Визуалом';
    if (!used.contains('video')) return 'Создай Reels-контент с SMM';
    // All done — suggest pipeline
    if (!used.contains('pipeline')) return 'Пройди полный pipeline от идеи до контента';
    // Repeat cycle
    return 'Создай новый трек — развивай свой стиль';
  }

  /// Add XP from a character action.
  void addXp(XpAction action) {
    xp += action.xp;
    completedActions = [
      ...completedActions,
      CompletedAction(type: action.name, label: action.label, xp: action.xp, ts: DateTime.now()),
    ];
  }

  /// Build context block for AI system prompts.
  String toAiContext() {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add('Артист: $name');
    if (genre.isNotEmpty) parts.add('Жанр: $genre');
    if (mood.isNotEmpty) parts.add('Настроение: $mood');
    if (references.isNotEmpty) parts.add('Референсы: ${references.join(", ")}');
    if (goals.isNotEmpty) parts.add('Цели: ${goals.join(", ")}');
    if (styleDescription.isNotEmpty) parts.add('Стиль: $styleDescription');
    if (goal.isNotEmpty) parts.add('Текущая цель: $goal');
    parts.add('Уровень: ${level.label} ($xp XP)');
    return parts.join('\n');
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'genre': genre,
    'mood': mood,
    'references': references,
    'goals': goals,
    'styleDescription': styleDescription,
    'goal': goal,
    'xp': xp,
    'sessionsCount': sessionsCount,
    'completedActions': completedActions.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory ArtistProfile.fromJson(Map<String, dynamic> j) => ArtistProfile(
    name: j['name'] as String? ?? '',
    genre: j['genre'] as String? ?? '',
    mood: j['mood'] as String? ?? '',
    references: (j['references'] as List?)?.cast<String>() ?? [],
    goals: (j['goals'] as List?)?.cast<String>() ?? [],
    styleDescription: j['styleDescription'] as String? ?? '',
    goal: j['goal'] as String? ?? '',
    xp: j['xp'] as int? ?? 0,
    sessionsCount: j['sessionsCount'] as int? ?? 0,
    completedActions: (j['completedActions'] as List?)
        ?.map((e) => CompletedAction.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  String encode() => jsonEncode(toJson());
  static ArtistProfile decode(String s) => ArtistProfile.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

enum ArtistLevel {
  beginner('Новичок', '🌱', 0),
  growing('Развивается', '🔥', 50),
  breakthrough('Прорыв', '⚡', 120),
  artist('Артист', '👑', 250);

  final String label;
  final String emoji;
  final int minXp;
  const ArtistLevel(this.label, this.emoji, this.minXp);
}
