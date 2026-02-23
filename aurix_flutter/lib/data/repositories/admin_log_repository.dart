import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';

class AdminLogRepository {
  Future<void> log({
    required String adminId,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic> details = const {},
  }) async {
    await supabase.from('admin_logs').insert({
      'admin_id': adminId,
      'action': action,
      'target_type': targetType,
      'target_id': targetId,
      'details': details,
    });
  }

  Future<List<AdminLogModel>> getLogs({
    int limit = 50,
    int offset = 0,
    String? actionFilter,
  }) async {
    var query = supabase
        .from('admin_logs')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (actionFilter != null && actionFilter.isNotEmpty) {
      query = supabase
          .from('admin_logs')
          .select()
          .eq('action', actionFilter)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
    }

    final res = await query;
    return (res as List)
        .map((e) => AdminLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getCount() async {
    final res = await supabase.from('admin_logs').select('id').count();
    return res.count;
  }
}
