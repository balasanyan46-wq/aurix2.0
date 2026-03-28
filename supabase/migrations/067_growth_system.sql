-- ============================================================
-- 067: Growth & Retention System
-- Goals, Achievements, XP/Levels, Public Profiles
-- ============================================================

-- ── XP & Levels (persistent) ──────────────────────────────
CREATE TABLE IF NOT EXISTS user_xp (
  user_id    INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  xp         INT NOT NULL DEFAULT 0,
  level      INT NOT NULL DEFAULT 1,
  level_name VARCHAR(30) NOT NULL DEFAULT 'Rookie',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- XP log for traceability
CREATE TABLE IF NOT EXISTS xp_log (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount     INT NOT NULL,
  reason     VARCHAR(100) NOT NULL,
  source     VARCHAR(50),  -- 'achievement','goal','daily','action','admin'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_xp_log_user ON xp_log(user_id, created_at DESC);

-- ── Goals ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_goals (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       VARCHAR(200) NOT NULL,
  description TEXT,
  target      INT NOT NULL DEFAULT 1,
  progress    INT NOT NULL DEFAULT 0,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  xp_reward   INT NOT NULL DEFAULT 50,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_goals_user ON user_goals(user_id, is_completed);

-- ── Achievements (catalog) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS achievements (
  id          VARCHAR(50) PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  description VARCHAR(255),
  icon        VARCHAR(50) DEFAULT 'star',
  category    VARCHAR(30) DEFAULT 'general',  -- general, creative, social, milestone
  xp_reward   INT NOT NULL DEFAULT 25,
  sort_order  INT NOT NULL DEFAULT 0
);

-- ── User achievements (unlocked) ───────────────────────────
CREATE TABLE IF NOT EXISTS user_achievements (
  user_id       INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  achievement_id VARCHAR(50) NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
  unlocked_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, achievement_id)
);
CREATE INDEX IF NOT EXISTS idx_user_achievements ON user_achievements(user_id);

-- ── Public profiles ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public_profiles (
  user_id     INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  slug        VARCHAR(60) UNIQUE,
  display_name VARCHAR(100),
  bio         TEXT,
  genre       VARCHAR(50),
  avatar_url  TEXT,
  cover_url   TEXT,
  links       JSONB DEFAULT '{}',  -- { instagram, spotify, tiktok, ... }
  is_public   BOOLEAN NOT NULL DEFAULT false,
  views       INT NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_public_slug ON public_profiles(slug) WHERE slug IS NOT NULL;

-- ── Seed achievements ──────────────────────────────────────
INSERT INTO achievements (id, name, description, icon, category, xp_reward, sort_order) VALUES
  ('first_login',       'Первый вход',           'Зарегистрироваться на платформе',       'login',          'milestone', 10,  1),
  ('first_release',     'Первый релиз',          'Создать первый релиз',                   'album',          'creative',  50,  2),
  ('first_track',       'Первый трек',           'Загрузить первый трек',                  'music_note',     'creative',  30,  3),
  ('first_cover',       'Первая обложка',        'Сгенерировать обложку через AI',         'image',          'creative',  30,  4),
  ('first_submit',      'На модерации',          'Отправить релиз на модерацию',           'send',           'milestone', 75,  5),
  ('ai_10',             '10 генераций',          'Использовать AI 10 раз',                 'smart_toy',      'creative',  40,  6),
  ('ai_50',             '50 генераций',          'Использовать AI 50 раз',                 'auto_fix_high',  'creative',  100, 7),
  ('releases_3',        'Продуктивный артист',   'Создать 3 релиза',                       'library_music',  'milestone', 75,  8),
  ('releases_10',       'Релиз-машина',          'Создать 10 релизов',                     'rocket_launch',  'milestone', 200, 9),
  ('streak_7',          'Неделя подряд',         'Заходить 7 дней подряд',                 'local_fire_department', 'general', 100, 10),
  ('streak_30',         'Месяц подряд',          'Заходить 30 дней подряд',                'diamond',        'general',   300, 11),
  ('subscriber',        'Подписчик',             'Оформить платную подписку',              'workspace_premium','milestone', 50, 12),
  ('share_first',       'Первый шеринг',         'Поделиться результатом',                 'share',          'social',    25,  13),
  ('public_profile',    'Публичный профиль',     'Настроить публичный профиль',            'person',         'social',    30,  14),
  ('potential_hit',     'Потенциальный хит',     'Набрать 1000 прослушиваний на треке',    'whatshot',       'milestone', 150, 15)
ON CONFLICT (id) DO NOTHING;

-- ── Level thresholds config ────────────────────────────────
CREATE TABLE IF NOT EXISTS level_config (
  level      INT PRIMARY KEY,
  name       VARCHAR(30) NOT NULL,
  min_xp     INT NOT NULL,
  perks      TEXT,
  color_key  VARCHAR(20) DEFAULT 'gray'
);

INSERT INTO level_config (level, name, min_xp, perks, color_key) VALUES
  (1,  'Rookie',       0,     'Базовый доступ',                  'gray'),
  (2,  'Beginner',     100,   'Открыт AI чат',                   'green'),
  (3,  'Rising',       300,   'Бейдж Rising',                    'green'),
  (4,  'Skilled',      600,   'Расширенная аналитика',           'blue'),
  (5,  'Pro',          1000,  'Доступ к Collab Board',            'blue'),
  (6,  'Expert',       1500,  'Авто-номинация Awards',            'purple'),
  (7,  'Master',       2200,  'Featured placement',               'purple'),
  (8,  'Top Artist',   3000,  'Приоритетные витрины',             'orange'),
  (9,  'Legend',       4000,  'Эксклюзивный бейдж Legend',        'orange'),
  (10, 'Elite',        5000,  'VIP статус на платформе',          'gold')
ON CONFLICT (level) DO NOTHING;

-- ── Daily streak tracking ──────────────────────────────────
CREATE TABLE IF NOT EXISTS user_streaks (
  user_id       INT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  current_streak INT NOT NULL DEFAULT 0,
  longest_streak INT NOT NULL DEFAULT 0,
  last_active_date DATE NOT NULL DEFAULT current_date,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
