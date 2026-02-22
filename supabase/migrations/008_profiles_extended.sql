-- Расширение profiles: name, city, gender, bio, avatar_url
-- Существующая таблица имеет id (PK, FK auth.users), email, display_name, artist_name, phone, role, account_status, created_at, updated_at

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS name text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS city text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gender text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS bio text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url text;

-- gender check: male, female, other или null
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_gender_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_gender_check
  CHECK (gender IS NULL OR gender IN ('male', 'female', 'other'));

-- updated_at trigger уже есть в 001_init
-- RLS policies уже есть (profiles_select_own, profiles_update_own, profiles_insert_own)
