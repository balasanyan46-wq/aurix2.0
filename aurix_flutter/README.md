# Aurix Flutter

Личный кабинет артиста и загрузка релизов (Web + Desktop). Backend: NestJS REST API.

## Запуск

Base URL backend через `--dart-define`:

```bash
flutter run -d macos --dart-define=API_BASE_URL=http://194.67.99.229:3000
```

Для web:
```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://194.67.99.229:3000
```

Значения по умолчанию уже заданы в `lib/config/app_config.dart` — можно запускать без параметров для локальной разработки.
