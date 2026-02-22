# Запуск Aurix

```bash
cd aurix_flutter
flutter clean
flutter pub get
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://ntnhxqvauvjqvplitbxw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_fkxVnE-EXF8lZMujbTW5LA_XQf6cOwX
```

Web:
```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://ntnhxqvauvjqvplitbxw.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_fkxVnE-EXF8lZMujbTW5LA_XQf6cOwX
```
