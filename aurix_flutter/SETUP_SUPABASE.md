# Aurix + Supabase — настройка и проверка

## Что сделано

### 1. Supabase init
- Зависимости: `supabase_flutter`, `supabase`, `file_picker`, `uuid`, `path`, `mime`, `archive`, `url_launcher`
- `lib/core/supabase_client.dart` — инициализация, `supabase` instance
- Ключи через `--dart-define` (по умолчанию в `AppConfig`)

### 2. Модели
- `ReleaseModel`: `artist` добавлен
- `TrackModel`: `audioPath`, `audioUrl` (fallback на `path`/`file_url`)

### 3. Репозитории
- `ReleaseRepository`: `artist` в create/update
- `FileRepository`: `uploadCover`, `uploadCoverBytes`, `uploadTrack`, `uploadTrackBytes`
- `TrackRepository`: add/delete track

### 4. Загрузка обложки
- Клик по зоне «Обложка» → file picker (png/jpg/jpeg, до 10 MB)
- Если релиза нет — создаётся черновик
- Путь: `covers/{userId}/{releaseId}/{fileName}`
- Превью после загрузки, SnackBar «Обложка загружена»

### 5. Добавление треков
- Кнопка «Добавить трек» → picker (mp3/wav/flac, до 200 MB)
- Без релиза: «Сначала заполните Основное и нажмите Далее»
- Название берётся из имени файла без расширения
- Путь: `tracks/{userId}/{releaseId}/{trackId}.{ext}`

### 6. Пошаговый мастер (RU)
- Далее/Назад, Добавить трек, Сохранить черновик, Отправить на модерацию
- Создание draft при переходе с шага 1 на шаг 2

### 7. Болванки убраны
- Главная: данные из Supabase
- Финансы: «Пока нет данных. Здесь появятся начисления после релизов.»

### 8. Поиск
- Фильтр по `title`, `artist`, `releaseType`
- Выпадающий список, клик — переход в карточку релиза

### 9. Навигация
- `HitTestBehavior.opaque` для кликабельности пунктов меню

### 10. Admin panel
- Админ: список email в `lib/core/admin_config.dart` или роль в Settings
- Скачать метаданные (JSON), Обложка (url_launcher), Треки (диалог со ссылками)

---

## Миграции (Supabase SQL Editor)

```sql
-- 005_fix_releases_cover_columns
alter table public.releases add column if not exists cover_url text;
alter table public.releases add column if not exists cover_path text;

-- 006_releases_artist
alter table public.releases add column if not exists artist text;
```

Плюс 003 (tracks) и 004 (audio_path, audio_url), если ещё не выполнены.

---

## Запуск

```bash
cd aurix_flutter

# Web
flutter run -d chrome --dart-define=SUPABASE_URL=https://ntnhxqvauvjqvplitbxw.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_fkxVnE-EXF8lZMujbTW5LA_XQf6cOwX

# macOS
flutter run -d macos --dart-define=SUPABASE_URL=https://ntnhxqvauvjqvplitbxw.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_fkxVnE-EXF8lZMujbTW5LA_XQf6cOwX
```

---

## Проверка

1. Войти (email из Supabase Auth)
2. Загрузить релиз: Основное → заполнить, загрузить обложку → Далее
3. Треки → Добавить трек → mp3/wav
4. Площадки и отправка → Сохранить черновик / Отправить на модерацию
5. Админ: добавить email в `admin_config.dart` или включить Admin в Settings → Управление → Скачать метаданные, Обложка, Треки
