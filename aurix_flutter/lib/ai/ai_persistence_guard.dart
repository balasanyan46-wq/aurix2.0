class AiSchemaMissingException implements Exception {
  final String table;
  const AiSchemaMissingException(this.table);

  @override
  String toString() => 'AI schema missing: $table';
}

bool isMissingTableError(Object e, {required String table}) {
  final msg = e.toString().toLowerCase();
  return msg.contains(table.toLowerCase()) &&
      (msg.contains('404') || msg.contains('not found') || msg.contains('missing'));
}

