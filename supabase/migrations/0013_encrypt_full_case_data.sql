-- Mã hóa toàn bộ khối JSONB "data" trong cases_v2 (chứa mọi chi tiết ca — họ tên, gia đình,
-- đánh giá, kế hoạch...). Khác với 0012 (chỉ 2 cột phẳng child_name/child_dob mà app không đọc
-- lại), khối "data" này được TOÀN BỘ app đọc/ghi liên tục — main.js gọi RPC mã hóa/giải mã ở
-- đúng 2-3 chỗ (saveCases/saveOneCase khi ghi, initStorage khi đọc), mọi chỗ khác trong app vẫn
-- thao tác trên object JS thường (đã giải mã sẵn trong bộ nhớ) — không đổi gì thêm.
--
-- Vẫn GIỮ cột "data" (JSONB plaintext) song song làm dự phòng — nếu RPC mã hóa/giải mã lỗi
-- (VD: quên tạo secret Vault, mất mạng), app tự động dùng lại "data" plaintext, không mất dữ
-- liệu. Cột "data" có thể xóa hẳn sau khi dùng ổn định một thời gian (không làm trong lần này).
--
-- ═══ DÙNG CHUNG SECRET "case_encryption_key" ĐÃ TẠO Ở MIGRATION 0012 ═══
-- Nếu chưa chạy 0012 / chưa tạo secret, chạy lệnh sau riêng (không lưu vào git) trước:
--   select vault.create_secret('<chuỗi bí mật dài ngẫu nhiên>', 'case_encryption_key');

create extension if not exists pgcrypto;

alter table if exists cases_v2 add column if not exists data_enc text;

-- RPC cho client gọi trực tiếp (không phải trigger) — client cần encrypt TRƯỚC khi upsert và
-- decrypt SAU khi select, vì Postgres không có cách "tự động" biến đổi cột JSONB qua lại giữa
-- 2 dạng plaintext/mã hóa một cách trong suốt như với 1 cột text đơn giản.
create or replace function encrypt_case_data(p_data jsonb)
returns text
security definer
set search_path = public, extensions
language plpgsql
as $$
declare
  _key text;
begin
  select decrypted_secret into _key from vault.decrypted_secrets where name = 'case_encryption_key' limit 1;
  if _key is null then
    raise exception 'Chưa tạo secret "case_encryption_key" trong Supabase Vault — xem hướng dẫn đầu migration 0012/0013';
  end if;
  return encode(pgp_sym_encrypt(p_data::text, _key), 'base64');
end;
$$;

create or replace function decrypt_case_data(p_enc text)
returns jsonb
security definer
set search_path = public, extensions
language plpgsql
as $$
declare
  _key text;
begin
  if p_enc is null then return null; end if;
  select decrypted_secret into _key from vault.decrypted_secrets where name = 'case_encryption_key' limit 1;
  if _key is null then
    raise exception 'Chưa tạo secret "case_encryption_key" trong Supabase Vault — xem hướng dẫn đầu migration 0012/0013';
  end if;
  return pgp_sym_decrypt(decode(p_enc, 'base64'), _key)::jsonb;
end;
$$;

-- Khác với hàm trigger (is_admin, check_stale_cases, _encrypt_case_identity_fields) — 2 hàm
-- này CẦN được gọi trực tiếp qua RPC từ client, nên chỉ cấp cho "authenticated", không cấp
-- "anon"/"public".
revoke execute on function encrypt_case_data(jsonb) from public, anon;
grant execute on function encrypt_case_data(jsonb) to authenticated;
revoke execute on function decrypt_case_data(text) from public, anon;
grant execute on function decrypt_case_data(text) to authenticated;
