-- 1) Vá "Function Search Path Mutable" — lỗ hổng thật, không phải hiệu năng.
--    is_admin() và check_stale_cases() là SECURITY DEFINER (chạy với quyền người tạo hàm)
--    nhưng không khóa search_path, nên có thể bị "đánh lừa" nếu ai đó tạo bảng/hàm trùng tên
--    trong schema khác nằm trước trong search_path của họ. Khóa cứng về "public" (cả 2 hàm chỉ
--    dùng bảng trong schema public, không tạo bảng tạm nên không cần thêm pg_temp).
alter function public.is_admin(uid uuid) set search_path = public;
alter function public.check_stale_cases() set search_path = public;

-- 2) Dọn policy cũ TRÙNG LẶP HOÀN TOÀN trên case_files và notifications — các policy này
--    không liên quan is_admin(), chỉ lặp lại đúng logic "auth.uid() = user_id" mà policy
--    "users_own_*" (FOR ALL, đã tối ưu) đã bao trọn cho mọi lệnh SELECT/INSERT/UPDATE/DELETE.
--    Xóa an toàn — không đổi ai được xem/sửa gì, chỉ giảm số policy phải đánh giá mỗi query
--    (khắc phục "Multiple Permissive Policies" + các dòng "Auth RLS Initialization Plan" lặp).
drop policy if exists "Users delete own files" on case_files;
drop policy if exists "Users insert own files" on case_files;
drop policy if exists "Users read own files" on case_files;

drop policy if exists "Users read own notifications" on notifications;
drop policy if exists "Users update own notifications" on notifications;

-- 3) cases_v2: CHƯA xử lý ở migration này.
--    Bảng này có thêm 4 policy cũ dùng is_admin() (delete_cases/read_cases/update_cases/write_cases)
--    song song với cơ chế admin theo email (admin_all_cases) mà app hiện tại đang dùng
--    (xem isAdmin() trong src/js/main.js — chỉ check email, không check profiles.role).
--    Cần xác nhận trước: có ai khác ngoài admin email đang có profiles.role = 'admin' không —
--    nếu có, xóa nhầm các policy is_admin() này sẽ làm mất quyền truy cập của họ.
--    Xem migration 0007 (sau khi xác nhận) để dọn dứt điểm cases_v2.
