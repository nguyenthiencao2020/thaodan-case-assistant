-- Audit log: ghi lại ai xem/tạo/sửa/xóa ca nào, lúc nào — theo đề xuất nâng cấp v2.0.
-- Bảng MỚI hoàn toàn, không đổi gì trên cases_v2/case_files/notifications/profiles hiện có
-- — an toàn tuyệt đối với dữ liệu ca thật đang có.
--
-- Không đặt FOREIGN KEY case_id → cases_v2(id): id của cases_v2 là chuỗi tự sinh phía client
-- (dạng "c_<timestamp>_<random>", xem genCaseId() trong src/js/main.js), không phải uuid, và
-- không chắc chắn kiểu cột chính xác trên DB thật — cố tình bỏ FK để tránh migration lỗi vì
-- sai kiểu dữ liệu. case_id chỉ lưu tham khảo, không ràng buộc toàn vẹn tham chiếu.
create table if not exists audit_logs (
  id          bigserial primary key,
  user_id     uuid,           -- có thể NULL khi thao tác chạy ngoài phiên đăng nhập (VD: SQL Editor)
  case_id     text,
  action      text not null check (action in ('view','create','edit','delete')),
  created_at  timestamptz not null default now()
);

create index if not exists idx_audit_logs_case_id on audit_logs (case_id);
create index if not exists idx_audit_logs_user_id on audit_logs (user_id);

alter table audit_logs enable row level security;

drop policy if exists "users_insert_own_audit" on audit_logs;
drop policy if exists "admin_read_audit" on audit_logs;

-- App tự insert log "view" khi NVXH mở 1 ca (client-side, xem selectCase() trong main.js) —
-- chỉ được ghi log của CHÍNH MÌNH. Không có policy UPDATE/DELETE nào ở đây (không cấp "for
-- all") — không ai (kể cả chủ log) sửa/xóa được log đã ghi, đảm bảo tính toàn vẹn audit trail.
create policy "users_insert_own_audit" on audit_logs
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

-- Chỉ admin (theo email, khớp cơ chế admin duy nhất app đang dùng) mới đọc được audit log —
-- đây là công cụ giám sát/tuân thủ, không phải thứ NVXH thường cần xem lại của người khác.
create policy "admin_read_audit" on audit_logs
  for select to authenticated
  using (
    (select email from auth.users where id = (select auth.uid())) = 'hangcong.nguyen@thaodancenter.org.vn'
  );

-- Trigger tự ghi log CREATE/EDIT/DELETE khi có thay đổi trên cases_v2 (kể cả sửa trực tiếp qua
-- SQL Editor, không chỉ qua app) — bổ sung cho phần "view" mà app tự ghi ở tầng JS.
-- SECURITY DEFINER để insert luôn thành công bất kể ai/thế nào gây ra thay đổi (kể cả khi
-- auth.uid() là NULL — VD: admin chạy UPDATE trực tiếp trong SQL Editor, không có phiên đăng
-- nhập app) — nếu không, trigger sẽ làm THẤT BẠI toàn bộ câu lệnh UPDATE/DELETE gốc trên
-- cases_v2 mỗi khi có ai thao tác ngoài luồng app bình thường.
create or replace function _log_case_audit()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  insert into audit_logs (user_id, case_id, action)
  values (
    auth.uid(),
    coalesce(new.id, old.id),
    case tg_op when 'INSERT' then 'create' when 'UPDATE' then 'edit' when 'DELETE' then 'delete' end
  );
  return coalesce(new, old);
end;
$$;

-- Hàm này chỉ dùng làm trigger handler (Postgres tự gọi khi có DML, không cần EXECUTE để
-- trigger chạy) — thu hồi quyền gọi trực tiếp qua RPC để không lặp lại cảnh báo "Public/
-- Signed-In Users Can Execute SECURITY DEFINER Function" như is_admin()/check_stale_cases()
-- trước đây.
revoke execute on function _log_case_audit() from public;
revoke execute on function _log_case_audit() from anon;
revoke execute on function _log_case_audit() from authenticated;

drop trigger if exists trg_log_case_audit on cases_v2;
create trigger trg_log_case_audit
  after insert or update or delete on cases_v2
  for each row execute function _log_case_audit();
