import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class AiStudioHistoryRepository {
  Future<List<({String role, String content, Map<String, dynamic>? meta})>> getMessages({int limit = 80, String? generativeType}) async {
    try {
      final query = <String, dynamic>{'limit': limit};
      if (generativeType != null) query['generativeType'] = generativeType;
      final res = await ApiClient.get('/ai-studio-messages', query: query);
      final rows = asList(res.data);
      return rows
          .map((r) {
            final meta = r['meta'];
            return (
              role: (r['role'] as String?) ?? 'assistant',
              content: (r['content'] as String?) ?? '',
              meta: meta is Map<String, dynamic> ? meta : meta is Map ? Map<String, dynamic>.from(meta) : null,
            );
          })
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }

  Future<void> append({required String role, required String content, Map<String, dynamic>? meta}) async {
    final c = content.trim();
    if (c.isEmpty) return;
    try {
      await ApiClient.post('/ai-studio-messages', data: {
        'role': role,
        'content': c,
        if (meta != null) 'meta': meta,
      });
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }

  Future<void> clear({String? generativeType}) async {
    try {
      final path = generativeType != null
          ? '/ai-studio-messages?generativeType=$generativeType'
          : '/ai-studio-messages';
      await ApiClient.delete(path);
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }
}
