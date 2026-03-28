import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/budget_plan_model.dart';

class BudgetPlanService {
  Future<BudgetPlanModel?> getSaved(String releaseId) async {
    try {
      final res = await ApiClient.get('/release-budgets/latest', query: {
        'release_id': releaseId,
      });
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      if (row == null) return null;
      return BudgetPlanModel.fromJson(row);
    } catch (e) {
      debugPrint('[BudgetPlanService] getSaved error: $e');
      return null;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, Map<String, dynamic> inputs) async {
    try {
      final res = await ApiClient.post('/tools/release-budget-plan', data: {
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
      debugPrint('[BudgetPlanService] generate error: $e');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
