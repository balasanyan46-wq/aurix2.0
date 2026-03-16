import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';

class AdminLogRepository {
  Future<void> log({
    required String adminId,
    required String action,
    required String targetType,
    String? targetId,
    Map<String, dynamic> details = const {},
  }) async {
    try {
      await ApiClient.post('/rpc/admin_log_event', data: {
        'p_action': action,
        'p_target_type': targetType,
        'p_target_id': targetId,
        'p_details': details,
      });
      return;
    } catch (_) {
      // Backward compatibility for environments without RPC.
      await ApiClient.post('/admin-logs', data: {
        'admin_id': adminId,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details,
      });
    }
  }

  Future<List<AdminLogModel>> getLogs({
    int limit = 50,
    int offset = 0,
    String? actionFilter,
  }) async {
    final query = <String, dynamic>{
      'order': 'created_at.desc',
      'limit': '$limit',
      'offset': '$offset',
    };
    if (actionFilter != null && actionFilter.isNotEmpty) {
      query['action'] = actionFilter;
    }

    final res = await ApiClient.get('/admin-logs', query: query);
    final list = res.data as List;
    return list
        .map((e) => AdminLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getCount() async {
    final res = await ApiClient.get('/admin-logs/count');
    final body = res.data;
    if (body is Map) return (body['count'] as num?)?.toInt() ?? 0;
    if (body is int) return body;
    return 0;
  }
}
