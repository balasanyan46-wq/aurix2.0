import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/features/progress/data/models/progress_habit.dart';

class ProgressHabitsRepository {
  Future<List<ProgressHabit>> getHabits({bool activeOnly = false}) async {
    final res = await ApiClient.get('/progress-habits', query: {
      if (activeOnly) 'is_active': true,
    });
    final rows = asList(res.data);
    return rows
        .whereType<Map>()
        .map((e) => ProgressHabit.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<ProgressHabit> createHabit({
    required String title,
    String category = 'content',
    String targetType = 'daily',
    int targetCount = 1,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final res = await ApiClient.post('/progress-habits', data: {
      'title': title,
      'category': category,
      'target_type': targetType,
      'target_count': targetCount,
      'is_active': isActive,
      'sort_order': sortOrder,
    });
    final row = res.data is Map ? (res.data as Map).cast<String, dynamic>() : <String, dynamic>{};
    return ProgressHabit.fromJson(row);
  }

  Future<void> updateHabit(
    String id, {
    String? title,
    String? category,
    String? targetType,
    int? targetCount,
    bool? isActive,
    int? sortOrder,
  }) async {
    final updates = <String, dynamic>{};
    if (title != null) updates['title'] = title;
    if (category != null) updates['category'] = category;
    if (targetType != null) updates['target_type'] = targetType;
    if (targetCount != null) updates['target_count'] = targetCount;
    if (isActive != null) updates['is_active'] = isActive;
    if (sortOrder != null) updates['sort_order'] = sortOrder;
    if (updates.isEmpty) return;
    await ApiClient.put('/progress-habits/$id', data: updates);
  }

  Future<void> deleteHabit(String id) async {
    await ApiClient.delete('/progress-habits/$id');
  }
}

