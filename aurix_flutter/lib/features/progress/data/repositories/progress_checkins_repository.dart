import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_checkin.dart';
import 'package:aurix_flutter/features/progress/data/progress_schema_guard.dart';

class ProgressCheckinsRepository {
  Future<List<ProgressCheckin>> getCheckins({
    required DateTime startDay,
    required DateTime endDay,
  }) async {
    final start = _dateOnly(startDay);
    final end = _dateOnly(endDay);
    try {
      final res = await ApiClient.get('/progress-checkins', query: {
        'start_day': _fmtDate(start),
        'end_day': _fmtDate(end),
      });
      final rows = (res.data as List?) ?? const [];
      return rows
          .whereType<Map>()
          .map((e) => ProgressCheckin.fromJson(e.cast<String, dynamic>()))
          .toList();
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
    final payload = <String, dynamic>{
      'habit_id': habitId,
      'day': _fmtDate(_dateOnly(day)),
      'done_count': doneCount,
    };
    if (note != null) payload['note'] = note;
    try {
      final res = await ApiClient.post('/progress-checkins', data: payload);
      final row = (res.data as Map).cast<String, dynamic>();
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
    try {
      await ApiClient.delete(
        '/progress-checkins/$habitId/${_fmtDate(_dateOnly(day))}',
      );
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

