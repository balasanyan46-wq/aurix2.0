import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class AiToolResultsRepository {
  Future<String?> getLatestResult({
    required String toolId,
    required String resourceType,
    required String? resourceId,
  }) async {
    try {
      final res = await ApiClient.get('/ai-tool-results/latest', query: {
        'tool_id': toolId,
        'resource_type': resourceType,
        if (resourceId != null) 'resource_id': resourceId,
      });
      final rows = (res.data as List?) ?? const [];
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
    try {
      await ApiClient.post('/ai-tool-results', data: {
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

