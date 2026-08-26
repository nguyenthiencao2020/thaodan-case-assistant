-- Tiếp tục sửa cảnh báo "Auth RLS Initialization Plan" của Supabase Advisor cho 2 bảng
-- còn lại: cases (bảng cũ, khác cases_v2) và profiles.
-- Giữ NGUYÊN policyname, cmd (SELECT/UPDATE/INSERT/ALL) và logic hiện có — chỉ bọc
-- auth.uid() trong (select auth.uid()) để Postgres tính 1 lần thay vì tính lại từng dòng.
-- Xác nhận cấu trúc hiện tại qua pg_policies trước khi viết migration này:
--   cases.Users read own data     SELECT  using (auth.uid() = user_id)
--   cases.Users update own data   UPDATE  using (auth.uid() = user_id)
--   cases.Users write own data    INSERT  with check (auth.uid() = user_id)
--   profiles.admin_manage_profiles ALL    using is_admin(auth.uid())
--   profiles.read_own_profile     SELECT  using ((auth.uid() = id) OR is_admin(auth.uid()))
-- Chạy 1 lần trong Supabase Dashboard → SQL Editor → New query.

-- ═══ cases ═══
drop policy if exists "Users read own data" on cases;
drop policy if exists "Users update own data" on cases;
drop policy if exists "Users write own data" on cases;

create policy "Users read own data" on cases
  for select
  using ((select auth.uid()) = user_id);

create policy "Users update own data" on cases
  for update
  using ((select auth.uid()) = user_id);

create policy "Users write own data" on cases
  for insert
  with check ((select auth.uid()) = user_id);

-- ═══ profiles ═══
-- is_admin() là hàm có sẵn trong DB — chỉ bọc auth.uid() truyền vào, không đổi is_admin().
drop policy if exists "admin_manage_profiles" on profiles;
drop policy if exists "read_own_profile" on profiles;

create policy "admin_manage_profiles" on profiles
  for all
  using (is_admin((select auth.uid())));

create policy "read_own_profile" on profiles
  for select
  using (
    (select auth.uid()) = id or is_admin((select auth.uid()))
  );
