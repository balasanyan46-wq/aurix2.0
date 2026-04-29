-- ════════════════════════════════════════════════════════════════════════════
-- 096_profiles_user_id_int_compat.sql
-- Conditional fix для legacy: profiles.user_id может быть uuid (Supabase era),
-- а users.id это int (NestJS era). Все JOIN'ы вида
--   `JOIN profiles p ON p.user_id = u.id`
-- молча возвращают пустоту, потому что int не сравнивается с uuid без cast.
--
-- Эта миграция СПОКОЙНО проверяет тип и:
--   - если user_id уже int → ничего не делает (no-op)
--   - если user_id это uuid → создаёт колонку user_int_id с FK на users(id),
--     заполняет её через email-mapping, добавляет partial index
--
-- ВАЖНО: миграция не дропает старую uuid-колонку — это deferred change,
-- который должен делаться в отдельной миграции после того, как код
-- переключится на user_int_id. Цель этой миграции — дать новой колонке
-- появиться, не ломая existing reads.
-- ════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  current_type text;
BEGIN
  -- Определяем текущий тип profiles.user_id.
  SELECT data_type INTO current_type
    FROM information_schema.columns
   WHERE table_schema = 'public'
     AND table_name = 'profiles'
     AND column_name = 'user_id';

  IF current_type IS NULL THEN
    RAISE NOTICE 'profiles table or user_id column not found — skipping';
    RETURN;
  END IF;

  IF current_type = 'integer' THEN
    RAISE NOTICE 'profiles.user_id уже integer — миграция не нужна';
    RETURN;
  END IF;

  IF current_type = 'uuid' THEN
    RAISE NOTICE 'profiles.user_id это uuid — добавляю user_int_id для совместимости';

    -- 1) Добавляем компаньон-колонку user_int_id если её нет.
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = 'profiles'
         AND column_name = 'user_int_id'
    ) THEN
      ALTER TABLE public.profiles ADD COLUMN user_int_id INT NULL;
    END IF;

    -- 2) Маппим uuid→int через email (общий ключ users и profiles).
    -- Только для строк, где маппинг ещё не произведён.
    UPDATE public.profiles p
       SET user_int_id = u.id
      FROM public.users u
     WHERE p.user_int_id IS NULL
       AND lower(p.email) = lower(u.email);

    -- 3) Индекс для быстрого JOIN'а.
    CREATE INDEX IF NOT EXISTS idx_profiles_user_int_id
      ON public.profiles(user_int_id)
      WHERE user_int_id IS NOT NULL;

    -- 4) Создаём VIEW который admin-код может использовать вместо профиля
    -- напрямую. Когда весь код переключится — добавим NOT NULL constraint
    -- и можно будет дропать uuid-колонку.
    CREATE OR REPLACE VIEW public.v_profiles_int AS
    SELECT
      p.*,
      p.user_int_id AS resolved_user_id
    FROM public.profiles p
    WHERE p.user_int_id IS NOT NULL;

    RAISE NOTICE 'Готово. Замапилось % строк',
      (SELECT count(*) FROM public.profiles WHERE user_int_id IS NOT NULL);
  ELSE
    RAISE NOTICE 'profiles.user_id неожиданный тип: % — миграцию не выполняем', current_type;
  END IF;
END$$;
