import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/ai/ai_persistence_guard.dart';

class AiStudioHistoryRepository {
  Future<List<({String role, String content})>> getMessages({int limit = 80}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      logSupabaseRequest(table: 'ai_studio_messages', operation: 'select', userId: userId);
      final rows = await supabase
          .from('ai_studio_messages')
          .select('role, content')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final c = content.trim();
    if (c.isEmpty) return;
    try {
      logSupabaseRequest(table: 'ai_studio_messages', operation: 'insert', userId: userId);
      await supabase.from('ai_studio_messages').insert({
        'user_id': userId,
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
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      logSupabaseRequest(table: 'ai_studio_messages', operation: 'delete', userId: userId);
      await supabase.from('ai_studio_messages').delete().eq('user_id', userId);
    } catch (e) {
      if (isMissingTableError(e, table: 'ai_studio_messages')) {
        throw const AiSchemaMissingException('ai_studio_messages');
      }
      rethrow;
    }
  }
}

