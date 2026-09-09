-- Quyền "xem được TẤT CẢ ca" chuyển từ EMAIL CỨNG sang DỮ LIỆU (profiles.role).
--
-- ══ VÌ SAO ══
-- Tới trước migration này, quyền xem hết ca do một email nằm cứng ở hai chỗ:
--   · private.is_super_admin()      — dùng trong policy của cases_v2, case_files, notifications,
--                                     audit_logs, storage.objects (migration 0014)
--   · ADMIN_EMAIL trong src/js/main.js — dùng để ẩn/hiện các nút quản trị
-- Hậu quả thực tế: tổ chức đổi nhân sự quản lý là phải nhờ kỹ thuật sửa code rồi deploy lại; và
-- đọc bảng profiles KHÔNG biết được ai đang thực sự có quyền — bảng ghi 'officer' mà người đó
-- vẫn xem hết ca. Hồ sơ bảo vệ trẻ em thì "ai xem được gì" phải tra được, không thể nằm trong code.
--
-- Yêu cầu của tổ chức (09/09/2026): 3 người xem được tất cả ca — hangcong.nguyen, ngan.lee,
-- thien.nguyen; những người còn lại là CBXH, chỉ thấy ca của mình.
--
-- ══ CÁCH LÀM ══
-- is_super_admin() nay trả true khi profiles.role = 'admin', HOẶC email khớp email dự phòng.
-- Giữ email dự phòng là có chủ ý: nếu ai đó lỡ tay hạ hết role admin thì vẫn còn một đường vào
-- để sửa lại — mất hết quyền quản trị thì không ai vào gán lại được, phải nhờ kỹ thuật.
--
-- ══ QUYỀN THỰC TẾ CỦA role = 'admin' ══
-- Các policy admin_* đều là FOR SELECT, còn users_own_cases là FOR ALL trên ca CỦA MÌNH. Nên
-- 'admin' = XEM được mọi ca, nhưng chỉ SỬA/XÓA được ca của chính mình. Đúng như yêu cầu.
-- Kèm theo: policy "admin_manage_profiles" (0009) dùng private.is_admin() cũng so role='admin',
-- nên 3 người này gán được vai trò cho người khác từ trong app. Đó là ý muốn, không phải tác dụng phụ.
--
-- KHÔNG đổi policy nào. Chỉ đổi ruột một hàm + chuẩn hóa dữ liệu.

-- ── 1) Đọc quyền từ dữ liệu ────────────────────────────────────────────────────────────────
-- SECURITY DEFINER: hàm phải đọc được profiles và auth.users trong khi người gọi (role
-- authenticated) không có quyền đó. STABLE: trong một câu lệnh, quyền của người đang đăng nhập
-- không đổi, Postgres gọi một lần thay vì gọi lại cho từng dòng.
-- KHÔNG dùng hàm này trong policy của bảng profiles — nó đọc profiles, sẽ đệ quy vô hạn. Policy
-- của profiles vẫn dùng private.is_admin() như cũ (0009).
create or replace function private.is_super_admin()
returns boolean
language sql
security definer
stable
set search_path = ''
as $$
  select coalesce(
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'admin'
    )
    or (select u.email from auth.users u where u.id = auth.uid())
       = 'hangcong.nguyen@thaodancenter.org.vn',   -- đường dự phòng, đừng xóa
    false
  );
$$;

revoke execute on function private.is_super_admin() from public, anon;
grant  execute on function private.is_super_admin() to authenticated;

-- ── 2) Mọi tài khoản đều phải có dòng profiles ─────────────────────────────────────────────
-- Không có dòng thì mọi lệnh update role đều sửa 0 dòng và im lặng — đã gặp thật: 4 trong 6 tài
-- khoản chưa có dòng nào.
insert into profiles (id, role)
select u.id, 'officer'
from auth.users u
left join profiles p on p.id = u.id
where p.id is null;

-- ── 3) Phân quyền theo yêu cầu của tổ chức ────────────────────────────────────────────────
-- Chạy lại nhiều lần vẫn an toàn. Thêm/bớt người thì sửa danh sách này rồi chạy lại, hoặc dùng
-- màn "Gán vai trò & nhóm" trong app (nút ⋯ → chỉ người có role admin thấy).
update profiles set role = 'admin', team_id = null
where id in (
  select u.id from auth.users u
  where lower(u.email) in (
    'hangcong.nguyen@thaodancenter.org.vn',
    'ngan.lee@thaodancenter.org.vn',
    'thien.nguyen@asif.foundation'
  )
);

-- Còn lại là CBXH. Không dùng nhóm: cơ chế trưởng nhóm (0011) chỉ cho xem ca CÙNG NHÓM, không
-- phù hợp với yêu cầu "xem tất cả", nên để team_id NULL cho sạch — cơ chế vẫn còn đó, sau này
-- nhiều địa bàn thì bật lên dùng.
update profiles set role = 'officer', team_id = null
where role <> 'admin';

-- ── Kiểm tra sau khi chạy ─────────────────────────────────────────────────────────────────
-- 1) Đúng 3 người 'admin', còn lại 'officer', không ai còn nhóm:
--      select u.email, p.role, p.team_id
--      from profiles p join auth.users u on u.id = p.id
--      order by p.role, u.email;
--
-- 2) Đăng nhập bằng ngan.lee@thaodancenter.org.vn → phải thấy TẤT CẢ ca trong tab Danh sách ca,
--    và menu ⋯ phải có mục "Gán vai trò & nhóm (quản trị)".
--    Đăng nhập bằng nhu.nguyen@thaodancenter.org.vn → chỉ thấy ca của chính mình.
--
-- 3) Hạ quyền một người (làm từ app, hoặc):
--      update profiles set role = 'officer' where id =
--        (select id from auth.users where email = 'ngan.lee@thaodancenter.org.vn');
--    Người đó tải lại trang là mất quyền ngay — không cần deploy gì.
