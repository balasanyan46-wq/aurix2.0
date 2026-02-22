/// Конфигурация приложения через compile-time defines.
///
/// Запуск с параметрами:
/// flutter run -d macos --dart-define=SUPABASE_URL=https://xxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxx
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ntnhxqvauvjqvplitbxw.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_fkxVnE-EXF8lZMujbTW5LA_XQf6cOwX',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      supabaseUrl.startsWith('https://') &&
      supabaseUrl.contains('.supabase.co');
}
