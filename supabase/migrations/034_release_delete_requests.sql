-- Delete requests flow: artist requests, admin approves/rejects.
begin;

create table if not exists public.release_delete_requests (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references public.releases(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'cancelled')),
  reason text,
  admin_comment text,
  processed_by uuid references auth.users(id) on delete set null,
  processed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_release_delete_requests_release on public.release_delete_requests(release_id);
create index if not exists idx_release_delete_requests_requester on public.release_delete_requests(requester_id, created_at desc);
create index if not exists idx_release_delete_requests_status on public.release_delete_requests(status, created_at desc);

-- Prevent duplicate pending requests for one release.
create unique index if not exists uniq_release_delete_pending_per_release
  on public.release_delete_requests(release_id)
  where status = 'pending';

alter table public.release_delete_requests enable row level security;

drop policy if exists "Users read own delete requests or admin reads all" on public.release_delete_requests;
create policy "Users read own delete requests or admin reads all"
  on public.release_delete_requests for select
  using (
    requester_id = auth.uid()
    or exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.role = 'admin'
    )
  );

drop policy if exists "Users create delete requests for own releases" on public.release_delete_requests;
create policy "Users create delete requests for own releases"
  on public.release_delete_requests for insert
  with check (
    requester_id = auth.uid()
    and exists (
      select 1 from public.releases r
      where r.id = release_id and r.owner_id = auth.uid()
    )
  );

drop policy if exists "Admins update delete requests" on public.release_delete_requests;
create policy "Admins update delete requests"
  on public.release_delete_requests for update
  using (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.role = 'admin'
    )
  )
  with check (
    exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.role = 'admin'
    )
  );

commit;

