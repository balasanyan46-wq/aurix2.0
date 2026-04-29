-- ════════════════════════════════════════════════════════════════════════════
-- 088_extended_admin_roles.sql
-- Расширенная ролевая модель + матрица разрешений + audit-friendly schema.
--
-- Зачем: до этой миграции было только role='admin', что давало полные права
-- любому админу (включая возможность повысить себя/другого до admin).
-- Теперь: 8 ролей с иерархией. Только super_admin может менять роли.
-- ════════════════════════════════════════════════════════════════════════════

-- 1) Расширяем enum ролей в users (мягко: дроп старого constraint, добавляем новый)
DO $$
BEGIN
  -- Дроп check constraint, если он существует
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'users_role_check' AND conrelid = 'public.users'::regclass
  ) THEN
    ALTER TABLE public.users DROP CONSTRAINT users_role_check;
  END IF;
EXCEPTION WHEN undefined_table THEN
  -- Таблица users отсутствует (Supabase-only deploy). Пропускаем.
  NULL;
END$$;

DO $$
BEGIN
  ALTER TABLE public.users
    ADD CONSTRAINT users_role_check CHECK (role IN (
      'user',
      'artist',
      'support',
      'moderator',
      'analyst',
      'finance_admin',
      'admin',
      'super_admin'
    ));
EXCEPTION WHEN undefined_table THEN NULL; END$$;

-- 2) Аналогично для profiles.role (Supabase mirror)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'profiles_role_check' AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles DROP CONSTRAINT profiles_role_check;
  END IF;
EXCEPTION WHEN undefined_table THEN NULL; END$$;

DO $$
BEGIN
  ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check CHECK (role IN (
      'user',
      'artist',
      'support',
      'moderator',
      'analyst',
      'finance_admin',
      'admin',
      'super_admin'
    ));
EXCEPTION WHEN undefined_table THEN NULL; END$$;

-- 3) Permission matrix — какие действия доступны какой роли.
-- Используется RolesGuard для тонкой проверки. super_admin имеет полный доступ
-- (проверяется в коде, не через явный seed — иначе seed раздуется).
CREATE TABLE IF NOT EXISTS public.role_permissions (
  role        text NOT NULL,
  permission  text NOT NULL,
  description text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (role, permission)
);

-- Идемпотентный seed — выполнение миграции дважды не сломает данные.
INSERT INTO public.role_permissions (role, permission, description) VALUES
  -- finance_admin: финансы и платежи
  ('finance_admin', 'admin.dashboard.read',     'Просмотр админ-дашборда'),
  ('finance_admin', 'admin.users.read',         'Просмотр пользователей'),
  ('finance_admin', 'admin.payments.read',      'Просмотр платежей'),
  ('finance_admin', 'admin.payments.refund',    'Возврат платежей'),
  ('finance_admin', 'admin.revenue.read',       'Просмотр revenue-метрик'),
  ('finance_admin', 'admin.logs.read',          'Просмотр логов'),

  -- support: поддержка пользователей
  ('support', 'admin.dashboard.read',           'Просмотр дашборда'),
  ('support', 'admin.users.read',               'Просмотр пользователей'),
  ('support', 'admin.users.notify',             'Отправка уведомлений'),
  ('support', 'admin.users.create_ticket',      'Создание тикетов'),
  ('support', 'admin.users.reset_limits',       'Сброс дневных лимитов'),
  ('support', 'admin.tickets.manage',           'Управление тикетами'),
  ('support', 'admin.action_center.read',       'Action Center'),

  -- moderator: модерация контента
  ('moderator', 'admin.dashboard.read',         'Просмотр дашборда'),
  ('moderator', 'admin.users.read',             'Просмотр пользователей'),
  ('moderator', 'admin.users.block',            'Блокировка пользователей'),
  ('moderator', 'admin.releases.review',        'Модерация релизов'),
  ('moderator', 'admin.content.moderate',       'Модерация контента'),
  ('moderator', 'admin.action_center.read',     'Action Center'),

  -- analyst: read-only аналитика
  ('analyst', 'admin.dashboard.read',           'Просмотр дашборда'),
  ('analyst', 'admin.users.read',               'Просмотр пользователей'),
  ('analyst', 'admin.analytics.read',           'Просмотр аналитики'),
  ('analyst', 'admin.revenue.read',             'Просмотр revenue'),
  ('analyst', 'admin.leads.read',               'Просмотр lead score'),
  ('analyst', 'admin.action_center.read',       'Action Center (read-only)'),

  -- admin: всё, кроме изменения ролей и super-admin операций
  ('admin', 'admin.dashboard.read',             'Просмотр дашборда'),
  ('admin', 'admin.users.read',                 'Просмотр пользователей'),
  ('admin', 'admin.users.edit',                 'Редактирование (без role)'),
  ('admin', 'admin.users.block',                'Блокировка'),
  ('admin', 'admin.users.notify',               'Уведомления'),
  ('admin', 'admin.users.create_ticket',        'Тикеты'),
  ('admin', 'admin.users.reset_limits',         'Сброс лимитов'),
  ('admin', 'admin.users.kill_sessions',        'Завершение сессий'),
  ('admin', 'admin.users.bonus',                'Выдача бонусов'),
  ('admin', 'admin.payments.read',              'Просмотр платежей'),
  ('admin', 'admin.payments.refund',            'Возврат платежей'),
  ('admin', 'admin.releases.review',            'Модерация релизов'),
  ('admin', 'admin.ai_actions.suggest',         'AI-операторы (suggest)'),
  ('admin', 'admin.ai_actions.preview',         'AI-операторы (preview)'),
  ('admin', 'admin.ai_actions.apply',           'AI-операторы (apply)'),
  ('admin', 'admin.action_center.read',         'Action Center'),
  ('admin', 'admin.action_center.act',          'Действия из Action Center'),
  ('admin', 'admin.leads.read',                 'Lead score'),
  ('admin', 'admin.leads.recalculate',          'Пересчёт scoring'),
  ('admin', 'admin.logs.read',                  'Просмотр логов')
  -- super_admin: НЕ перечисляем — обрабатывается в коде как «всё разрешено»
ON CONFLICT (role, permission) DO NOTHING;

-- 4) Расширяем admin_logs: для опасных действий обязательны reason и confirmed.
-- Не делаем NOT NULL на уровне БД (старые записи без reason остаются), но
-- добавляем индекс, чтобы быстро находить опасные действия по reason.
CREATE INDEX IF NOT EXISTS idx_admin_logs_action_created
  ON public.admin_logs(action, created_at DESC);

-- 5) Audit на смену роли — отдельная таблица, чтобы не теряться в общем логе.
CREATE TABLE IF NOT EXISTS public.role_change_log (
  id            bigserial PRIMARY KEY,
  changed_by    int NOT NULL,           -- кто сделал
  target_user   int NOT NULL,           -- кому
  old_role      text,
  new_role      text NOT NULL,
  reason        text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_role_change_log_target
  ON public.role_change_log(target_user, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_role_change_log_changed_by
  ON public.role_change_log(changed_by, created_at DESC);
