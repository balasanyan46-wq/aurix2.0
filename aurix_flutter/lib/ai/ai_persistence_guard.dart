import 'package:supabase_flutter/supabase_flutter.dart';

class AiSchemaMissingException implements Exception {
  final String table;
  const AiSchemaMissingException(this.table);

  @override
  String toString() => 'AI schema missing: $table';
}

bool isMissingTableError(Object e, {required String table}) {
  if (e is! PostgrestException) return false;
  if (e.code != 'PGRST205') return false;
  final msg = e.message.toLowerCase();
  return msg.contains(table.toLowerCase());
}

