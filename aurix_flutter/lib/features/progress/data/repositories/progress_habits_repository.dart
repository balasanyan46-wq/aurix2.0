import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_habit.dart';

class ProgressHabitsRepository {
  Future<List<ProgressHabit>> getHabits({bool activeOnly = false}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final base = supabase.from('progress_habits').select();
    final q = activeOnly ? base.eq('is_active', true) : base;
    final rows = await q.order('sort_order').order('created_at');
    return (rows as List).map((e) => ProgressHabit.fromJson(e)).toList();
  }

  Future<ProgressHabit> createHabit({
    required String title,
    String category = 'content',
    String targetType = 'daily',
    int targetCount = 1,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final row = await supabase
        .from('progress_habits')
        .insert({
          'user_id': userId,
          'title': title,
          'category': category,
          'target_type': targetType,
          'target_count': targetCount,
          'is_active': isActive,
          'sort_order': sortOrder,
        })
        .select()
        .single();
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
    await supabase.from('progress_habits').update(updates).eq('id', id);
  }

  Future<void> deleteHabit(String id) async {
    await supabase.from('progress_habits').delete().eq('id', id);
  }
}

