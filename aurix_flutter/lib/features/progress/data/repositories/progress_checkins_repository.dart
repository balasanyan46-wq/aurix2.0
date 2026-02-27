import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_checkin.dart';
import 'package:aurix_flutter/features/progress/data/progress_schema_guard.dart';

class ProgressCheckinsRepository {
  Future<List<ProgressCheckin>> getCheckins({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    final start = _dateOnly(startDay);
    final end = _dateOnly(endDay);
    try {
      final rows = await supabase
          .from('progress_checkins')
          .select()
          .gte('day', _fmtDate(start))
          .lte('day', _fmtDate(end))
          .order('day');
      return (rows as List).map((e) => ProgressCheckin.fromJson(e)).toList();
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_checkins')) {
        throw const ProgressSchemaMissingException('progress_checkins');
      }
      rethrow;
    }
  }

  /// Upserts a check-in for the given habit/day.
  /// Returns the saved row.
  Future<ProgressCheckin> upsert({
    required String habitId,
    required DateTime day,
    required int doneCount,
    String? note,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final payload = <String, dynamic>{
      'user_id': userId,
      'habit_id': habitId,
      'day': _fmtDate(_dateOnly(day)),
      'done_count': doneCount,
    };
    if (note != null) payload['note'] = note;
    try {
      final row = await supabase
          .from('progress_checkins')
          .upsert(payload, onConflict: 'user_id,habit_id,day')
          .select()
          .single();
      return ProgressCheckin.fromJson(row);
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_checkins')) {
        throw const ProgressSchemaMissingException('progress_checkins');
      }
      rethrow;
    }
  }

  Future<void> delete({
    required String habitId,
    required DateTime day,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    try {
      await supabase
          .from('progress_checkins')
          .delete()
          .eq('user_id', userId)
          .eq('habit_id', habitId)
          .eq('day', _fmtDate(_dateOnly(day)));
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_checkins')) {
        throw const ProgressSchemaMissingException('progress_checkins');
      }
      rethrow;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

