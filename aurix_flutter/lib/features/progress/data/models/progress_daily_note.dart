class ProgressDailyNote {
  final String id;
  final String userId;
  final DateTime day; // date-only
  final int? mood; // 1..5
  final String? blocker;
  final String? win;
  final DateTime createdAt;

  const ProgressDailyNote({
    required this.id,
    required this.userId,
    required this.day,
    this.mood,
    this.blocker,
    this.win,
    required this.createdAt,
  });

  factory ProgressDailyNote.fromJson(Map<String, dynamic> json) {
    return ProgressDailyNote(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      day: DateTime.parse(json['day'] as String),
      mood: (json['mood'] as num?)?.toInt(),
      blocker: json['blocker'] as String?,
      win: json['win'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

