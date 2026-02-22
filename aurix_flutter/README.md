# Aurix Flutter

Личный кабинет артиста и загрузка релизов (Web + Desktop). Backend: Supabase (Auth + DB + Storage).

## Запуск

Ключи Supabase через `--dart-define`:

```bash
flutter run -d macos --dart-define=SUPABASE_URL=https://ntnhxqvauvjqvplitbxw.supabase.co --dart-define=SUPABASE_ANON_KEY=ваш-anon-key
```

Для web:
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

Значения по умолчанию уже заданы в `lib/config/app_config.dart` — можно запускать без параметров для локальной разработки.
