class ProgressCheckin {
  final String id;
  final String userId;
  final String habitId;
  final DateTime day; // date-only
  final int doneCount;
  final String? note;
  final DateTime createdAt;

  const ProgressCheckin({
    required this.id,
    required this.userId,
    required this.habitId,
    required this.day,
    required this.doneCount,
    this.note,
    required this.createdAt,
  });

  factory ProgressCheckin.fromJson(Map<String, dynamic> json) {
    return ProgressCheckin(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      habitId: json['habit_id'] as String,
      day: DateTime.parse(json['day'] as String),
      doneCount: (json['done_count'] as num?)?.toInt() ?? 1,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

