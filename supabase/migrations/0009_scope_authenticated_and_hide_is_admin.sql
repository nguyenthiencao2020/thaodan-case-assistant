-- 1) Dời is_admin() ra khỏi schema "public" — PostgREST chỉ tự expose RPC cho hàm nằm trong
--    schema công khai (mặc định là "public"), nên dời sang "private" sẽ KHÔNG còn gọi được qua
--    /rest/v1/rpc/is_admin nữa, trong khi RLS bên trong Postgres vẫn gọi được như cũ (RLS chạy
--    thẳng trong DB, không đi qua lớp REST nên không bị ảnh hưởng bởi việc này).
--    Không đổi SECURITY DEFINER (không dùng SECURITY INVOKER — sẽ gây đệ quy vì is_admin() tự
--    query lại profiles, mà chính profiles lại dùng is_admin() trong policy của nó).
create schema if not exists private;

-- Bọc trong DO block để chạy lại được nhiều lần an toàn — ALTER FUNCTION ... SET SCHEMA không
-- có "if exists" nên nếu hàm đã được dời sang private từ trước (VD: chạy migration này 2 lần),
-- chạy thẳng câu ALTER sẽ báo lỗi "function public.is_admin(uuid) does not exist". Chỉ dời khi
-- nó thật sự còn nằm trong public.
do $$
begin
  if exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where p.proname = 'is_admin' and n.nspname = 'public'
      and pg_get_function_identity_arguments(p.oid) = 'uid uuid'
  ) then
    alter function public.is_admin(uuid) set schema private;
  end if;
end $$;

-- Cập nhật lại 2 policy của profiles để trỏ đúng vị trí mới của hàm.
drop policy if exists "admin_manage_profiles" on profiles;
drop policy if exists "read_own_profile" on profiles;

create policy "admin_manage_profiles" on profiles
  for all
  to authenticated
  using (private.is_admin((select auth.uid())));

create policy "read_own_profile" on profiles
  for select
  to authenticated
  using (
    (select auth.uid()) = id or private.is_admin((select auth.uid()))
  );

-- 2) Giới hạn rõ các policy còn lại chỉ áp dụng cho role "authenticated" (bỏ "anon") —
--    app này không có tính năng nào dùng được khi chưa đăng nhập, nên anon không cần được
--    RLS xét tới. Hết cảnh báo "Multiple Permissive Policies" cho role anon, giữ nguyên hành vi
--    cho người đã đăng nhập (không đổi gì về việc ai xem/sửa được ca nào).

drop policy if exists "users_own_cases" on cases_v2;
drop policy if exists "admin_all_cases" on cases_v2;
create policy "users_own_cases" on cases_v2
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "admin_all_cases" on cases_v2
  for select to authenticated
  using ((select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn');

drop policy if exists "users_own_case_files" on case_files;
drop policy if exists "admin_all_case_files" on case_files;
create policy "users_own_case_files" on case_files
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "admin_all_case_files" on case_files
  for select to authenticated
  using ((select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn');

drop policy if exists "users_own_notifications" on notifications;
drop policy if exists "admin_all_notifications" on notifications;
create policy "users_own_notifications" on notifications
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "admin_all_notifications" on notifications
  for select to authenticated
  using ((select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn');

drop policy if exists "users_own_case_files_storage" on storage.objects;
drop policy if exists "admin_all_case_files_storage" on storage.objects;
create policy "users_own_case_files_storage" on storage.objects
  for all to authenticated
  using (bucket_id = 'case-files' and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'case-files' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "admin_all_case_files_storage" on storage.objects
  for select to authenticated
  using (
    bucket_id = 'case-files'
    and (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );
