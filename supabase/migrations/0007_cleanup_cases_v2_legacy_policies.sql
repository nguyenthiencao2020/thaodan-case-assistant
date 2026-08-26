-- Dọn dứt điểm cases_v2 — đã xác nhận không ai đang có profiles.role = 'admin'
-- (select ... from profiles where role = 'admin' → 0 dòng), nên các policy cũ dựa trên
-- is_admin() không cấp quyền cho ai cả — xóa an toàn, không mất quyền truy cập của ai.
--
-- Sau khi xóa, cases_v2 chỉ còn đúng 2 policy (đã tối ưu ở 0004):
--   users_own_cases  (FOR ALL,    auth.uid() = user_id)
--   admin_all_cases  (FOR SELECT, email = 'hangcong.nguyen@thaodancenter.org.vn')
-- khớp đúng với cơ chế admin duy nhất mà app đang dùng (isAdmin() trong src/js/main.js).

drop policy if exists "Users delete own cases" on cases_v2;
drop policy if exists "Users insert own cases" on cases_v2;
drop policy if exists "Users read own cases" on cases_v2;
drop policy if exists "Users update own cases" on cases_v2;

drop policy if exists "delete_cases" on cases_v2;
drop policy if exists "read_cases" on cases_v2;
drop policy if exists "update_cases" on cases_v2;
drop policy if exists "write_cases" on cases_v2;
