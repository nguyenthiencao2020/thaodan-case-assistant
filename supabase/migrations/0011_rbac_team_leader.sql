-- RBAC nhiều cấp (officer / team_leader / admin) — theo đề xuất nâng cấp v2.0.
-- Thiết kế để KHÔNG ảnh hưởng gì tới quyền truy cập hiện có:
--   - team_id mặc định NULL cho mọi profile/ca hiện có và ca mới tạo sau này.
--   - Policy "trưởng nhóm xem theo team" chỉ khớp khi CẢ 2 điều kiện đều có giá trị và bằng
--     nhau — team_id NULL sẽ không bao giờ khớp NULL (so sánh NULL luôn cho kết quả không đúng
--     trong SQL), nên policy này coi như không có hiệu lực cho tới khi có ai đó chủ động gán
--     team_id cho profile và cho ca.
-- CHƯA có UI quản lý nhóm/gán ca — admin cần tự gán qua SQL Editor cho tới khi có UI riêng:
--   update profiles set role = 'team_leader', team_id = 'nhom-vang-tau' where id = '<uid>';
--   update profiles set team_id = 'nhom-vang-tau' where id = '<uid officer trong nhóm>';
--   update cases_v2 set team_id = 'nhom-vang-tau' where id = '<case id>';

alter table if exists profiles add column if not exists role text not null default 'officer'
  check (role in ('officer','team_leader','admin'));
alter table if exists profiles add column if not exists team_id text;

alter table if exists cases_v2 add column if not exists team_id text;
create index if not exists idx_cases_v2_team_id on cases_v2 (team_id);

-- Hàm tra cứu team_id/role của 1 user — SECURITY DEFINER để tránh đệ quy RLS (profiles có RLS
-- riêng của nó; nếu policy của cases_v2 subquery thẳng vào profiles dưới quyền người gọi, có
-- thể gây vòng lặp/kết quả sai giống sự cố is_admin() trước đây). Dời sang schema "private"
-- luôn (không phải public) để không lộ ra làm RPC endpoint công khai.
create or replace function private.get_user_team(uid uuid)
returns text
security definer
set search_path = public
language sql
stable
as $$
  select team_id from profiles where id = uid;
$$;

create or replace function private.is_team_leader(uid uuid)
returns boolean
security definer
set search_path = public
language sql
stable
as $$
  select exists(select 1 from profiles where id = uid and role = 'team_leader');
$$;

revoke execute on function private.get_user_team(uuid) from public, anon;
grant execute on function private.get_user_team(uuid) to authenticated;
revoke execute on function private.is_team_leader(uuid) from public, anon;
grant execute on function private.is_team_leader(uuid) to authenticated;

-- Policy mới: trưởng nhóm xem (chỉ SELECT, không sửa/xóa ca người khác) các ca cùng team_id.
-- Không đổi/xóa policy nào hiện có (users_own_cases, admin_all_cases) — chỉ CỘNG THÊM.
drop policy if exists "team_leader_view_team_cases" on cases_v2;
create policy "team_leader_view_team_cases" on cases_v2
  for select to authenticated
  using (
    team_id is not null
    and private.is_team_leader((select auth.uid()))
    and team_id = private.get_user_team((select auth.uid()))
  );
