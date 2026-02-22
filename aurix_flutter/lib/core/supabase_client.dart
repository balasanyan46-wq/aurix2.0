import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Инициализация Supabase. Вызывать в main() до runApp.
Future<void> initSupabase() async {
  if (!AppConfig.isConfigured) {
    if (kDebugMode) {
      debugPrint('[Supabase] Config invalid: url=${AppConfig.supabaseUrl.isEmpty ? "empty" : "ok"}, key=${AppConfig.supabaseAnonKey.isEmpty ? "empty" : "ok"}');
    }
    return;
  }
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  if (kDebugMode) {
    debugPrint('[Supabase] Initialized: url=${AppConfig.supabaseUrl}');
  }
}

SupabaseClient get supabase => Supabase.instance.client;
