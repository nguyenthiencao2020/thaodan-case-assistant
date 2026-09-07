-- Sửa hậu quả của một lỗi trong migration 0011.
--
-- ══ NGUYÊN NHÂN ══
-- 0011 viết:
--     alter table profiles add column if not exists role text not null default 'officer'
--       check (role in ('officer','team_leader','admin'));
-- Cột "role" ĐÃ CÓ SẴN trong schema gốc (giá trị 'user') VÀ đã có ràng buộc riêng tên
-- "profiles_role_check" với bộ giá trị KHÔNG chứa 'officer'. Postgres bỏ qua toàn bộ câu
-- ADD COLUMN vì cột đã tồn tại — kể cả DEFAULT, kể cả CHECK mới.
--
-- Trạng thái thật đo được trên DB:
--     id                                    email                                  role   team_id
--     8c4351f8-618b-4307-926d-ee0305b4af91  hangcong.nguyen@thaodancenter.org.vn   user   NULL
--     f5c6d51f-57a4-4c56-adec-37429df52740  thien.nguyen@asif.foundation           user   NULL
--
-- Hậu quả:
--   1) private.is_team_leader() tìm role = 'team_leader' — giá trị đó bị ràng buộc CŨ chặn,
--      nên không ai gán được, cơ chế trưởng nhóm coi như không tồn tại dù policy đã tạo.
--   2) Bản 0015 đầu tiên của tôi chạy lỗi 23514 đúng vì lý do này: nó update role thành
--      'officer' TRƯỚC khi bỏ ràng buộc cũ.
--
-- KHÔNG ảnh hưởng quyền "xem hết ca": quyền đó do email cứng quyết định
-- (private.is_super_admin), không đọc profiles.role.
--
-- ══ THỨ TỰ BẮT BUỘC ══
-- Bỏ ràng buộc cũ → chuẩn hóa giá trị → đặt lại DEFAULT/NOT NULL → tạo ràng buộc mới.
-- Đảo thứ tự là lỗi 23514 như lần trước.

-- 1) Bỏ ràng buộc cũ. Schema gốc chỉ cho phép một bộ giá trị hẹp hơn (không có 'officer',
--    không có 'team_leader'), nên còn nó thì không thể chuẩn hóa được.
alter table profiles drop constraint if exists profiles_role_check;

-- 2) Chuẩn hóa giá trị đang có: 'user' là cách gọi cũ của 'officer' (NVXH thường).
--    Chạy lại nhiều lần vẫn an toàn.
update profiles set role = 'officer' where role is null or role not in ('officer','team_leader','admin');

-- 3) Đặt lại DEFAULT và NOT NULL — hai bước mà 0011 đã bỏ sót.
alter table profiles alter column role set default 'officer';
alter table profiles alter column role set not null;

-- 4) Tạo lại ràng buộc bằng ADD CONSTRAINT (không phải ADD COLUMN) nên lần này áp dụng thật
--    và validate các dòng đang có — nếu còn giá trị lạ, câu này báo lỗi thay vì âm thầm bỏ
--    qua. Đó là điều mong muốn: thà lỗi ngay còn hơn tưởng đã có ràng buộc.
alter table profiles
  add constraint profiles_role_check check (role in ('officer','team_leader','admin'));

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
--
-- LƯU Ý: hàm is_admin() có sẵn trong DB (dùng cho policy của bảng profiles) so role = 'admin'.
-- Sau migration này cả 2 tài khoản là 'officer', tức is_admin() vẫn trả false cho mọi người —
-- giống y trước khi chạy (trước đó là 'user'). Không có gì thay đổi về quyền.

-- ── Kiểm tra ──
--   select p.id, u.email, p.role, p.team_id
--   from profiles p join auth.users u on u.id = p.id;
--   → mọi dòng phải là 'officer', không còn 'user'.
--
--   select conname, pg_get_constraintdef(oid) from pg_constraint
--   where conrelid = 'profiles'::regclass and conname = 'profiles_role_check';
--   → CHECK ((role = ANY (ARRAY['officer'::text, 'team_leader'::text, 'admin'::text])))
