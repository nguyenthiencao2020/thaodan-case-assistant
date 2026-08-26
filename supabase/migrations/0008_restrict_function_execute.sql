-- Vá "Public/Signed-In Users Can Execute SECURITY DEFINER Function".
-- Supabase tự expose mọi hàm có quyền EXECUTE cho anon/authenticated thành RPC endpoint công khai
-- (POST /rest/v1/rpc/<tên_hàm>). Xác nhận qua src/js/main.js: app KHÔNG có bất kỳ lệnh
-- supabase.rpc(...) nào gọi is_admin hoặc check_stale_cases — cả 2 chỉ được dùng nội bộ
-- (is_admin trong RLS policy của profiles; check_stale_cases dự kiến chạy qua cron/thủ công).

-- check_stale_cases(): KHÔNG có ai cần gọi qua API. Hàm này insert notification cho TẤT CẢ
-- ca đang mở của TẤT CẢ user mỗi lần chạy — nếu để công khai, ai đó gọi lặp lại qua RPC có thể
-- spam notification hàng loạt / gây tải DB. Thu hồi quyền thực thi của mọi role phía client.
revoke execute on function public.check_stale_cases() from public;
revoke execute on function public.check_stale_cases() from anon;
revoke execute on function public.check_stale_cases() from authenticated;

-- is_admin(uuid): ĐANG được RLS policy của bảng profiles gọi (admin_manage_profiles,
-- read_own_profile) — user đã đăng nhập (authenticated) BẮT BUỘC cần quyền EXECUTE để những
-- policy đó hoạt động, không thể thu hồi hết. Chỉ thu hẹp: bỏ quyền của "anon"/"public"
-- (người chưa đăng nhập không cần và không nên gọi được), giữ lại đúng "authenticated".
revoke execute on function public.is_admin(uuid) from public;
revoke execute on function public.is_admin(uuid) from anon;
grant execute on function public.is_admin(uuid) to authenticated;
