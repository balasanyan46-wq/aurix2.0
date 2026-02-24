import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/config/app_config.dart';
import 'package:aurix_flutter/data/models/tool_result_model.dart';

class ToolService {
  static const _functionMap = {
    'growth-plan': 'release-growth-plan',
    'budget-plan': 'release-budget-plan',
    'release-packaging': 'release-packaging',
    'content-plan-14': 'content-plan-14',
    'playlist-pitch-pack': 'playlist-pitch-pack',
  };

  Future<ToolResultModel?> getSaved(String releaseId, String toolKey) async {
    try {
      final uid = supabase.auth.currentUser?.id;
      debugPrint('[ToolService] getSaved($toolKey) uid=$uid releaseId=$releaseId');
      if (uid == null) return null;
      final res = await supabase
          .from('release_tools')
          .select()
          .eq('release_id', releaseId)
          .eq('user_id', uid)
          .eq('tool_key', toolKey)
          .maybeSingle();
      debugPrint('[ToolService] getSaved($toolKey) result=${res != null ? "found" : "null"}');
      if (res == null) return null;
      return ToolResultModel.fromJson(res);
    } catch (e) {
      debugPrint('[ToolService] getSaved($toolKey) error: $e');
      return null;
    }
  }

  Future<({bool ok, bool isDemo, Map<String, dynamic> data, String? error})>
      generate(String releaseId, String toolKey, Map<String, dynamic> inputs) async {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        debugPrint('[ToolService] generate($toolKey): no token');
        return (ok: false, isDemo: false, data: <String, dynamic>{}, error: 'Not authenticated');
      }

      final fnName = _functionMap[toolKey] ?? toolKey;
      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/$fnName');
      debugPrint('[ToolService] generate($toolKey) POST $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'apikey': AppConfig.supabaseAnonKey,
        },
        body: jsonEncode({'releaseId': releaseId, 'inputs': inputs}),
      );

      debugPrint('[ToolService] generate($toolKey) status=${response.statusCode}');
      debugPrint('[ToolService] generate($toolKey) body=${response.body.length > 500 ? response.body.substring(0, 500) : response.body}');

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
    } catch (e, st) {
      debugPrint('[ToolService] generate($toolKey) error: $e');
      debugPrint('[ToolService] stackTrace: $st');
      return (ok: false, isDemo: false, data: <String, dynamic>{}, error: e.toString());
    }
  }
}
