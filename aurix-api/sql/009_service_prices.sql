-- 009: Service prices table — admin-managed pricing for release services
CREATE TABLE IF NOT EXISTS service_prices (
  id TEXT PRIMARY KEY,            -- e.g. 'ai_cover', 'pitching'
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  step INTEGER NOT NULL DEFAULT 0, -- wizard step where it appears
  enabled BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed default prices
INSERT INTO service_prices (id, name, description, price, step, sort_order) VALUES
  ('ai_cover',      'AI обложка',                       'Генерация обложки нейросетью по вашему описанию',           990,   1, 1),
  ('lyrics_sync',   'Синхронизация текста (караоке)',    'Тайминг каждой строки для Apple Music и Spotify',          1970,  2, 2),
  ('lyrics_check',  'AI проверка текста',               'Проверка орфографии, рифм и ритмики',                       0,     2, 3),
  ('pitching',      'Питчинг в плейлисты',              'Отправка релиза кураторам Spotify и Apple Music',           4970,  4, 4),
  ('tiktok_promo',  'TikTok продвижение',               'Посев в TikTok — от 10 блогеров',                          9970,  5, 5),
  ('youtube_clip',  'AI клип для YouTube',              'Визуализация трека нейросетью',                            14970,  5, 6)
ON CONFLICT (id) DO NOTHING;
