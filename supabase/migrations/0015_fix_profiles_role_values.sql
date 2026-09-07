-- Sửa hậu quả của một lỗi trong migration 0011.
--
-- ══ NGUYÊN NHÂN ══
-- 0011 viết:
--     alter table profiles add column if not exists role text not null default 'officer'
--       check (role in ('officer','team_leader','admin'));
-- Cột "role" ĐÃ CÓ SẴN trong DB từ trước (giá trị 'user'), nên Postgres bỏ qua TOÀN BỘ câu
-- ADD COLUMN — kể cả DEFAULT và kể cả CHECK. Kết quả kiểm tra thực tế trên DB:
--     id                                    role   team_id
--     8c4351f8-618b-4307-926d-ee0305b4af91  user   NULL
--     f5c6d51f-57a4-4c56-adec-37429df52740  user   NULL
--
-- Hậu quả:
--   1) Giá trị thật là 'user', không nằm trong 3 giá trị mà 0011 giả định.
--   2) Không có ràng buộc CHECK → gõ sai giá trị cũng không ai chặn.
--   3) private.is_team_leader() tìm role = 'team_leader' nên KHÔNG BAO GIỜ khớp — cơ chế
--      trưởng nhóm coi như không tồn tại, dù policy đã được tạo.
--
-- KHÔNG ảnh hưởng quyền "xem hết ca": quyền đó do email cứng quyết định
-- (private.is_super_admin), không đọc profiles.role.

-- 1) Chuẩn hóa giá trị đang có: 'user' là cách gọi cũ của 'officer' (NVXH thường).
--    Chạy lại nhiều lần vẫn an toàn.
update profiles set role = 'officer' where role in ('user', 'nvxh') or role is null;

-- 2) Đặt lại DEFAULT — bước mà 0011 đã bỏ sót.
alter table profiles alter column role set default 'officer';
alter table profiles alter column role set not null;

-- 3) Tạo ràng buộc CHECK. Dùng ALTER TABLE ADD CONSTRAINT (không phải ADD COLUMN) nên lần này
--    áp dụng thật, và có validate các dòng đang có — nếu còn giá trị lạ, câu này sẽ báo lỗi
--    thay vì âm thầm bỏ qua. Đó là điều mong muốn: thà lỗi ngay còn hơn tưởng đã có ràng buộc.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_role_check'
  ) then
    alter table profiles
      add constraint profiles_role_check check (role in ('officer','team_leader','admin'));
  end if;
end $$;

-- ── Sau khi chạy: bật trưởng nhóm (chưa có UI, phải gán tay) ──
-- Gán role và nhóm cho NGƯỜI:
--   update profiles set role = 'team_leader', team_id = 'nhom-1' where id = '<uid trưởng nhóm>';
--   update profiles set team_id = 'nhom-1'                        where id = '<uid NVXH>';
-- Gán nhóm cho CA: app đã có (chỉ admin thấy), hoặc:
--   update cases_v2 set team_id = 'nhom-1' where id = '<case id>';
--
-- Policy "team_leader_view_team_cases" (tạo ở 0011) đòi team_id IS NOT NULL ở cả ca và
-- profile, nên tới khi gán đủ 3 chỗ trên thì nó mới bắt đầu có hiệu lực. Trưởng nhóm chỉ
-- XEM được ca cùng nhóm, không sửa/xóa.

-- ── Kiểm tra ──
--   select p.id, u.email, p.role, p.team_id
--   from profiles p join auth.users u on u.id = p.id;
--   → mọi dòng phải là 'officer' (hoặc giá trị bạn vừa gán), không còn 'user'.
--
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--   where conname = 'profiles_role_check';
--   → phải trả về 1 dòng.
