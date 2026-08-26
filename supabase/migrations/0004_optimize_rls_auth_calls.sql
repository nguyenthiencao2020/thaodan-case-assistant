-- Sửa cảnh báo "Auth RLS Initialization Plan" của Supabase Advisor.
-- Nguyên nhân: policy gọi auth.uid() trực tiếp khiến Postgres tính lại hàm này cho TỪNG DÒNG
-- khi quét bảng, thay vì tính 1 lần rồi tái sử dụng. Cách khuyến nghị của Supabase: bọc trong
-- (select auth.uid()) để Postgres coi đây là InitPlan (chỉ chạy 1 lần).
-- Đây là tối ưu HIỆU NĂNG — không đổi logic/quyền truy cập, chỉ viết lại cùng policy cho nhanh hơn.
-- Chạy 1 lần trong Supabase Dashboard → SQL Editor → New query.

-- ═══ cases_v2 ═══
drop policy if exists "users_own_cases" on cases_v2;
drop policy if exists "admin_all_cases" on cases_v2;

create policy "users_own_cases" on cases_v2
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "admin_all_cases" on cases_v2
  for select
  using (
    (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ case_files ═══
drop policy if exists "users_own_case_files" on case_files;
drop policy if exists "admin_all_case_files" on case_files;

create policy "users_own_case_files" on case_files
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "admin_all_case_files" on case_files
  for select
  using (
    (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ notifications ═══
drop policy if exists "users_own_notifications" on notifications;
drop policy if exists "admin_all_notifications" on notifications;

create policy "users_own_notifications" on notifications
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "admin_all_notifications" on notifications
  for select
  using (
    (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ case_stats ═══
drop policy if exists "users_own_case_stats" on case_stats;
drop policy if exists "admin_all_case_stats" on case_stats;

create policy "users_own_case_stats" on case_stats
  for all
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "admin_all_case_stats" on case_stats
  for select
  using (
    (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ storage.objects — bucket "case-files" ═══
drop policy if exists "users_own_case_files_storage" on storage.objects;
drop policy if exists "admin_all_case_files_storage" on storage.objects;

create policy "users_own_case_files_storage" on storage.objects
  for all
  using (bucket_id = 'case-files' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'case-files' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "admin_all_case_files_storage" on storage.objects
  for select
  using (
    bucket_id = 'case-files'
    and (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );
