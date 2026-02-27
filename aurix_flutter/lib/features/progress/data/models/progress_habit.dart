class ProgressHabit {
  final String id;
  final String userId;
  final String title;
  final String category; // content/music/admin/growth/health
  final String targetType; // daily/weekly
  final int targetCount;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const ProgressHabit({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.targetType,
    required this.targetCount,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });

  factory ProgressHabit.fromJson(Map<String, dynamic> json) {
    return ProgressHabit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: (json['title'] as String?) ?? '',
      category: (json['category'] as String?) ?? 'content',
      targetType: (json['target_type'] as String?) ?? 'daily',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 1,
      isActive: (json['is_active'] as bool?) ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

