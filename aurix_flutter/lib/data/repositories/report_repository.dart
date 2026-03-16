import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';

class ReportRepository {
  bool _isMissingScopeColumn(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('column') &&
        (msg.contains('user_id') || msg.contains('release_id')) &&
        msg.contains('does not exist');
  }

  Future<List<ReportModel>> getReports() async {
    final res = await ApiClient.get('/reports', query: {'order': 'created_at.desc'});
    final list = res.data as List;
    return list.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReportModel?> getReport(String id) async {
    try {
      final res = await ApiClient.get('/reports/$id');
      final body = res.data as Map<String, dynamic>;
      return ReportModel.fromJson(body);
    } catch (_) {
      return null;
    }
  }

  Future<ReportModel> createReport({
    required DateTime periodStart,
    required DateTime periodEnd,
    String distributor = 'zvonko',
    String? fileName,
    String? fileUrl,
    String? createdBy,
    String? userId,
    String? releaseId,
    String? importHash,
  }) async {
    final payload = <String, dynamic>{
      'period_start': periodStart.toIso8601String().split('T').first,
      'period_end': periodEnd.toIso8601String().split('T').first,
      'distributor': distributor,
      'status': 'uploaded',
    };
    if (fileName != null) payload['file_name'] = fileName;
    if (fileUrl != null) payload['file_url'] = fileUrl;
    if (createdBy != null) payload['created_by'] = createdBy;
    if (userId != null && userId.isNotEmpty) payload['user_id'] = userId;
    if (releaseId != null && releaseId.isNotEmpty) payload['release_id'] = releaseId;
    if (importHash != null && importHash.isNotEmpty) payload['import_hash'] = importHash;
    try {
      final res = await ApiClient.post('/reports', data: payload);
      final body = res.data as Map<String, dynamic>;
      return ReportModel.fromJson(body);
    } catch (e) {
      final txt = e.toString();
      if (_isMissingScopeColumn(e)) {
        final fallback = Map<String, dynamic>.from(payload)
          ..remove('user_id')
          ..remove('release_id');
        final fbRes = await ApiClient.post('/reports', data: fallback);
        final fbBody = fbRes.data as Map<String, dynamic>;
        return ReportModel.fromJson(fbBody);
      }
      if (importHash != null &&
          importHash.isNotEmpty &&
          (txt.contains('23505') || txt.toLowerCase().contains('import_hash'))) {
        try {
          final existing = await ApiClient.get('/reports', query: {'import_hash': importHash});
          final list = existing.data as List;
          if (list.isNotEmpty) return ReportModel.fromJson(list.first as Map<String, dynamic>);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> updateReportStatus(String id, String status) async {
    await ApiClient.put('/reports/$id', data: {'status': status});
  }

  Future<void> addReportRows(
    String reportId,
    List<Map<String, dynamic>> rows,
    {String? userId, String? releaseId}
  ) async {
    if (rows.isEmpty) return;
    final payloads = rows.map((r) {
      final payload = <String, dynamic>{
        'report_id': reportId,
        'report_date': r['report_date'],
        'track_title': r['track_title'],
        'isrc': r['isrc'],
        'platform': r['platform'],
        'country': r['country'],
        'streams': r['streams'] ?? 0,
        'revenue': r['revenue'] ?? 0,
        'currency': r['currency'] ?? 'USD',
        'raw_row_json': r['raw_row_json'],
      };
      if (userId != null && userId.isNotEmpty) payload['user_id'] = userId;
      if (releaseId != null && releaseId.isNotEmpty) payload['release_id'] = releaseId;
      return payload;
    }).toList();
    try {
      await ApiClient.post('/report-rows/batch', data: payloads);
    } catch (e) {
      if (_isMissingScopeColumn(e)) {
        final fallback = payloads
            .map((p) => Map<String, dynamic>.from(p)
              ..remove('user_id')
              ..remove('release_id'))
            .toList();
        await ApiClient.post('/report-rows/batch', data: fallback);
        return;
      }
      rethrow;
    }
  }

  Future<List<ReportRowModel>> getReportRows(String reportId) async {
    final res = await ApiClient.get('/report-rows', query: {'report_id': reportId, 'order': 'created_at.asc'});
    final list = res.data as List;
    return list.map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Returns report rows for tracks owned by the given user.
  Future<List<ReportRowModel>> getRowsByUser(String userId) async {
    try {
      final res = await ApiClient.get('/report-rows', query: {
        'user_id': userId,
        'order': 'created_at.desc',
        'limit': '5000',
      });
      final list = res.data as List;
      return list.map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (_isMissingScopeColumn(e)) {
        final fallback = await ApiClient.get('/report-rows', query: {
          'order': 'created_at.desc',
          'limit': '5000',
        });
        final list = fallback.data as List;
        return list.map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
      }
      rethrow;
    }
  }

  Future<List<ReportRowModel>> getRowsByUserAndRelease({
    required String userId,
    required String releaseId,
  }) async {
    try {
      final res = await ApiClient.get('/report-rows', query: {
        'user_id': userId,
        'release_id': releaseId,
        'order': 'created_at.desc',
        'limit': '5000',
      });
      final list = res.data as List;
      return list.map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (_isMissingScopeColumn(e)) {
        return [];
      }
      rethrow;
    }
  }

  Future<void> linkReportRowToTrack(String rowId, String trackId) async {
    await ApiClient.put('/report-rows/$rowId', data: {'track_id': trackId});
  }

  Future<List<ReportRowModel>> getAllReportRows() async {
    final res = await ApiClient.get('/report-rows', query: {
      'order': 'created_at.desc',
      'limit': '5000',
    });
    final list = res.data as List;
    return list
        .map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> matchReportRowsByIsrc(String reportId) async {
    final rows = await getReportRows(reportId);
    var matched = 0;
    for (final row in rows) {
      if (row.trackId != null || (row.isrc?.trim().isEmpty ?? true)) continue;
      final isrcNorm = row.isrc!.trim().toUpperCase();
      try {
        final trackRes = await ApiClient.get('/tracks', query: {'isrc': isrcNorm, 'select': 'id'});
        final trackList = trackRes.data as List;
        if (trackList.isNotEmpty) {
          final trackId = (trackList.first as Map<String, dynamic>)['id'] as String?;
          if (trackId != null) {
            await linkReportRowToTrack(row.id, trackId);
            matched++;
          }
        }
      } catch (_) {}
    }
    return matched;
  }

  Future<void> deleteReport(String reportId) async {
    await ApiClient.delete('/report-rows/by-report/$reportId');
    await ApiClient.delete('/reports/$reportId');
  }
}
