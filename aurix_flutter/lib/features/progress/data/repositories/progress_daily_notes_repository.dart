import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_daily_note.dart';
import 'package:aurix_flutter/features/progress/data/progress_schema_guard.dart';

class ProgressDailyNotesRepository {
  Future<ProgressDailyNote?> getByDay(DateTime day) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final d = _dateOnly(day);
    try {
      final row = await supabase
          .from('progress_daily_notes')
          .select()
          .eq('user_id', userId)
          .eq('day', _fmtDate(d))
          .maybeSingle();
      if (row == null) return null;
      return ProgressDailyNote.fromJson(row);
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_daily_notes')) {
        throw const ProgressSchemaMissingException('progress_daily_notes');
      }
      rethrow;
    }
  }

  Future<ProgressDailyNote> upsert({
    required DateTime day,
    int? mood,
    String? win,
    String? blocker,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    final payload = <String, dynamic>{
      'user_id': userId,
      'day': _fmtDate(_dateOnly(day)),
      'mood': mood,
      'win': win,
      'blocker': blocker,
    };
    try {
      final row = await supabase
          .from('progress_daily_notes')
          .upsert(payload, onConflict: 'user_id,day')
          .select()
          .single();
      return ProgressDailyNote.fromJson(row);
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_daily_notes')) {
        throw const ProgressSchemaMissingException('progress_daily_notes');
      }
      rethrow;
    }
  }

  Future<void> deleteByDay(DateTime day) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');
    try {
      await supabase
          .from('progress_daily_notes')
          .delete()
          .eq('user_id', userId)
          .eq('day', _fmtDate(_dateOnly(day)));
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_daily_notes')) {
        throw const ProgressSchemaMissingException('progress_daily_notes');
      }
      rethrow;
    }
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

