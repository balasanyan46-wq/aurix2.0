/// Application configuration via compile-time defines.
///
/// Run with:
/// flutter run -d macos --dart-define=API_BASE_URL=https://aurixmusic.ru
class AppConfig {
  AppConfig._();

  /// REST API base URL (NestJS backend).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://aurixmusic.ru',
  );

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  /// AI provider: 'openai', 'yandexgpt', 'gigachat', 'polza'
  static const String aiProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'openai',
  );
}
