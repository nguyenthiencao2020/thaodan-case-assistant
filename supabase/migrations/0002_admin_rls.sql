-- Admin RLS policies for cases_v2
-- Allow admin email to read all cases; regular users see only their own

alter table if exists cases_v2 enable row level security;

-- Drop existing policies if re-running
drop policy if exists "users_own_cases" on cases_v2;
drop policy if exists "admin_all_cases" on cases_v2;

-- Regular users: full access to their own cases
create policy "users_own_cases" on cases_v2
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Admin: read-only access to all cases
create policy "admin_all_cases" on cases_v2
  for select
  using (
    (select email from auth.users where id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn'
  );
