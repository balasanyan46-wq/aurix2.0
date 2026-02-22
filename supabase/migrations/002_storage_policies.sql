-- Storage buckets: covers, tracks
-- Пути: covers/{user_id}/{file_name}, tracks/{user_id}/{file_name}
-- Владелец загружает/читает свои; admin — всё

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('covers', 'covers', false, 5242880, array['image/jpeg', 'image/png', 'image/jpg']),
  ('tracks', 'tracks', false, 104857600, array['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/x-wav', 'audio/flac'])
on conflict (id) do update set
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Политики storage: пользователь только в своей папке user_id/...
-- RLS для storage: проверяем путь (name) — должен начинаться с auth.uid()::

-- covers: владелец папки = свой user_id
create policy "covers_upload_own" on storage.objects
  for insert with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "covers_select_own_or_admin" on storage.objects
  for select using (
    bucket_id = 'covers'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
    )
  );

create policy "covers_update_own" on storage.objects
  for update using (
    bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "covers_delete_own" on storage.objects
  for delete using (
    bucket_id = 'covers' and (storage.foldername(name))[1] = auth.uid()::text
  );

-- tracks
create policy "tracks_upload_own" on storage.objects
  for insert with check (
    bucket_id = 'tracks'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "tracks_select_own_or_admin" on storage.objects
  for select using (
    bucket_id = 'tracks'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
    )
  );

create policy "tracks_update_own" on storage.objects
  for update using (
    bucket_id = 'tracks' and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "tracks_delete_own" on storage.objects
  for delete using (
    bucket_id = 'tracks' and (storage.foldername(name))[1] = auth.uid()::text
  );
