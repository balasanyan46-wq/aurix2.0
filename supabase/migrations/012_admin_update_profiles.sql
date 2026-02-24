-- Allow admins to update any profile (role, plan, account_status)
create policy "profiles_admin_update" on public.profiles
  for update using (
    exists (select 1 from public.profiles p where p.user_id = auth.uid() and p.role = 'admin')
  );
