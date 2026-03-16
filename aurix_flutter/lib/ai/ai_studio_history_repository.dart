import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class AiStudioHistoryRepository {
  Future<List<({String role, String content})>> getMessages({int limit = 80}) async {
    try {
      final res = await ApiClient.get('/ai-studio-messages', query: {'limit': limit});
      final rows = (res.data as List?) ?? const [];
      return (rows as List)
          .map((r) => (role: (r['role'] as String?) ?? 'assistant', content: (r['content'] as String?) ?? ''))
          .where((m) => m.content.trim().isNotEmpty)
          .toList();
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }

  Future<void> append({required String role, required String content}) async {
    final c = content.trim();
    if (c.isEmpty) return;
    try {
      await ApiClient.post('/ai-studio-messages', data: {
        'role': role,
        'content': c,
      });
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }

  Future<void> clear() async {
    try {
      await ApiClient.delete('/ai-studio-messages');
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }
}

