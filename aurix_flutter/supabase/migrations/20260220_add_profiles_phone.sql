-- Add phone column to profiles (if not exists)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone text;

-- Unique index on phone (only for non-null values)
CREATE UNIQUE INDEX IF NOT EXISTS profiles_phone_unique
  ON profiles (phone)
  WHERE phone IS NOT NULL;
