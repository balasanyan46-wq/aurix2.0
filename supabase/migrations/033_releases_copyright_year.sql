-- Fix: releases.copyright_year used by app but missing in DB.
-- Apply in Supabase SQL Editor or via `supabase db push`.

alter table public.releases
  add column if not exists copyright_year int;

-- Optional (helps with PostgREST schema cache in some setups):
-- notify pgrst, 'reload schema';

