-- RLS cho case_files, notifications, case_stats + storage bucket "case-files"
-- Áp dụng cùng khuôn mẫu user_id / admin-email đã dùng cho cases_v2 ở 0002_admin_rls.sql.
-- Chạy 1 lần trong Supabase Dashboard → SQL Editor → New query.

-- ═══ case_files (metadata file đính kèm ca — xem uploadCaseFile() trong src/js/main.js) ═══
alter table if exists case_files enable row level security;

drop policy if exists "users_own_case_files" on case_files;
drop policy if exists "admin_all_case_files" on case_files;

create policy "users_own_case_files" on case_files
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "admin_all_case_files" on case_files
  for select
  using (
    (select email from auth.users where id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ notifications ═══
alter table if exists notifications enable row level security;

drop policy if exists "users_own_notifications" on notifications;
drop policy if exists "admin_all_notifications" on notifications;

create policy "users_own_notifications" on notifications
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "admin_all_notifications" on notifications
  for select
  using (
    (select email from auth.users where id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ case_stats ═══
-- Nếu bảng này thực chất là VIEW (không phải table thật) thì câu ALTER TABLE dưới sẽ báo lỗi
-- "case_stats is not a table" — khi đó bỏ qua đoạn này và xem hướng dẫn "case_stats là view" bên dưới.
alter table if exists case_stats enable row level security;

drop policy if exists "users_own_case_stats" on case_stats;
drop policy if exists "admin_all_case_stats" on case_stats;

create policy "users_own_case_stats" on case_stats
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "admin_all_case_stats" on case_stats
  for select
  using (
    (select email from auth.users where id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- ═══ Storage bucket "case-files" — file vật lý (ảnh/PDF...), không phải bảng dữ liệu ═══
-- Đường dẫn lưu file có dạng "<user_id>/<case_id>/<timestamp>.<ext>" (xem uploadCaseFile()),
-- nên policy giới hạn theo folder đầu tiên phải khớp auth.uid() của người đăng nhập.
drop policy if exists "users_own_case_files_storage" on storage.objects;
drop policy if exists "admin_all_case_files_storage" on storage.objects;

create policy "users_own_case_files_storage" on storage.objects
  for all
  using (bucket_id = 'case-files' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'case-files' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "admin_all_case_files_storage" on storage.objects
  for select
  using (
    bucket_id = 'case-files'
    and (select email from auth.users where id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn'
  );
