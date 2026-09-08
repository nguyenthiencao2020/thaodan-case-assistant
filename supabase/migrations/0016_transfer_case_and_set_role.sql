-- Bàn giao ca cho NVXH khác, và gán vai trò/nhóm cho người dùng.
--
-- ══ VÌ SAO CẦN ══
-- Ca gắn cứng với người tạo: policy "users_own_cases" trên cases_v2 là
--     auth.uid() = user_id
-- nên nhân sự nghỉ việc, nghỉ phép dài hay luân chuyển địa bàn thì ca của họ KHÔNG chuyển được
-- cho ai. Trưởng nhóm (policy "team_leader_view_team_cases" ở 0011) chỉ XEM được, không sửa.
-- Trong thực tế quản lý ca CTXH thì bàn giao là việc bình thường, và bỏ ngỏ nó nghĩa là tới lúc
-- có người nghỉ thì hoặc phải nhờ kỹ thuật chạy SQL tay, hoặc phải nhập lại cả hồ sơ.
--
-- Việc gán role/team cũng vậy: 0011 đã dựng xong cơ chế trưởng nhóm ở tầng dữ liệu nhưng chưa
-- có màn hình nào gán được, nên tới giờ vẫn phải update bằng SQL Editor.
--
-- ══ CÁCH LÀM ══
-- Hai hàm SECURITY DEFINER. Chúng cần đọc auth.users (để đổi email thành uid) và ghi vào dòng
-- mà người gọi sắp KHÔNG còn quyền nữa — hai việc mà RLS của người gọi không cho phép, nên phải
-- là SECURITY DEFINER. Bù lại, mọi điều kiện được kiểm NGAY TRONG hàm, không dựa vào giao diện.
--
-- Đặt trong schema public (khác với các hàm nội bộ ở schema private) vì app phải gọi qua
-- PostgREST /rest/v1/rpc/... — PostgREST chỉ thấy schema được expose. Đây là cùng cách đã làm
-- với encrypt_case_data / decrypt_case_data ở 0013.
--
-- KHÔNG đổi một policy nào hiện có. Chỉ CỘNG THÊM hai hàm.

-- ── 1) Sổ ghi bàn giao ────────────────────────────────────────────────────────────────────
-- Ghi ở tầng DB, không phải trong JSON của ca: sau khi bàn giao thì người giao mất quyền ghi
-- lên dòng ca đó, nên nếu chỉ ghi trong JSON thì không ai chứng minh được ai đã giao cho ai.
-- Đây là hồ sơ bảo vệ trẻ — chuỗi trách nhiệm phải truy được.
create table if not exists case_transfers (
  id          bigserial primary key,
  case_id     text        not null,
  from_user   uuid        not null,
  to_user     uuid        not null,
  from_email  text,
  to_email    text,
  reason      text        not null,
  at          timestamptz not null default now()
);

create index if not exists case_transfers_case_idx on case_transfers (case_id, at desc);

alter table case_transfers enable row level security;

-- Chỉ hai đầu của lần bàn giao và super admin đọc được. Không ai INSERT/UPDATE/DELETE trực tiếp
-- được — chỉ hàm transfer_case (SECURITY DEFINER) mới ghi, nên sổ không sửa lại được từ app.
drop policy if exists "transfers_read_own" on case_transfers;
create policy "transfers_read_own" on case_transfers
  for select to authenticated
  using (from_user = (select auth.uid()) or to_user = (select auth.uid())
         or private.is_super_admin());

