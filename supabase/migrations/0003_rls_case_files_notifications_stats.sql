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
-- case_stats là VIEW (gom số liệu từ cases_v2 theo user_id), không phải table thật, nên
-- không gắn policy trực tiếp được. security_invoker khiến view chạy bằng quyền của người
-- ĐANG TRUY VẤN thay vì người TẠO view — nhờ đó RLS của cases_v2 (bảng gốc) tự áp dụng
-- khi ai đó SELECT case_stats, không cần policy riêng cho view.
alter view if exists case_stats set (security_invoker = true);

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
