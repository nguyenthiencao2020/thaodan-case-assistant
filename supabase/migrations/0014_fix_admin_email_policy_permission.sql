-- Sửa lỗi "permission denied for table users" khi NVXH lưu ca.
--
-- ══ NGUYÊN NHÂN ══
-- Từ migration 0003 tới 0010, các policy dành cho admin đều viết trực tiếp:
--     (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@…'
-- Biểu thức trong RLS policy được đánh giá bằng QUYỀN CỦA NGƯỜI GỌI, không phải quyền của
-- chủ bảng. Role "authenticated" không có quyền SELECT trên auth.users (Supabase thu hồi
-- mặc định), nên mỗi lần một policy như vậy được đánh giá là Postgres báo:
--     permission denied for table users
--
-- Vì sao lần lưu đầu được mà lần lưu sau thì lỗi: app dù
--     .upsert(payload, { onConflict: 'id' })
-- tức INSERT ... ON CONFLICT DO UPDATE. Lần đầu chỉ là INSERT thuần nên chỉ xét policy INSERT
-- ("users_own_cases", không dính auth.users) → chạy được. Từ lần thứ hai, câu lệnh phải tìm
-- dòng đang xung đột để UPDATE, và Postgres đòi CẢ policy SELECT cho bước đó — lúc này
-- "admin_all_cases" (for select) bị đánh giá và làm cả câu lệnh thất bại. Người dùng thấy hộp
-- thoại "CHƯA lưu được lên máy chủ · Lý do: permission denied for table users".
--
-- ══ CÁCH SỬA ══
-- Bọc phép so email vào một hàm SECURITY DEFINER: hàm chạy bằng quyền của chủ hàm nên đọc
-- được auth.users, còn policy chỉ cần quyền EXECUTE. Đặt trong schema "private" nên PostgREST
-- không expose thành endpoint /rest/v1/rpc/... (cùng cách đã làm với is_admin() ở 0009).
--
-- KHÔNG đổi một dòng dữ liệu nào, KHÔNG đổi ai xem/sửa được ca nào — chỉ đổi cách policy
-- lấy email admin.

create schema if not exists private;

-- STABLE: trong cùng một câu lệnh, email của người đang đăng nhập không đổi, nên Postgres chỉ
-- cần gọi một lần thay vì gọi lại cho từng dòng.
-- search_path = '' : bắt buộc ghi rõ schema ở mọi chỗ bên trong, không để ai đánh lừa hàm bằng
-- một bảng "users" tự tạo trong schema khác.
create or replace function private.is_super_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select coalesce(
    (select u.email from auth.users u where u.id = auth.uid()) = 'hangcong.nguyen@thaodancenter.org.vn',
    false
  );
$$;

-- Policy được đánh giá bằng quyền của role đang gọi, nên "authenticated" phải có EXECUTE.
-- Vẫn thu hồi của public/anon: người chưa đăng nhập không cần và không nên gọi được.
revoke execute on function private.is_super_admin() from public;
revoke execute on function private.is_super_admin() from anon;
grant  usage   on schema private to authenticated;
grant  execute on function private.is_super_admin() to authenticated;

-- ── Dựng lại 5 policy còn dùng biểu thức cũ ──
-- Giữ nguyên tên policy, phạm vi (for select), role (authenticated) và ý nghĩa.

drop policy if exists "admin_all_cases" on cases_v2;
create policy "admin_all_cases" on cases_v2
  for select to authenticated
  using (private.is_super_admin());

drop policy if exists "admin_all_case_files" on case_files;
create policy "admin_all_case_files" on case_files
  for select to authenticated
  using (private.is_super_admin());

drop policy if exists "admin_all_notifications" on notifications;
create policy "admin_all_notifications" on notifications
  for select to authenticated
  using (private.is_super_admin());

drop policy if exists "admin_read_audit" on audit_logs;
create policy "admin_read_audit" on audit_logs
  for select to authenticated
  using (private.is_super_admin());

drop policy if exists "admin_all_case_files_storage" on storage.objects;
create policy "admin_all_case_files_storage" on storage.objects
  for select to authenticated
  using (bucket_id = 'case-files' and private.is_super_admin());

-- ── Kiểm tra sau khi chạy ──
-- 1) Không còn policy nào tự đọc auth.users:
--      select schemaname, tablename, policyname
--      from pg_policies
--      where qual like '%auth.users%' or with_check like '%auth.users%';
--    → phải trả về 0 dòng.
-- 2) Đăng nhập bằng một tài khoản NVXH thường, lưu một ca HAI LẦN liên tiếp — lần thứ hai
--    chính là lần trước đây báo lỗi.