-- ── 2) Bàn giao ca ────────────────────────────────────────────────────────────────────────
create or replace function transfer_case(
  p_case_id  text,
  p_to_email text,
  p_reason   text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_me      uuid := auth.uid();
  v_owner   uuid;
  v_to      uuid;
  v_myemail text;
begin
  if v_me is null then
    raise exception 'Chưa đăng nhập';
  end if;

  -- Lý do là BẮT BUỘC, kiểm ở đây chứ không chỉ ở giao diện: bàn giao hồ sơ bảo vệ trẻ mà không
  -- ai biết vì sao thì tới lúc giám sát hỏi lại là không trả lời được.
  if p_reason is null or length(btrim(p_reason)) < 10 then
    raise exception 'Phải ghi lý do bàn giao (ít nhất 10 ký tự)';
  end if;

  select c.user_id into v_owner from public.cases_v2 c where c.id = p_case_id;
  if v_owner is null then
    raise exception 'Không tìm thấy ca %', p_case_id;
  end if;

  -- Chỉ CHỦ ca hiện tại hoặc super admin được bàn giao. Trưởng nhóm chỉ xem, không được giao ca
  -- của người khác — đó là quyết định về quyền, muốn đổi thì phải sửa migration, không sửa app.
  if v_owner <> v_me and not private.is_super_admin() then
    raise exception 'Chỉ chủ ca hiện tại hoặc quản trị mới bàn giao được ca này';
  end if;

  select u.id into v_to from auth.users u where lower(u.email) = lower(btrim(p_to_email));
  if v_to is null then
    raise exception 'Chưa có tài khoản nào dùng email %. Người nhận phải đăng nhập app ít nhất một lần trước khi nhận ca.', p_to_email;
  end if;
  if v_to = v_owner then
    raise exception 'Ca đang thuộc chính người này rồi';
  end if;

  select u.email into v_myemail from auth.users u where u.id = v_owner;

  update public.cases_v2 set user_id = v_to, updated_at = now() where id = p_case_id;

  -- Tệp đính kèm đi theo ca, nếu không thì người nhận mở ca ra mà không thấy giấy tờ đã chụp.
  update public.case_files set user_id = v_to where case_id = p_case_id;

  insert into public.case_transfers (case_id, from_user, to_user, from_email, to_email, reason)
  values (p_case_id, v_owner, v_to, v_myemail, lower(btrim(p_to_email)), btrim(p_reason));

  return jsonb_build_object('ok', true, 'to_user', v_to, 'to_email', lower(btrim(p_to_email)));
end;
$$;

revoke execute on function transfer_case(text, text, text) from public, anon;
grant  execute on function transfer_case(text, text, text) to authenticated;

-- ── 3) Gán vai trò và nhóm ────────────────────────────────────────────────────────────────
-- Chỉ super admin. Bộ giá trị role phải khớp ràng buộc profiles_role_check (xem 0015).
create or replace function set_user_role(
  p_email   text,
  p_role    text,
  p_team_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid;
begin
  if not private.is_super_admin() then
    raise exception 'Chỉ quản trị mới gán được vai trò';
  end if;
  if p_role not in ('officer', 'team_leader', 'admin') then
    raise exception 'Vai trò không hợp lệ: % (chỉ officer | team_leader | admin)', p_role;
  end if;

  select u.id into v_uid from auth.users u where lower(u.email) = lower(btrim(p_email));
  if v_uid is null then
    raise exception 'Chưa có tài khoản nào dùng email %', p_email;
  end if;

  -- Người dùng có thể chưa có dòng profiles nếu chưa từng lưu gì.
  insert into public.profiles (id, role, team_id)
  values (v_uid, p_role, nullif(btrim(coalesce(p_team_id, '')), ''))
  on conflict (id) do update
    set role = excluded.role, team_id = excluded.team_id;

  return jsonb_build_object('ok', true, 'id', v_uid, 'role', p_role,
                            'team_id', nullif(btrim(coalesce(p_team_id, '')), ''));
end;
$$;

revoke execute on function set_user_role(text, text, text) from public, anon;
grant  execute on function set_user_role(text, text, text) to authenticated;

-- ── Kiểm tra sau khi chạy ─────────────────────────────────────────────────────────────────
-- 1) Người nhận PHẢI đăng nhập app ít nhất một lần trước đó (để có dòng trong auth.users),
--    nếu không hàm báo lỗi rõ ràng thay vì chuyển vào hư không.
-- 2) Thử bàn giao một ca thử:
--      select transfer_case('<case id>', 'nguoinhan@thaodancenter.org.vn', 'NVXH phụ trách nghỉ phép dài');
--    → chủ cũ mở app phải KHÔNG còn thấy ca đó; người nhận đăng nhập phải thấy.
-- 3) Sổ bàn giao:
--      select case_id, from_email, to_email, reason, at from case_transfers order by at desc;
-- 4) Gán trưởng nhóm (chỉ tài khoản admin chạy được):
--      select set_user_role('truongnhom@thaodancenter.org.vn', 'team_leader', 'nhom-1');
--      select set_user_role('nvxh@thaodancenter.org.vn',       'officer',     'nhom-1');
--    Rồi gán nhóm cho ca (app có, hoặc):
--      update cases_v2 set team_id = 'nhom-1' where id = '<case id>';
--    Policy "team_leader_view_team_cases" (0011) đòi team_id KHÔNG NULL ở cả ca và profile.
