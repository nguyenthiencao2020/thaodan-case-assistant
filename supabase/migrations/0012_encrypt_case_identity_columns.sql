-- Mã hóa 2 cột định danh rõ nhất trong cases_v2: child_name, child_dob.
-- App KHÔNG BAO GIỜ đọc lại 2 cột này (initStorage() chỉ select "id, data, user_id" — xem
-- src/js/main.js) — chúng chỉ được ghi lúc lưu ca, dự phòng cho tra cứu/báo cáo sau này.
-- Vì vậy mã hóa 2 cột này KHÔNG ảnh hưởng bất kỳ tính năng nào của app đang chạy — an toàn
-- tuyệt đối kể cả với người dùng đang hoạt động, khác với việc mã hóa khối JSONB "data" chính
-- (nơi TOÀN BỘ app đọc/ghi liên tục — cố tình CHƯA làm, rủi ro cao hơn hẳn).
--
-- ═══ BƯỚC BẮT BUỘC TRƯỚC KHI CHẠY FILE NÀY ═══
-- Tạo khóa mã hóa trong Supabase Vault — chạy lệnh dưới đây RIÊNG (không chạy chung với phần
-- migration bên dưới, và KHÔNG lưu lệnh này vào git vì nó chứa khóa bí mật thật):
--
--   select vault.create_secret('<THAY-BẰNG-CHUỖI-BÍ-MẬT-DÀI-NGẪU-NHIÊN-CỦA-BẠN>', 'case_encryption_key');
--
-- Chỉ chạy 1 lần. Nếu chạy lại migration này về sau, phần dưới không đụng tới secret đã tạo.

create extension if not exists pgcrypto;

create or replace function _encrypt_case_identity_fields()
returns trigger
security definer
set search_path = public, extensions
language plpgsql
as $$
declare
  _key text;
begin
  select decrypted_secret into _key from vault.decrypted_secrets where name = 'case_encryption_key' limit 1;
  if _key is null then
    raise exception 'Chưa tạo secret "case_encryption_key" trong Supabase Vault — xem hướng dẫn trong migration 0012';
  end if;
  if new.child_name is not null and new.child_name <> '' then
    new.child_name := encode(pgp_sym_encrypt(new.child_name, _key), 'base64');
  end if;
  if new.child_dob is not null and new.child_dob <> '' then
    new.child_dob := encode(pgp_sym_encrypt(new.child_dob, _key), 'base64');
  end if;
  return new;
end;
$$;

-- Trigger tự chạy, không cần quyền EXECUTE trực tiếp — thu hồi ngay để không lộ ra RPC công khai.
revoke execute on function _encrypt_case_identity_fields() from public, anon, authenticated;

drop trigger if exists trg_encrypt_case_identity on cases_v2;
create trigger trg_encrypt_case_identity
  before insert or update on cases_v2
  for each row execute function _encrypt_case_identity_fields();

-- Lưu ý: vì app không đọc lại 2 cột này nên KHÔNG cần hàm giải mã cho luồng hoạt động bình
-- thường. Nếu sau này cần tra cứu (VD: admin tìm theo tên trẻ), viết hàm giải mã riêng, chỉ
-- cấp quyền cho admin, dùng cùng "case_encryption_key" trong Vault.
