import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class AiToolResultsRepository {
  Future<String?> getLatestResult({
    required String toolId,
    required String resourceType,
    required String? resourceId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    try {
      logSupabaseRequest(table: 'ai_tool_results', operation: 'select', userId: userId, payload: {'toolId': toolId, 'resourceId': resourceId});
      var q = supabase
          .from('ai_tool_results')
          .select('result_markdown')
          .eq('user_id', userId)
          .eq('tool_id', toolId)
          .eq('resource_type', resourceType);
      if (resourceId != null) q = q.eq('resource_id', resourceId);
      final rows = (await q.order('created_at', ascending: false).limit(1)) as List;
      if (rows.isEmpty) return null;
      final first = rows.first as Map;
      return (first['result_markdown'] as String?)?.trim();
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_tool_results')) {
        throw const AiSchemaMissingException('ai_tool_results');
      }
      rethrow;
    }
  }

  Future<void> saveRun({
    required String toolId,
    required String resourceType,
    required String? resourceId,
    Map<String, dynamic>? input,
    String? quickPrompt,
    String? resultMarkdown,
    String? errorText,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      logSupabaseRequest(table: 'ai_tool_results', operation: 'insert', userId: userId, payload: {'toolId': toolId, 'resourceId': resourceId});
      await supabase.from('ai_tool_results').insert({
        'user_id': userId,
        'tool_id': toolId,
        'resource_type': resourceType,
        'resource_id': resourceId,
        'input': input,
        'quick_prompt': quickPrompt,
        'result_markdown': resultMarkdown,
        'error_text': errorText,
      });
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_tool_results')) {
        throw const AiSchemaMissingException('ai_tool_results');
      }
      rethrow;
    }
  }
}

