# Изменения: Supabase backend, загрузка, админ, UX

## Что сделано

### 1. Supabase init
- `lib/core/supabase_client.dart` — `initSupabase()` через `AppConfig` (url, anonKey)
- Ключи через `--dart-define=SUPABASE_URL` и `SUPABASE_ANON_KEY` (см. README)
- Добавлены зависимости: path, mime, archive, url_launcher

### 2. cover_url и cover_path
- В `ReleaseModel` добавлено `coverPath`
- В `ReleaseRepository` — `coverPath` в create/update
- Миграция `004_releases_cover_path_tracks_audio.sql`: добавлена колонка `cover_path` в releases

### 3. Загрузка обложки (bucket covers)
- Путь: `covers/{userId}/{releaseId}/cover.{ext}`
- Если релиза ещё нет — создаётся черновик
- Лимит 10 МБ, форматы png/jpg/jpeg
- В БД сохраняются `cover_path` и `cover_url`
- Превью после загрузки

### 4. Загрузка треков (bucket tracks)
- Путь: `tracks/{userId}/{releaseId}/{trackId}.{ext}`
- Лимит 200 МБ, форматы mp3/wav/flac
- В таблицу tracks записываются `audio_path` и `audio_url`
- Кнопка «Далее» неактивна, пока нет хотя бы одного трека
- Удаление трека — из БД и из storage

### 5. UI на русском
- Кнопки «Далее» и «Назад»
- Сообщения об ошибках на русском
- L10nScope по умолчанию `AppLocale.ru`

### 6. Убраны болванки
- Главная: данные из БД (releases от текущего пользователя)
- Финансы: «Пока нет данных» + кнопка «Загрузить отчёт»

### 7. Поиск в шапке
- Поиск по названию и типу релиза
- Выпадающий список с результатами
- Клик — переход в карточку релиза

### 8. Hover и клики
- Убран scale 1.02 на hover (AurixButton), оставлен только scale при нажатии

### 9. Админ: скачивание
- «Скачать метаданные» — JSON с полями релиза и треков
- «Обложка» — открывает cover_url в браузере

### 10. Отправка на модерацию
- Валидация: название, обложка, ≥1 трека
- Обновление `releases.status = 'submitted'`

---

## Миграции (Supabase Dashboard → SQL Editor)

1. `003_cover_url_and_tracks.sql` — cover_url в releases, таблица tracks (path, file_url)
2. `004_releases_cover_path_tracks_audio.sql` — cover_path, audio_path, audio_url

---

## Как проверить

1. Запуск: `flutter run -d macos` или `flutter run -d chrome`
2. Обложка: Шаг «Основное» → клик по зоне обложки → выбор файла
3. Треки: Шаг «Треки» → «Добавить трек» → выбор аудио
4. Поиск: ввод в поле поиска → выбор результата
5. Админ: Settings → роль Admin → вкладка «Управление» → «Скачать метаданные»
