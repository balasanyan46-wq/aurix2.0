import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/growth_plan_model.dart';

class GrowthPlanService {
  Future<GrowthPlanModel?> getSaved(String releaseId) async {
    try {
      final res = await ApiClient.get('/release-growth-plans/latest', query: {
        'release_id': releaseId,
      });
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      if (row == null) return null;
      return GrowthPlanModel.fromJson(row);
    } catch (e) {
      debugPrint('[GrowthPlanService] getSaved error: $e');
      return null;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, Map<String, dynamic> inputs) async {
    try {
      final res = await ApiClient.post('/tools/release-growth-plan', data: {
        'releaseId': releaseId,
        'inputs': inputs,
      });

      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

      if (res.statusCode == 200 && body['ok'] == true) {
        return (
          ok: true,
          isDemo: body['is_demo'] as bool? ?? false,
          data: body['data'] as Map<String, dynamic>? ?? {},
          error: null,
        );
      }

      final errorMsg = body['error'] as String? ?? 'Unknown error (${res.statusCode})';
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: errorMsg);
    } catch (e) {
      debugPrint('[GrowthPlanService] generate error: $e');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
