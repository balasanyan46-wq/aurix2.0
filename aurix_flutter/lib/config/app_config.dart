/// Application configuration via compile-time defines.
///
/// Run with:
/// flutter run -d macos --dart-define=API_BASE_URL=https://194.67.99.229
class AppConfig {
  AppConfig._();

  /// REST API base URL (NestJS backend).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://194.67.99.229',
  );

  static bool get isConfigured => apiBaseUrl.isNotEmpty;

  /// AI provider: 'openai', 'yandexgpt', 'gigachat', 'polza'
  static const String aiProvider = String.fromEnvironment(
    'AI_PROVIDER',
    defaultValue: 'openai',
  );

  static const String cfBaseUrl = String.fromEnvironment(
    'CF_BASE_URL',
    defaultValue: 'https://wandering-snow-3f00.armtelan1.workers.dev',
  );

  /// Feature-flag for direct Studio AI transport.
  static const bool studioToolsDirectWorker = bool.fromEnvironment(
    'STUDIO_TOOLS_DIRECT_WORKER',
    defaultValue: false,
  );
}
