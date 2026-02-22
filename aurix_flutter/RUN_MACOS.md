# Запуск AURIX на macOS

## Требования

- Flutter 3.x+
- Xcode (для сборки macOS)

## Конфигурация Supabase

Запуск с параметрами:

```bash
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Сеть (App Sandbox)

Для работы с Supabase приложение должно иметь доступ в интернет. В проекте уже настроены entitlements:

- `com.apple.security.network.client` — исходящие подключения (HTTP/HTTPS к Supabase)
- `com.apple.security.network.server` — для локальных сервисов (если нужны)

Файлы: `macos/Runner/DebugProfile.entitlements`, `macos/Runner/Release.entitlements`.

Если сеть не работает:

1. Откройте `macos/Runner/DebugProfile.entitlements`
2. Убедитесь, что есть `<key>com.apple.security.network.client</key><true/>`
3. Выполните `flutter clean && flutter pub get`
4. Пересоберите: `flutter run -d macos`

## Быстрый запуск

```bash
cd aurix_flutter
flutter pub get
flutter run -d macos --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
