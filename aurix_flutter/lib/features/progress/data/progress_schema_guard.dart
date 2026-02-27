import 'package:postgrest/postgrest.dart';

class ProgressSchemaMissingException implements Exception {
  final String table;
  const ProgressSchemaMissingException(this.table);

  @override
  String toString() => 'Progress schema missing: $table';
}

bool isMissingTableError(Object e, {required String table}) {
  if (e is! PostgrestException) return false;
  if (e.code != 'PGRST205') return false;
  final msg = (e.message).toLowerCase();
  return msg.contains(table.toLowerCase());
}

