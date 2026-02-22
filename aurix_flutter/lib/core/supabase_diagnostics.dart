import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

String _maskKey(String key) {
  if (key.length <= 16) return '***';
  return '${key.substring(0, 8)}...${key.substring(key.length - 4)}';
}

/// Логирует перед Supabase запросом.
void logSupabaseRequest({
  required String table,
  required String operation,
  Map<String, dynamic>? payload,
  String? userId,
}) {
  if (!kDebugMode) return;
  final url = AppConfig.supabaseUrl;
  final key = _maskKey(AppConfig.supabaseAnonKey);
  debugPrint('[Supabase] $operation $table | url=$url | key=$key | userId=${userId ?? "null"} | payload=$payload');
}

/// Извлекает понятное сообщение об ошибке из исключения.
String formatSupabaseError(Object e) {
  if (e is PostgrestException) {
    final parts = <String>[e.message];
    if (e.code != null && e.code!.isNotEmpty) parts.add('code=${e.code}');
    if (e.details != null && e.details.toString().isNotEmpty) parts.add('details=${e.details}');
    if (e.hint != null && e.hint!.isNotEmpty) parts.add('hint=${e.hint}');
    return parts.join(' | ');
  }
  if (e is StorageException) {
    return 'Storage: ${e.message} (statusCode=${e.statusCode})';
  }
  if (e is AuthException) {
    return 'Auth: ${e.message}';
  }
  return e.toString();
}
