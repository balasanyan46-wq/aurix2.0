import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_daily_note.dart';
import 'package:aurix_flutter/features/progress/data/progress_schema_guard.dart';

class ProgressDailyNotesRepository {
  Future<ProgressDailyNote?> getByDay(DateTime day) async {
    final d = _dateOnly(day);
    try {
      final res = await ApiClient.get('/progress-daily-notes', query: {
        'day': _fmtDate(d),
      });
      final row = res.data;
      if (row == null) return null;
      return ProgressDailyNote.fromJson((row as Map).cast<String, dynamic>());
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
    final payload = <String, dynamic>{
      'day': _fmtDate(_dateOnly(day)),
      'mood': mood,
      'win': win,
      'blocker': blocker,
    };
    try {
      final res = await ApiClient.post('/progress-daily-notes', data: payload);
      return ProgressDailyNote.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      if (isMissingTableError(e, table: 'progress_daily_notes')) {
        throw const ProgressSchemaMissingException('progress_daily_notes');
      }
      rethrow;
    }
  }

  Future<void> deleteByDay(DateTime day) async {
    try {
      await ApiClient.delete('/progress-daily-notes/${_fmtDate(_dateOnly(day))}');
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

