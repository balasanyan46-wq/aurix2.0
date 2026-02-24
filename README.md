# Aurix — личный кабинет артиста и загрузка релизов

Один код для **iOS**, **Android** и **Web**. Стек: Flutter, Riverpod, go_router, Supabase (Auth, Postgres, Storage, RLS).

## Самый быстрый запуск

```bash
cd aurix_flutter
./scripts/run_macos.sh
```

---

## Пошаговая настройка (с нуля)

### 1. Регистрация в Supabase

1. Открой в браузере: [https://supabase.com](https://supabase.com)
2. Нажми **Start your project** и войди через GitHub или email.
3. После входа попадёшь в панель проектов.

### 2. Создание проекта

1. Нажми **New project**.
2. Выбери организацию (или создай новую).
3. Укажи:
   - **Name** — например `aurix`.
   - **Database Password** — придумай и сохрани пароль (он нужен только для доступа к БД из панели).
   - **Region** — ближайший к тебе.
4. Нажми **Create new project** и подожди 1–2 минуты.

### 3. Где взять URL и anon key

1. В левом меню Supabase выбери **Project Settings** (иконка шестерёнки).
2. Слева открой **API**.
3. Скопируй:
   - **Project URL** (например `https://xxxxx.supabase.co`).
   - **anon public** ключ (длинная строка в блоке **Project API keys**).

### 4. Конфигурация (dart-define)

Приложение читает конфиг через `--dart-define`. Передавай URL и anon key при запуске:

```
flutter run -d macos \
  --dart-define=SUPABASE_URL=https://твой-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=твой-anon-key
```

Файл `.env` **не требуется**. Сборка проходит без него. Без `--dart-define` приложение покажет экран «Config missing» и инструкцию.

### 5. Создание хранилищ (buckets) covers и tracks

1. В Supabase в левом меню открой **Storage**.
2. Нажми **New bucket**.
3. Создай первый bucket:
   - **Name:** `covers`
   - **Public bucket:** выключено (оставь галочку снятой).
   - Нажми **Create bucket**.
4. Снова **New bucket** и создай второй:
   - **Name:** `tracks`
   - **Public bucket:** выключено.
   - **Create bucket**.

(Если захочешь ограничить размер или типы файлов — это можно настроить в настройках каждого bucket.)

### 6. Выполнение SQL (таблицы и политики)

1. В Supabase в левом меню открой **SQL Editor**.
2. Нажми **New query**.
3. Открой файл **supabase/migrations/001_init.sql** из этого репозитория, скопируй весь текст и вставь в окно запроса в Supabase.
4. Нажми **Run** (или Ctrl+Enter). Внизу должно появиться сообщение об успешном выполнении.
5. Открой **supabase/migrations/002_storage_policies.sql**, скопируй весь текст в **новый** запрос в SQL Editor и снова нажми **Run**.

Дальше выполни миграции (каждый файл — в отдельном запросе):
- `supabase/migrations/014_plan_slugs_migration.sql`
- `supabase/migrations/024_profiles_billing_period.sql`
- `supabase/migrations/025_subscriptions_table_and_rls.sql`
- `supabase/migrations/026_lock_profile_subscription_fields.sql`

Если при выполнении **002_storage_policies.sql** появится ошибка про `storage.buckets` (например что такого таблицы нет или нельзя вставлять) — тогда buckets созданы вручную через Storage (шаг 5), и нужно выполнить только **политики для storage.objects**. В таком случае открой 002, удали блок `insert into storage.buckets ...` и выполни оставшуюся часть файла (все `create policy ...`).

### 7. Запуск Flutter-приложения

Нужен установленный Flutter ([flutter.dev](https://flutter.dev)).

1. Открой терминал и перейди в папку приложения:
   ```bash
   cd aurix_flutter
   ```
2. Если в папке **aurix_flutter** нет подпапок **web**, **android**, **ios** — создай платформы одной командой (не затрёт твой код):
   ```bash
   flutter create .
   ```
   Когда спросит про перезапись — выбери «n» (no) для pubspec.yaml и lib, если нужно.
3. Установи зависимости:
   ```bash
   flutter pub get
   ```
4. Запуск в браузере (Web):
   ```bash
   flutter run -d chrome --dart-define=SUPABASE_URL=https://твой-project.supabase.co --dart-define=SUPABASE_ANON_KEY=твой-anon-key
   ```
5. Запуск на macOS:
   ```bash
   flutter run -d macos --dart-define=SUPABASE_URL=https://твой-project.supabase.co --dart-define=SUPABASE_ANON_KEY=твой-anon-key
   ```
6. Запуск на телефоне/эмуляторе:
   - Подключи телефон по USB (с отладкой по USB) или запусти эмулятор.
   -    Выполни:
     ```bash
     flutter run -d <id_устройства> --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
     ```
   Для теста без Supabase запусти `flutter run -d macos` — приложение соберётся и покажет «Config missing».

---

## Что должно получиться

- **Регистрация** по email и паролю, **вход** и **выход**. Сессия сохраняется (после перезапуска приложения пользователь остаётся залогиненным).
- **Профиль**: имя артиста, отображаемое имя, телефон (опционально). Профиль автоматически создаётся при первом входе.
- **Релизы**: список своих релизов, создание релиза (название, тип single/ep/album, дата, жанр, язык, explicit), статус draft → submitted. Экран деталей релиза.
- **Загрузка файлов**: обложка (jpg/png) в bucket `covers`, трек (mp3/wav/flac) в bucket `tracks`. Пути сохраняются в таблицу `files`.
- **Админ**: если в таблице `profiles` у пользователя `role = 'admin'`, он видит раздел «Админ» и список всех релизов, может менять статус (submitted / in_review / approved / rejected) и добавлять заметку (admin_note).

---

## Проверка: «план нельзя менять вручную»

- **Обычный пользователь (не admin)**:
  - Открой `/subscription` и нажми на любой тариф → должно открываться «оплата/checkout», но **план в БД не меняется**.
  - Попробуй из браузера (Supabase client / REST) выполнить `update public.profiles set plan='empire' ...` → запрос должен упасть с ошибкой (trigger блокирует).
  - Попробуй `update public.subscriptions set plan='empire' ...` → запрос должен упасть (RLS deny).

- **Админ**:
  - В админке открой пользователя → «План» → выбери тариф → запрос идёт в Edge Function `admin-subscriptions-assign`, план меняется в `subscriptions` и синхронизируется в `profiles`.

---

## Чек-лист «сделай 1–2–3»

- [ ] **1.** Зарегистрироваться в Supabase и создать проект (New project).
- [ ] **2.** В Project Settings → API скопировать **Project URL** и **anon public** key.
- [ ] **3.** Запускать приложение с `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (см. шаг 4 выше). Файл .env не нужен.
- [ ] **4.** В Supabase → Storage создать два bucket: **covers** и **tracks** (оба не публичные).
- [ ] **5.** В SQL Editor выполнить **001_init.sql**, затем **002_storage_policies.sql** (если 002 ругается на создание buckets — создать buckets вручную и выполнить только политики из 002).
- [ ] **6.** В терминале: `cd aurix_flutter`, при необходимости `flutter create .`, затем `flutter pub get` и `flutter run -d macos` (сборка без .env) или `flutter run -d macos --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` (полный запуск).
- [ ] **7.** В приложении: зарегистрироваться, войти, заполнить профиль, создать релиз и загрузить обложку и трек. Для проверки админки вручную в Supabase в таблице `profiles` выставить своему пользователю `role = 'admin'`.

После этого приложение должно полностью работать: регистрация, вход, личный кабинет, создание релиза, загрузка обложки и трека, а для админа — просмотр всех релизов и смена статуса с заметкой.
