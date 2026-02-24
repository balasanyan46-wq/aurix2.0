import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/data/models/budget_plan_model.dart';

class BudgetPlanService {
  Future<BudgetPlanModel?> getSaved(String releaseId) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid == null) return null;
      final res = await supabase
          .from('release_budgets')
          .select()
          .eq('release_id', releaseId)
          .eq('user_id', uid)
          .maybeSingle();
      if (res == null) return null;
      return BudgetPlanModel.fromJson(res);
    } catch (e) {
      debugPrint('[BudgetPlanService] getSaved error: $e');
      return null;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, Map<String, dynamic> inputs) async {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) return (ok: false, isDemo: false, data: <String, dynamic>{}, error: 'Not authenticated');

      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/release-budget-plan');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'releaseId': releaseId, 'inputs': inputs}),
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && body['ok'] == true) {
        return (
          ok: true,
          isDemo: body['is_demo'] as bool? ?? false,
          data: body['data'] as Map<String, dynamic>? ?? {},
          error: null,
        );
      }

      final errorMsg = body['error'] as String? ?? 'Unknown error (${response.statusCode})';
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: errorMsg);
    } catch (e) {
      debugPrint('[BudgetPlanService] generate error: $e');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
