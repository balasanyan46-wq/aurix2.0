import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';

class ReportRepository {
  Future<List<ReportModel>> getReports() async {
    logSupabaseRequest(table: 'reports', operation: 'select');
    final res = await supabase
        .from('reports')
        .select()
        .order('created_at', ascending: false);
    return (res as List).map((e) => ReportModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ReportModel?> getReport(String id) async {
    logSupabaseRequest(table: 'reports', operation: 'select', payload: {'id': id});
    final res = await supabase.from('reports').select().eq('id', id).maybeSingle();
    if (res == null) return null;
    return ReportModel.fromJson(res as Map<String, dynamic>);
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
    if (userId != null) payload['user_id'] = userId;
    if (releaseId != null) payload['release_id'] = releaseId;
    logSupabaseRequest(table: 'reports', operation: 'insert', payload: payload);
    final res = await supabase.from('reports').insert(payload).select().single();
    return ReportModel.fromJson(res as Map<String, dynamic>);
  }

  Future<void> updateReportStatus(String id, String status) async {
    await supabase.from('reports').update({'status': status}).eq('id', id);
  }

  Future<void> addReportRows(
    String reportId,
    List<Map<String, dynamic>> rows, {
    String? userId,
    String? releaseId,
  }) async {
    if (rows.isEmpty) return;
    final payloads = rows.map((r) {
      final m = <String, dynamic>{
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
      if (userId != null) m['user_id'] = userId;
      if (releaseId != null) m['release_id'] = releaseId;
      return m;
    }).toList();
    await supabase.from('report_rows').insert(payloads);
  }

  Future<List<ReportRowModel>> getReportRows(String reportId) async {
    final res = await supabase
        .from('report_rows')
        .select()
        .eq('report_id', reportId)
        .order('created_at');
    return (res as List).map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ReportRowModel>> getRowsByUser(String userId) async {
    final res = await supabase
        .from('report_rows')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(5000);
    return (res as List).map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> linkReportRowToTrack(String rowId, String trackId) async {
    await supabase.from('report_rows').update({'track_id': trackId}).eq('id', rowId);
  }

  Future<List<ReportRowModel>> getAllReportRows() async {
    final res = await supabase
        .from('report_rows')
        .select()
        .order('created_at', ascending: false)
        .limit(5000);
    return (res as List)
        .map((e) => ReportRowModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> matchReportRowsByIsrc(String reportId) async {
    final rows = await getReportRows(reportId);
    var matched = 0;
    for (final row in rows) {
      if (row.trackId != null || row.isrc == null || row.isrc!.isEmpty) continue;
      final isrcNorm = row.isrc!.trim().toUpperCase();
      final trackRes = await supabase
          .from('tracks')
          .select('id')
          .eq('isrc', isrcNorm)
          .maybeSingle();
      if (trackRes != null) {
        final trackId = trackRes['id'] as String?;
        if (trackId != null) {
          await linkReportRowToTrack(row.id, trackId);
          matched++;
        }
      }
    }
    return matched;
  }

  Future<void> deleteReport(String reportId) async {
    await supabase.from('report_rows').delete().eq('report_id', reportId);
    await supabase.from('reports').delete().eq('id', reportId);
  }
}
