# Thảo Đàn AI Case Assistant

Công cụ hỗ trợ Nhân viên Công tác Xã hội (NVXH) tại Thảo Đàn SSC quản lý ca bảo vệ trẻ em theo quy trình 5 giai đoạn (Tiếp cận → Vãng gia → Kế hoạch → Tiến trình → Kết thúc), có AI hỗ trợ trích xuất form và tư vấn chuyên môn.

Hai trong năm giai đoạn **lặp nhiều lần** trong một ca: **GĐ2 Vãng gia** (mỗi buổi vãng gia là
một phúc trình riêng, đánh số "Lần vãng gia thứ N", in ra mỗi buổi một phiếu) và **GĐ4 Tiến
trình** (mỗi buổi theo dõi nối thêm bản ghi vào Form 5/6). Ba giai đoạn còn lại chạy một lần;
chạy lại là sửa chứ không tạo bản mới. Ở cả hai giai đoạn lặp, **ở lại giai đoạn đó** và bấm
phân tích lại cho mỗi buổi — chỉ bấm "Hoàn thành" khi thật sự chuyển bước.

## Kiến trúc

Vanilla JS (không framework, không bundler cho `main.js`) + Vite (chỉ dùng cho dev server) + Vercel Serverless Functions + Supabase (Postgres + Auth + Storage).

```
index.html              # 1 trang duy nhất, load 4 file JS qua <script> thường (không phải module)
                        # + bộ 45 icon nét dạng <symbol> nhúng sẵn ngay sau <body>
src/js/config.js        # Hằng số, STAGE_CONFIG, công tắc FEATURES
src/js/prompts.js       # Toàn bộ system prompt gửi cho AI
src/js/utils.js         # Hàm tiện ích (esc, escAttr, deepMerge, showNotif...)
src/js/main.js          # Toàn bộ logic app (~6900 dòng)
src/css/main.css        # Design system — biến màu, thang chữ, vùng bấm tối thiểu
api/chat.js             # Proxy gọi Groq — yêu cầu Supabase access token
api/rag.js              # Proxy tìm tài liệu liên quan (pgvector) — yêu cầu token
api/_auth.js            # Helper xác thực token dùng chung cho các route trên
supabase/migrations/    # Toàn bộ migration SQL, đánh số thứ tự — xem bên dưới
docs/                   # Tài liệu nghiệp vụ CTXH cho AI học (RAG) — xem docs/README.md
```

**Lưu ý quan trọng:** `main.js` không có bước build/bundler thật (Vite chỉ chạy dev server; `npm run build` không nhúng được các file `<script>` thường). Deploy lên Vercel dùng `buildCommand: "npm install"` + `outputDirectory: "."` — serve thẳng source, không qua bước build. `.vercelignore` loại trừ `docs/`, `supabase/`, `scripts/`, `*.bak` khỏi việc bị public hóa.

## Cài đặt & chạy dev

```bash
npm install
npm run dev
```

## Trạng thái triển khai (cập nhật 07/09/2026)

Ghi lại để phiên sau không phải đoán. Cập nhật bảng này mỗi khi cấu hình đổi.

| Hạng mục | Trạng thái |
|---|---|
| Code trên `main` | ✅ đầy đủ |
| 15 migration Supabase `0001`→`0015` | ✅ đã chạy hết (`0014`, `0015` xác nhận trên DB ngày 07/09/2026) |
| Khóa Vault `case_encryption_key` | ✅ đã tạo — kiểm chứng mã hóa/giải mã vòng tròn OK |
| Mã hóa ca cũ | ✅ 4/4 ca có `data_enc`, 0 ca còn plaintext |
| Vercel: `GROQ_KEY_1/2/3`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_ANON_KEY` | ✅ đã khai |
| Vercel: `OPENAI_API_KEY` | ⏸ **HOÃN** — tổ chức chưa có khóa OpenAI |
| GitHub Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` | ✅ đã khai |
| GitHub Secrets: `OPENAI_API_KEY` | ⏸ **HOÃN** — cùng lý do |
| Kho tri thức (RAG) đã nạp | ⏸ **HOÃN** cùng với khóa OpenAI — Action tự bỏ qua và vẫn báo xanh |
| `nguon-luc/danh-ba-nguon-luc.md` | ⬜ còn khung mẫu, đang chờ dữ liệu thật từ tổ chức (làm được độc lập, không cần khóa OpenAI) |
| `docs/phap-ly/can-cu-phap-ly.md` | ⬜ còn khung mẫu |
| Hồ sơ đánh giá tác động NĐ 13/2023 | ⬜ việc của tổ chức, cần tham vấn pháp lý |

### Hai tính năng đang HOÃN vì chưa có khóa OpenAI

Tổ chức chưa có khóa OpenAI, nên hai tính năng dùng nó đều đã được xử lý gọn để **không gây nhiễu**:

| Tính năng | Trạng thái khi không có khóa |
|---|---|
| Kho tri thức (RAG) | `api/rag.js` trả `{chunks:[]}` — app chạy bình thường, chỉ là AI trả lời bằng kiến thức chung. GitHub Action **tự bỏ qua và thoát 0** nên không đỏ; log in cảnh báo rõ |
| Đọc ảnh trang sổ tay | **ĐÃ XOÁ** (08/09/2026) — luồng duy nhất gửi tên thật/địa chỉ chưa che ra ngoài; cần dựng lại thì lấy trong git |

**Không phải việc cần làm gấp.** Bật lại khi nào tổ chức có khóa: khai `OPENAI_API_KEY` ở Vercel và
GitHub Secrets, rồi bật `FEATURES.rag`. Chi tiết trong
[`docs/README.md`](docs/README.md).

Nếu sau này bật RAG, **cách kiểm nó chạy thật** (vì nó không báo lỗi): phân tích một ca rồi hỏi
trong chat *"Quy trình giai đoạn 2 của Thảo Đàn yêu cầu những gì?"* — trả lời đúng **SLA 72 giờ**
và tên biểu mẫu bắt buộc là đang chạy.

### Đang chạy đủ, không phụ thuộc khóa OpenAI

Phân tích ca và chat (Groq) · 10 biểu mẫu và bộ hồ sơ Word · truy vết nguồn · dấu BẢN NHÁP và bước
xác nhận · ẩn danh tên/SĐT/CCCD/email/địa chỉ · tra cứu tiền lệ · nhập bằng giọng nói · xuất
Word/PDF có chữ ký và số trang · công văn chuyển gửi · mã hóa hồ sơ · audit log.

Nói cách khác: **giá trị cốt lõi của tool không cần khóa OpenAI.**

## Biến môi trường — phải khai ở HAI nơi khác nhau

Đây là chỗ nhầm phổ biến nhất: **Vercel và GitHub hoàn toàn không thấy biến của nhau**. Cùng giá
trị nhưng khai riêng ở mỗi nơi, không thay thế được cho nhau.

### Vercel → Project Settings → Environment Variables (app đang chạy ĐỌC dữ liệu)

| Biến | Dùng ở đâu | Ghi chú |
|---|---|---|
| `GROQ_KEY_1`, `GROQ_KEY_2`, `GROQ_KEY_3` | `api/chat.js` | Round-robin giữa 3 key để giảm rate limit. Model hiện dùng: `openai/gpt-oss-120b`. |
| `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` | `api/rag.js` | Service key — **không** để lộ ra client. |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `api/_auth.js` | Xác thực token người dùng gửi lên từ client. Thiếu biến này thì `requireUser()` chặn mọi lời gọi API. |
| `OPENAI_API_KEY` | `api/rag.js` | Tạo embedding để truy xuất kho tri thức nội bộ. Chưa có khóa nên `FEATURES.rag` đang tắt — và khi tắt thì app KHÔNG gọi `/api/rag` nữa, xem ghi chú trong `config.js`. |

Thêm/sửa biến xong **phải bấm Redeploy** — Vercel chỉ nạp biến lúc build, không áp cho bản đã build sẵn.

### GitHub → Settings → Secrets and variables → **Actions** (Action GHI vào kho tri thức)

| Secret | Vì sao cần |
|---|---|
| `SUPABASE_URL` | `scripts/index-docs.js` ghi vào bảng `documents` |
| `SUPABASE_SERVICE_KEY` | Phải là **service_role**, không phải anon — anon không có quyền ghi |
| `OPENAI_API_KEY` | Tạo embedding cho từng mẩu tài liệu |

Khai ở **Repository secrets**, KHÔNG phải Environments — workflow không khai báo `environment:` nên
không thấy secret của Environments. Thiếu secret thì Action dừng ngay và **app không báo gì cho
người dùng biết**; script nêu rõ thiếu biến nào trong log.

Client-side (`src/js/main.js`) tự gắn `Authorization: Bearer <token>` (lấy từ session Supabase hiện tại) vào mọi request tới `/api/chat` và `/api/rag` — 2 route này từ chối request không có token hợp lệ.

## Supabase — migrations

Chạy theo đúng thứ tự trong `supabase/migrations/`, dán từng file vào **SQL Editor** và Run:

| File | Nội dung |
|---|---|
| `0001_rag_documents.sql` | Bảng `documents` + hàm `match_documents` cho RAG |
| `0002_admin_rls.sql` | RLS gốc cho `cases_v2` (user thấy ca của mình, admin thấy tất cả) |
| `0003` – `0009` | Rà soát & vá RLS toàn diện: bật RLS cho `case_files`/`notifications`/`case_stats` (view), tối ưu hiệu năng (`(select auth.uid())`), dọn policy trùng/cũ, khóa `search_path` cho hàm `SECURITY DEFINER`, thu hồi quyền gọi RPC trực tiếp, dời `is_admin()` khỏi schema `public` |
| `0010_audit_logs.sql` | Bảng `audit_logs` — ghi ai xem/tạo/sửa/xóa ca nào |
| `0011_rbac_team_leader.sql` | Role `officer/team_leader/admin` + `team_id` — mặc định vô hiệu tới khi có ai được gán |
| `0012_encrypt_case_identity_columns.sql` | Mã hóa 2 cột `child_name`/`child_dob` trong `cases_v2`. **Cần tạo secret Vault trước** (xem comment đầu file), không lưu khóa vào git |
| `0013_encrypt_full_case_data.sql` | Mã hóa **toàn bộ** khối JSONB `data` qua RPC `encrypt_case_data`/`decrypt_case_data`. Vẫn giữ cột `data` plaintext song song làm dự phòng — nếu giải mã lỗi, app tự dùng lại, không bao giờ mất quyền xem ca. Dùng chung secret Vault với `0012` |
| `0014_fix_admin_email_policy_permission.sql` | **Sửa lỗi `permission denied for table users` khi lưu ca lần thứ hai.** Các policy admin từ `0003`→`0010` đọc trực tiếp `auth.users`, mà role `authenticated` không có quyền SELECT trên bảng đó; `INSERT … ON CONFLICT DO UPDATE` lại đòi cả policy SELECT nên câu lệnh lưu thất bại. Migration bọc phép so email vào `private.is_super_admin()` (SECURITY DEFINER) rồi dựng lại 5 policy. Không đổi dữ liệu, không đổi ai xem được ca nào |
| `0015_fix_profiles_role_values.sql` | **Sửa lỗi của `0011`.** Đã chạy: `convalidated = true`, `role = 'officer'` cho cả 2 tài khoản. `alter table … add column if not exists role` bị Postgres bỏ qua vì cột `role` đã có sẵn (giá trị `'user'`) **và đã có ràng buộc `profiles_role_check` riêng của schema gốc, với bộ giá trị không chứa `'officer'`/`'team_leader'`**, nên cả `default 'officer'` lẫn ràng buộc `check` mới đều không được tạo — khiến `private.is_team_leader()` không bao giờ khớp và cơ chế trưởng nhóm coi như không tồn tại. Migration **bỏ ràng buộc cũ trước**, rồi chuẩn hóa `'user'` → `'officer'`, đặt lại DEFAULT/NOT NULL và tạo lại `check` bằng `add constraint` (đảo thứ tự là lỗi 23514). Chỉ cần chạy nếu định dùng vai trưởng nhóm |
| `0016_transfer_case_and_set_role.sql` | **Bàn giao ca** cho NVXH khác (hàm `transfer_case`, sổ `case_transfers` ghi ở tầng DB nên không sửa lại được từ app) và **gán vai trò/nhóm** (`set_user_role`) — trước đó phải chạy SQL tay. Lý do bàn giao là **bắt buộc**, kiểm ngay trong hàm chứ không chỉ ở giao diện |
| `0017_admin_by_role.sql` | **Quyền "xem tất cả ca" chuyển từ email cứng sang `profiles.role = 'admin'`** — tổ chức tự gán/thu quyền trong app, không phải sửa code, và đọc bảng là biết ai có quyền gì. Giữ một email dự phòng trong hàm để không bao giờ mất hết quyền quản trị. Kèm bù dòng `profiles` cho tài khoản còn thiếu (4/6 tài khoản chưa có) và phân quyền theo yêu cầu 09/09/2026 |

### Bước làm tay không nằm trong migration nào

Khóa mã hóa cố tình không đưa vào git — để trong repo thì ai đọc được code là giải mã được hồ sơ.
Chạy riêng **một lần**, không lưu câu lệnh này vào git:

```sql
select vault.create_secret('<chuỗi dài ngẫu nhiên, giữ kín>', 'case_encryption_key');
```

Kiểm chứng (phải ra `{"thu": 1}` — chứng minh mã hóa VÀ giải mã cùng chạy bằng đúng một khóa):

```sql
select decrypt_case_data(encrypt_case_data('{"thu":1}'::jsonb));
```

Mã hóa ngược các ca đã lưu từ trước (cột `data` gốc giữ nguyên làm dự phòng):

```sql
update cases_v2 set data_enc = encrypt_case_data(data) where data_enc is null and data is not null;
```

⚠️ **Mất khóa là mất hồ sơ**, không ai cứu được. Lưu vào trình quản lý mật khẩu của tổ chức và cho
ít nhất 2 người biết chỗ lấy.

**Cơ chế admin hiện tại:** hard-code theo email (`ADMIN_EMAIL` trong `src/js/main.js`, khớp với `hangcong.nguyen@thaodancenter.org.vn` trong các policy SQL) — nếu đổi admin, sửa cả 2 chỗ.

## Phân quyền — ai xem được ca nào

| Vai | Xem được | Sửa/xóa | Xác định bằng |
|---|---|---|---|
| CBXH (`officer`) | chỉ ca của chính mình | ✅ ca của mình | `cases_v2.user_id = auth.uid()` |
| Quản lý (`admin`) | **toàn bộ ca của mọi người** | ❌ chỉ xem | `profiles.role = 'admin'` |
| Trưởng nhóm (`team_leader`) | ca của mình **+ ca cùng `team_id`** | ❌ chỉ xem | `profiles.role` + `profiles.team_id` |

Từ migration `0017`, quyền quản lý là **dữ liệu**, không còn là email viết cứng. Gán/thu quyền
ngay trong app: menu **⋯ → "Gán vai trò & nhóm (quản trị)"**, hoặc bằng SQL (xem dưới). Người
được gán tải lại trang là có hiệu lực — **không cần deploy**.

Vẫn còn **một email dự phòng** trong `private.is_super_admin()` và `ADMIN_EMAIL`
(`hangcong.nguyen@thaodancenter.org.vn`). Nó tồn tại để nếu ai lỡ tay hạ hết `role = 'admin'` thì
còn một đường vào gán lại — mất hết quyền quản trị thì không ai vào sửa được. **Hai chỗ đó phải
luôn khớp nhau**; bộ kiểm thử `role` có một kiểm tra đối chiếu đúng việc này.

Phân quyền đang áp dụng (yêu cầu của tổ chức 09/09/2026): `hangcong.nguyen@thaodancenter.org.vn` ·
`ngan.lee@thaodancenter.org.vn` · `thien.nguyen@asif.foundation` là **quản lý**; còn lại là
**CBXH**. Không dùng nhóm — cơ chế trưởng nhóm vẫn còn đó cho lúc chia địa bàn.

Bốn điều dễ hiểu sai, đã trả giá để biết:

1. **Quản lý xem được nhưng KHÔNG sửa được ca người khác** (`admin_all_cases` là `FOR SELECT`,
   còn `users_own_cases` là `FOR ALL` trên ca của mình). Quản lý mở ca của CBXH khác rồi bấm Lưu
   thì DB từ chối — giao diện hiện chưa nói trước việc này.
2. **Tài khoản không có dòng `profiles` thì mọi lệnh `update profiles` sửa 0 dòng và im lặng.**
   Đã gặp thật: 4 trong 6 tài khoản chưa có dòng nào, nên lệnh gán quyền "chạy xong" mà không đổi
   gì. Dùng `insert … on conflict` hoặc bù dòng trước (migration `0017` làm sẵn).
3. **Trưởng nhóm chỉ có hiệu lực khi gán đủ 3 chỗ**: `role` và `team_id` cho người, `team_id` cho
   ca. Policy đòi `team_id IS NOT NULL` ở cả hai, mà trong SQL `NULL = NULL` không bao giờ đúng.
4. **`set_user_role()` KHÔNG chạy được trong SQL Editor** — nó kiểm người gọi qua `auth.uid()`, mà
   SQL Editor không có ai đăng nhập nên hàm coi như không phải quản trị và báo lỗi. Hàm đó dành
   cho app; trong SQL Editor thì sửa thẳng bảng.

Gán quyền bằng SQL (chạy được trong SQL Editor, an toàn khi chạy lại):

```sql
-- Quản lý (xem tất cả ca)
insert into profiles (id, role, team_id)
select id, 'admin', null from auth.users where lower(email) = 'nguoi@thaodancenter.org.vn'
on conflict (id) do update set role = 'admin', team_id = null;

-- CBXH (chỉ ca của mình)
insert into profiles (id, role, team_id)
select id, 'officer', null from auth.users where lower(email) = 'nguoi@thaodancenter.org.vn'
on conflict (id) do update set role = 'officer', team_id = null;

-- Xem ai đang có quyền gì (kể cả người chưa có dòng profiles)
select u.email, coalesce(p.role,'(chưa có dòng profiles)') as role,
       coalesce(p.team_id,'—') as nhom, u.last_sign_in_at::date as dang_nhap_lan_cuoi
from auth.users u left join profiles p on p.id = u.id
order by p.role, u.email;
```

Xem trạng thái thật bất cứ lúc nào:

```sql
select policyname, cmd, qual from pg_policies where tablename = 'cases_v2' order by policyname;
select p.id, u.email, p.role, p.team_id from profiles p join auth.users u on u.id = p.id;
```

**Một điểm cần lưu ý về mã hóa:** `decrypt_case_data(text)` là `SECURITY DEFINER` và cấp `EXECUTE`
cho mọi người đã đăng nhập, tức ai cũng gọi được nó với bất kỳ chuỗi ciphertext nào. Thực tế RLS
vẫn chặn họ đọc `data_enc` của ca người khác nên không có chuỗi để giải; nhưng nếu ciphertext lọt
ra bằng đường khác (bản backup, log, hoặc một lỗi RLS về sau) thì lớp mã hóa không còn chặn được
người đã đăng nhập. Siết được bằng cách thêm kiểm tra chủ sở hữu vào chính hàm đó.

## Tình trạng bảo mật (tính đến phiên rà soát gần nhất)

Đã vá: XSS lưu trữ (hiển thị form/report, import file backup ca), API proxy không xác thực, PII trẻ em gửi gần nguyên văn cho AI, prototype pollution qua lệnh chat sửa form, RLS thiếu/dư trên nhiều bảng, hàm `SECURITY DEFINER` thiếu khóa `search_path`, lộ file nội bộ qua static hosting, race condition mất dữ liệu khi đăng nhập mạng chậm.

Vá ở phiên QA 07/09/2026: **XSS lưu trữ qua tên ca trong bảng thông báo** — đường đọc từ DB đã
`esc()` từ trước nhưng đường dự phòng cục bộ (khi bảng `notifications` rỗng) chèn thẳng
`n.message` vào `innerHTML`, mà message có nhúng tên ca lấy từ `co_ban.ho_ten` do AI trích xuất từ
ghi chép (hoặc từ file backup import vào) — tức nội dung không tin được. Cùng lúc siết `n.id`
trước khi chèn vào thuộc tính `onclick` và `esc(e.message)` ở 2 chỗ hiển thị lỗi.

Vá cùng phiên: **`esc()` không che dấu `"` và `'`** nên chuỗi đặt trong GIÁ TRỊ THUỘC TÍNH HTML bị
cắt ngang ở dấu nháy đầu tiên (một câu như `Trẻ nói "con không sao"` mất phần còn lại và có thể
sinh thuộc tính lạ). Thêm `escAttr()` trong `src/js/utils.js` và áp cho 3 chỗ đang dùng sai.
**`permission denied for table users` khi lưu ca lần thứ hai** — 5 policy admin đọc trực tiếp
`auth.users` mà role `authenticated` không có quyền SELECT trên bảng đó, còn
`INSERT … ON CONFLICT DO UPDATE` lại đòi cả policy SELECT (migration `0014`).

Vá trong các phiên trước đó: lưu thất bại nhưng vẫn báo "Đã lưu" (nay `await` kết quả và hiện
cảnh báo kèm nút Thử lại), ghi chép đang gõ không có lớp bảo vệ nào (nay lưu nháp xuống
`localStorage` mỗi lần gõ), lưu 1 ca nhưng ghi lại toàn bộ ca (nay chỉ ghi ca thực sự đổi), số nhà
và tên đường vẫn gửi nguyên văn cho AI (nay che, giữ phường/quận), và 2 lỗi che tên chỉ lộ ra khi
khai nhiều tên: mọi tên dùng chung một placeholder nên khôi phục sai người, và `\b` của JavaScript
không hiểu chữ có dấu nên tên gọi một chữ phá vỡ từ khác.

**Cố tình chưa làm:**
- **Xem hồ sơ khi mất mạng** — app không cache hồ sơ xuống máy (chỉ có bản nháp ghi chép). Làm được
  nhưng đồng nghĩa hồ sơ trẻ nằm trên máy cá nhân; rủi ro bảo mật có thể lớn hơn lợi ích.
- **Tự tải lại dữ liệu** — `initStorage()` chạy một lần lúc đăng nhập, tab mở cả ngày không thấy
  thay đổi từ máy khác.
- **Bàn giao ca trong giao diện** — RLS gắn ca theo `user_id`; NVXH nghỉ việc thì admin phải sửa
  `user_id` qua SQL Editor. Hàm `_setCaseTeam` có sẵn nhưng chưa có UI.
- **Thùng rác cho ca đã xóa** — `deleteCase()` xóa vĩnh viễn, có hỏi xác nhận nhưng không khôi phục được.
- **Bước duyệt của giám sát ca** — `completeStage()` là tự bấm tự xong, chưa có phê duyệt chuyên môn.
- **SLA theo giai đoạn** — chỉ có khái niệm thô "ca >14/30 ngày chưa cập nhật", chưa theo SOP.

**Yêu cầu môi trường:** app dùng `color-mix()` (12 chỗ, trong đó có nền nút "Phân tích"), `:has()`
và `100dvh` — cần Chrome ≥111 hoặc Safari ≥16.2 (từ 2023). Trình duyệt cũ hơn sẽ mất nền nút.

## Tính năng chính

**Soạn hồ sơ** — giá trị cốt lõi: một lần viết ghi chép văn xuôi sinh ra **139 trường + 6 bảng**
trên 10 biểu mẫu. Nhập bằng cách gõ hoặc bằng **giọng nói** (Web Speech API, miễn phí).

**Kiểm chứng — phân biệt "AI viết" với "người đã kiểm":**
- **Truy vết nguồn**: mỗi ô AI trích xuất được đối chiếu ngược với ghi chép gốc; ô nào không tìm
  thấy căn cứ (≥60% từ khóa) thì gắn cờ `❓ chưa có căn cứ`. NVXH chỉ soi mấy ô đó thay vì đọc lại
  toàn bộ. Đây cũng là cơ chế chặn AI bịa.
- **Dấu BẢN NHÁP**: mọi bản in/xuất khi chưa được NVXH xác nhận đều mang dấu "BẢN NHÁP — NỘI DUNG
  DO AI TRÍCH XUẤT, CHƯA ĐƯỢC NVXH XÁC NHẬN". Chạy phân tích mới thì thu hồi xác nhận.
- Mức rủi ro AI đưa ra được ghi rõ là **"AI gợi ý"**, không phải kết luận chuyên môn; "câu hỏi cần
  khai thác" và "độ tin cậy dữ liệu" đặt TRÊN mọi kết luận của máy.

**Ẩn danh trước khi gửi AI** — tên thật (theo ô NVXH tự khai, placeholder có đánh số theo từng
người), số điện thoại, CCCD, email, số nhà + tên đường; giữ phường/quận để AI hiểu địa bàn. Khôi
phục nguyên văn vào hồ sơ sau khi AI trả kết quả. Ngoại lệ duy nhất: **ảnh sổ tay không che được**
(tên và địa chỉ nằm trong nét chữ) — có bắt xác nhận riêng trước lần dùng đầu.

**Khác:** 5 giai đoạn quản lý ca · chat tư vấn CTXH có RAG · **tra cứu tiền lệ** (tìm ca cũ tương
tự, chạy cục bộ, không gửi gì cho AI) · popup cảnh báo khi AI thấy rủi ro Cao · mã ca tự sinh
`CA-YYYY-MM-STT` · xuất Word/PDF có chữ ký và số trang · **soạn công văn chuyển gửi** từ Form 7 ·
**việc cần làm** (gộp mọi ca, dựng từ ngày tháng đã có trong kế hoạch) · **danh bạ nguồn lực** tra tại chỗ · **in phiếu trắng** mang đi vãng gia · **bàn giao ca** cho NVXH khác · theo dõi sau đóng ca · **đóng ca / mở lại ca bắt buộc ghi lý do** (lưu kèm ngày, người thực hiện
và giai đoạn; xem lại trong trang chi tiết ca) · **xem lại và in lại bản lưu** của từng mốc lịch
sử (buổi vãng gia, bản kế hoạch, lần cập nhật tiến trình) · audit log.

**Giao diện — thiết kế cho NVXH lớn tuổi, dùng trên cả điện thoại:**

| Điểm | Chi tiết |
|---|---|
| Bề rộng cột | Ba cột cố định được nới theo cỡ chữ mới: danh sách biểu mẫu 220→260px (mọi nhãn về một dòng), danh sách ca 270→330px (tên ca không còn bị cắt còn "Nguyễn V…"), hàng 5 mốc giai đoạn xuống 2 hàng |
| Cỡ chữ | Thang chữ đã nâng một bậc toàn app (542 chỗ): sàn 11px cho nhãn nhỏ nhất, thân chữ 15–16px, chữ nền trang 16px. Cỡ chữ trong bản xuất `.docx` **giữ nguyên** Times New Roman 12pt theo quy cách văn bản hành chính |
| Vùng bấm | Sàn 32px ở mọi kích cỡ màn hình, 34–36px trên màn hẹp — người lớn tuổi bấm kém chính xác hơn |
| Icon | Bộ 45 icon nét nhúng sẵn dạng `<symbol>`, `stroke:currentColor` nên tự ăn theo màu chữ, không thêm request nào. Emoji đã bỏ trong khu chat và toàn bộ báo cáo (mỗi hệ điều hành vẽ emoji một kiểu, một sắc độ — đây là thứ làm giao diện trông thô nhất). Cột trái và thanh menu vẫn còn emoji |
| Màu | Bảng màu báo cáo từ 65 giá trị còn 28, gom về **4 họ mang nghĩa**: đỏ = rủi ro · vàng = việc NVXH phải làm · xanh = đạt/an toàn · navy = thông tin chuyên môn. Tím, lam lạc tông, lục lam, cam trước đây chỉ để trang trí |
| Khu chat | Ô nhập và nút gửi gộp thành một composer, textarea tự cao tới 5 dòng; gợi ý còn 3 chip một hàng + nút "n câu khác"; ba lời cảnh báo trùng nhau gộp thành một dòng, toàn văn Điều 45 / Thông tư 35 / chính sách bảo mật nằm trong nút ⓘ. Khung chrome từ 198px còn 114px |
| Thu gọn / mở rộng | 3 trạng thái, nhớ lựa chọn trên máy người dùng. Mở rộng = báo cáo chiếm cả bề ngang (ẩn cột trái); thu gọn = chat còn thanh 44px, cột trái giãn ra. Trên điện thoại thành "báo cáo cả màn hình" / "ô ghi chép cả màn hình" |
| Điện thoại | Header một hàng, các thao tác phụ (Thống kê, Thông báo, Xuất/Nhập JSON, Đăng xuất) dồn vào menu **⋯**; dải mã ca dưới thanh tab để biết đang mở ca nào; nhãn tab bản ngắn để cả 4 tab lọt từ màn 360px |

**Đang tạm tắt** — công tắc `FEATURES` trong `src/js/config.js`, đổi `false`→`true` để bật lại.
Code, modal, endpoint và dữ liệu đã lưu đều còn nguyên, không phải viết lại gì:

| Cờ | Tính năng | Vì sao tắt |
|---|---|---|
| `dass` | Thang đo DASS-21/42 | Chờ thiết kế lại — bộ câu hỏi là bản tự khai ngôi thứ nhất của người lớn, chỉ thẩm định cho ≥17 tuổi, mà màn hình không hỏi ai là người trả lời |
| `genogram` | Sơ đồ phả hệ | Chờ thiết kế lại — thiếu đúng phần cốt lõi là đường quan hệ (thân thiết/xung đột/xa cách/cắt đứt) và không sửa được bằng tay |
| `rag` | Tra cứu tài liệu nội bộ bằng vector | Chưa có `OPENAI_API_KEY` nên `/api/rag` luôn trả 500. Khi tắt thì app KHÔNG gọi nữa — trước đây vẫn gọi và **chờ xong** trước mỗi lần Phân tích và mỗi tin nhắn chat, tốn 1–3 giây khởi động lạnh cho một kết quả rỗng |
| `precedents` | Tra cứu tiền lệ (ca cũ tương tự) | Dưới khoảng **50 ca đã đóng** thì kết quả là nhiễu; NVXH đọc thấy "ca tương tự" chẳng liên quan là mất niềm tin vào toàn bộ phần gợi ý. Bật lại khi đủ dữ liệu |
| `evalTab` | Tab "Phân tích & Đánh giá tổng hợp" | Báo cáo dài do AI viết cho **giám sát viên**, không phải việc hằng ngày của NVXH, mà chiếm 1 trong 4 tab chính. Tắt cờ thì nó rời hàng tab, vẫn mở được từ menu ⋯ |

**Đã xoá hẳn (không phải tắt cờ):** đọc chữ trong ảnh trang sổ tay (`FEATURES.ocr`, `api/ocr.js`,
nút 📷). Đó là luồng **duy nhất** gửi tên thật và địa chỉ **chưa che** ra ngoài — chúng nằm ngay
trong nét chữ của trang sổ, không regex nào che được. Tổ chức đã quyết tắt vĩnh viễn; để code lại
thì mỗi lần QA vẫn phải kiểm một đường không ai dùng, và luôn còn nguy cơ có người bật cờ mà không
biết hệ quả. Cần dựng lại thì lấy trong git (commit 08/09/2026) và **phải làm lại phần đồng thuận
của thân chủ trước khi bật**.

Nút 🎤 **nhập bằng giọng nói vẫn bật** — dùng Web Speech API sẵn trong Chrome/Edge, miễn phí, và
văn bản đọc ra vẫn đi qua đúng bộ che tên/SĐT/địa chỉ trước khi tới Groq. Với NVXH vừa đi vãng gia
về, kể lại bằng miệng nhanh hơn gõ nhiều.

## Kiểm thử

Không có test tự động trong repo (app là script không module, không có bước build cho `main.js`).
Kiểm thử được viết dưới dạng script Playwright chạy ngoài, dựng máy chủ tĩnh trên `localhost:8899`
và giả lập Supabase + Groq + OpenAI để chạy được toàn bộ luồng mà không cần khóa thật.

**Lần QA gần nhất: 09/09/2026 — 31 bộ, tất cả đạt**, trên 11 khổ máy từ 360px tới 1920px:

| Bộ | Kết quả | Phủ những gì |
|---|---|---|
| Quy trình + logic | 226 kiểm tra, 0 lỗi | 5 giai đoạn, nhánh phụ, truy vết nguồn, dấu BẢN NHÁP, che danh tính, chống mất dữ liệu, XSS, in & xuất, cờ tính năng — xem bảng dưới |
| `desk` | 20/20 trang sạch | 4 tab × 5 khổ desktop (1920 → 1024): tràn ngang/dọc, phần tử vượt mép, nút bị cắt, nút dưới 30px, lỗi JS |
| `mob` | 24/24 trang sạch | 4 tab × 6 khổ điện thoại/tablet (360 → 768): thêm header một hàng, 4 tab lọt bề ngang, dải mã ca, nút ⋯ |
| `chatui` | tất cả đạt | Composer, chip gợi ý (câu hỏi chứa `"` và `'`), 3 trạng thái thu gọn/mở rộng + ghi nhớ, ô nhập tự cao rồi co lại, hộp thoại ⓘ, bảng màu + emoji trong cả 5 giai đoạn báo cáo |
| `mob2` | tất cả đạt | Menu ⋯ (5 mục ≥44px, bấm ra ngoài đóng, mang theo số thông báo), thu gọn/mở rộng trên phone, tab biểu mẫu |
| `contrast` | tất cả đạt | Tương phản WCAG mọi phần tử có chữ, chặn dưới 2.5:1; soi file CSS tìm `var()` trỏ vào biến chưa khai báo mà không có giá trị dự phòng |
| `hover` | 73/73 phần tử | Tương phản ở **cả** trạng thái nghỉ và trỏ chuột — bộ cũ chỉ kiểm lúc đứng yên nên bỏ sót chip gợi ý mất chữ khi hover |
| `pii` | 20/20 đạt | Đường ghi chép → AI → biểu mẫu của SĐT/CCCD/email: che có đánh số, khôi phục nguyên văn, hai số khác nhau không lẫn người, không phá số thường ("bé 12 tuổi"), dung sai khi model sao lại nhãn sai kiểu (`[ sdt_1 ]`, `[SĐT_1]`); `deepMerge` với mảng giàu/nghèo hơn |
| `role` | 24/24 đạt | Quyền quản lý đọc từ `profiles.role`: gán/hạ quyền có hiệu lực ngay không cần sửa code, email dự phòng vẫn vào được khi role bị hạ, đọc vai trò lỗi mạng thì nghiêng về phía ÍT quyền, đăng xuất xoá vai trò; đối chiếu email dự phòng trong migration `0017` phải khớp `ADMIN_EMAIL` trong code |
| `qanew` | 34/34 đạt | Bấm THẬT từng nút của các tính năng mới trong trạng thái đã đăng nhập: mở ca từ danh sách việc (cả ca đang mở và ca đã đóng), tick xong việc, 4 nút trên thanh công cụ form đều tạo được file, dải BẢN NHÁP còn 1 dòng, header/menu ⋯/3 tab, xuất JSON hỏi trước và chỉ hỏi một lần, bàn giao + màn quản trị, không còn vết tích OCR, RAG không gọi mạng. Kèm bắt lỗi JS trong suốt bài kiểm |
| `todo` | 39/39 đạt | "Việc cần làm": dựng đúng việc từ hoạt động kế hoạch + mốc xem xét + lịch theo dõi sau đóng ca; mức độ gấp hiện bằng "thẻ hạn" trên từng dòng (không còn tiêu đề nhóm), mỗi dòng một hành động mở ca, thu gọn được và nhớ lựa chọn; ca đã đóng chỉ lấy lịch theo dõi; hạn không phải ngày cụ thể ("hàng tháng", "2 tuần") thì bỏ qua chứ không bịa hạn; đánh dấu xong lưu vào hồ sơ ca; vùng phải dùng chung — chưa chọn ca thì là danh sách việc, chọn ca thì là chi tiết ca, có nút quay lại |
| `guidelink` | 22/22 đạt | Sổ tay đọc được TRƯỚC khi đăng nhập: link nằm trong khung đăng nhập, bấm mở đúng trang (15 mục, 10 ảnh) và trang đó không đòi đăng nhập; menu ⋯ cũng có mục sổ tay; `/huong-dan` khai trong vercel.json. Câu mô tả tool trên màn đăng nhập phải nói cả việc nó làm (ghi chép → biểu mẫu) và giới hạn (AI gợi ý, NVXH quyết định), và phải nằm trước nút Đăng nhập. **Chặn cái bẫy `.vercelignore`**: đọc thẳng `.vercelignore` rồi khẳng định `_NL_URL` và mọi link trong app KHÔNG trỏ vào thư mục bị loại khỏi bản deploy (đã 404 thật hai lần); sổ tay không chứa email nhân sự thật |
| `login` | 22/22 đạt | Đăng nhập / đăng xuất để lại màn hình SẠCH: không dải "chỉ đọc" hay "ca đã đóng" nào kẹt lại, nút Lưu và Hoàn thành GĐ mở lại được; người khác đăng nhập vào cùng máy KHÔNG thừa hưởng ca của người trước; email chủ ca dài không bị cắt mất đuôi; đã có ca thì vào thẳng tab Danh sách ca, chưa có ca thì ở lại Dashboard; thử đủ mọi đường ra khỏi một ca (+ Ca mới, mở ca khác, xoá ca, bàn giao) |
| `roadmin` | 29/29 đạt | Quản lý mở ca của CBXH khác: dải chỉ đọc hiện ngay ở ĐẦU cột làm việc và nói rõ ca của ai, ô nhập bị khoá, nút Lưu / Hoàn thành GĐ vô hiệu hoá; bấm Lưu thì KHÔNG báo "đã lưu" và KHÔNG xoá bản nháp (tái hiện đúng lỗi đã gặp); phân tích / hoàn thành GĐ / đóng / mở lại / xoá ca / tick việc / đính tài liệu đều bị chặn ở cửa vào; ca của chính mình và ca chưa có chủ không bị ảnh hưởng gì |
| `qa4` | 13/13 đạt | QA sau khi dựng lại bố cục: chèn `<img onerror>` vào tên ca / tên việc không chạy được mã; xoá ca đang xem thì vùng phải trả về danh sách việc; các tab con và nút Xem lại/In lại vẫn chạy sau khi đổi `#cases-main` → `#cases-detail`; thu gọn còn nhớ sau khi qua lại chi tiết ca; hết việc thì khoảng trống trở lại đầy đủ (bắt được lỗi hai đường ra sớm của `renderTodo` không đồng bộ bố cục) |
| `qa5` | 28/28 phép đo | Tương phản (WCAG) và cỡ vùng bấm của mọi phần tử mới trong khối việc, đo trên **cả** máy tính và điện thoại — bắt được 4 chỗ chữ mờ 2.7–3.0:1 dưới ngưỡng 4.5:1 (dòng "thuộc ca nào · hạn ngày nào", chân khối, dòng "chỉ còn việc ở xa", lời mời chọn ca) |
| `handover` | 26/26 đạt | Bàn giao ca: đòi cả email người nhận (đúng dạng) lẫn lý do ≥10 ký tự, ghi sổ TRƯỚC rồi mới gọi chuyển, RPC lỗi thì ca vẫn còn tại máy và hiện nguyên văn lỗi máy chủ, không phải chủ ca thì không mở được hộp thoại; màn gán vai trò chỉ quản trị mở được (gọi trực tiếp cũng chặn) |
| `nl` | 18/18 đạt | Danh bạ nguồn lực đọc từ file .md: bỏ dòng mẫu chưa điền, tìm theo tên/nhóm/số điện thoại, nút Chép; phiếu trắng KHÔNG lẫn dữ liệu ca đang mở và trả dữ liệu ca về nguyên vẹn sau khi in |
| `stbar` | 18/18 đạt | Dải 5 chấm tiến trình phải khớp giữa thẻ ca bên trái và trang chi tiết bên phải — quét đủ 10 tổ hợp (5 giai đoạn × mở/đóng), đọc màu thật đã tính ra chứ không đọc code. Ca đóng ở GĐ4 mà chưa từng tới GĐ5 → GĐ5 xám; ca **đã từng** tới GĐ5 rồi lùi lại (mở lại ca, lùi giai đoạn) → GĐ5 vẫn xanh, đọc bằng chứng từ sổ đóng/mở ca và các mốc ghi chép |
| `vglan` | 14/14 đạt | Đánh số buổi vãng gia qua luồng thật (giả lập AI, gọi `runAnalysis`): buổi đầu ra ĐÚNG 1 phiếu, bấm Phân tích lại cùng nội dung thì cập nhật phiếu đó chứ không sinh phiếu trùng, đổi nội dung mới thành buổi 2, ghi chép nói "lần thứ 5" thì lấy số theo ghi chép, ô chọn buổi liệt kê đúng |
| `ground2` | 14/14 đạt | Truy vết nguồn phải đối chiếu với ghi chép của CẢ ca: tái hiện báo động giả của cách cũ (4/4 ô Form 0 bị đánh dấu sau khi phân tích GĐ2), rồi kiểm cách mới cho lại "có căn cứ" mà vẫn bắt được 3 giá trị bịa; gom đủ 7 nguồn ghi chép, bỏ trùng; ca chưa có ghi chép thì không đánh dấu bừa; hồ sơ cũ dùng `entries` làm căn cứ |
| `hist2` | 19/19 đạt | Nút "Xem lại / In lại" phải nằm ở đúng chỗ NGƯỜI DÙNG THẤY: panel "📚 Lịch sử nhập — GĐ N" trên Dashboard và tab Ghi chép trong trang chi tiết ca; bấm cả dòng thì xem lại chứ không lặng lẽ ghi đè ô ghi chép; nút Khôi phục vẫn còn và vẫn chạy; mốc không có bản chụp thì ẩn 2 nút mới |
| `close` | 22/22 đạt | Đóng ca / mở lại ca bắt buộc ghi lý do: nút xác nhận khóa tới khi đủ 20 ký tự, chặn cả ở logic (gọi thẳng `_doConfirm` cũng không qua), sổ ghi lưu lý do + ngày + người + giai đoạn, trang chi tiết ca và dải "ca đã đóng" hiện lý do, hồ sơ cũ nói rõ là mốc không có lý do, lý do chứa mã độc bị vô hiệu |
| `hist` | 23/23 đạt | Xem lại / in lại bản lưu: mốc lịch sử là bản chụp (sửa dữ liệu hiện tại không làm đổi bản cũ), bản lưu kế hoạch bản 1 vẫn chỉ có 2 mục tiêu, chế độ chỉ đọc chặn sửa/lưu/phân tích/chuyển giai đoạn, in ra đúng nội dung bản lưu, thoát về đúng dữ liệu hiện tại; ô chọn buổi vãng gia lọc cả màn hình lẫn file .docx và đặt tên file kèm số lần + ngày |
| `vg` | 18/18 đạt | Vãng gia nhiều buổi: 3 buổi ra 3 phúc trình có ngắt trang và số lần đúng, ca một buổi in y như cũ, hồ sơ cũ (chỉ có bản gộp) vẫn in được, màn hình hiện đủ 3 buổi, sửa buổi 3 không đổi buổi 1, ẩn danh phủ hết danh sách |
| `plan` | 11/11 đạt | Chuẩn hóa kế hoạch: xếp 7 mục tiêu thật của ca mẫu vào đúng 1 trong 8 loại của Mục I Form 4; `loai` lạ thì không mất chữ mà đẩy xuống `muc_tieu`; `fmtDate` không được thay trắng cả câu bằng cái ngày trong câu (8 câu phải giữ nguyên, 9 giá trị phải đổi) |
| `mapall` · `mapping` · `bridge` · `bridge5` · `perform` | tất cả đạt | 170 khóa schema × 11 biểu mẫu: không khóa nào mất, không ô nào chỉ có trên web hoặc chỉ có trong .docx; cầu nối báo cáo → biểu mẫu cho cả 5 giai đoạn (không ghi đè chữ NVXH đã ghi) |
| `cb` · `cbdocx` | tất cả đạt | Chọn ô ☑ theo từ khóa (thay cách so 4 ký tự đầu): mỗi nhóm loại trừ chỉ tích tối đa 1 ô, trên cả web và .docx |
| `clip` | 0 chỗ bị cắt | Chữ **không** tràn khỏi trang nhưng bị chính khung bao (`overflow:hidden`), chiều cao đặt cứng, hoặc `text-overflow:ellipsis` do cột quá hẹp (báo khi mất >25% bề rộng) cắt mất. Bộ dò phân biệt "tới được bằng cách cuộn" với "mất hẳn", bỏ qua thứ đang ẩn có chủ ý |

Ba bộ cuối (`contrast`, `hover`, `clip`) sinh ra từ chính các lỗi đã gặp — chúng bắt được lớp lỗi
mà kiểm tra tràn trang không bao giờ thấy. Nếu QA lại, dựng ba bộ này trước.

Bảng phủ của bộ quy trình + logic:

| Nhóm | Phủ những gì |
|---|---|
| Quy trình 5 giai đoạn | Phân tích → đổ dữ liệu vào form → chuyển giai đoạn → đóng ca; `deepMerge` không ghi đè dữ liệu giai đoạn trước; **hai giai đoạn lặp** — GĐ2 mỗi buổi vãng gia một phúc trình riêng, GĐ4 mỗi buổi theo dõi nối thêm bản ghi |
| Nhánh phụ | Lùi giai đoạn, mở lại ca, backup/khôi phục (id độc bị vô hiệu), cảnh báo thiếu trường |
| Truy vết nguồn | 10 ca thử, trong đó bắt đúng 3 giá trị bịa hoàn toàn và không báo động giả với giá trị chuẩn hóa |
| Dấu BẢN NHÁP | Dấu trên cả 3 đường xuất; xác nhận rồi thì đổi dấu; phân tích lại thì thu hồi |
| Che danh tính | Địa chỉ (12 câu mẫu: 5 phải che, 7 phải giữ nguyên), **"thành phố"/"khu phố" không bị coi là tên đường**, tên đường viết thường thì không che nửa vời, nhiều tên với placeholder riêng, SĐT/CCCD/email có đánh số (bộ `pii`) |
| Chống mất dữ liệu | Mất mạng khi lưu, nháp `localStorage`, chỉ ghi ca thực sự đổi (200 ca: 0 và 1 lệnh ghi) |
| XSS | Khai thác thật bằng tên ca chứa `<img onerror>` và id độc trong `onclick`; `escAttr()` cho giá trị thuộc tính |
| In & xuất | Đọc XML file Word xuất ra: số mục La Mã, KHẨN CẤP, chữ ký, số trang, ảnh footer trải trọn khổ giấy, 10 biểu mẫu, công văn chuyển gửi |
| Tính năng có cờ | Tắt thì ẩn nút, bật lại thì chạy đúng (kiểm cả hai chiều) |

Script kiểm thử **không lưu trong repo** — chúng dùng dữ liệu giả và bám vào chi tiết cài đặt nội
bộ, nên giữ lại dễ mục ruỗng hơn là có ích. Khi cần QA lại, dựng lại theo mô tả trong bảng trên.

## Khôi phục lịch sử/quyết định

Các quyết định thiết kế quan trọng (vì sao chọn cách này thay vì cách khác) được ghi chú trực tiếp
trong code. Nơi nên đọc trước:

| Chủ đề | Đọc ở đâu |
|---|---|
| Vì sao mỗi migration làm như vậy | comment đầu mỗi file trong `supabase/migrations/` — đặc biệt `0014` (lỗi phân quyền khi lưu ca), `0015` (lỗi ràng buộc `role` mà `0011` bỏ sót) và `0016` (bàn giao ca + gán vai trò) |
| Việc cần làm dựng từ đâu | `main.js` gần `_collectTasks`, `renderTodo` |
| Vì sao danh bạ và sổ tay không nằm trong `docs/` | `.vercelignore` (đầu file) — thư mục đó bị loại khỏi bản deploy, file nào trình duyệt phải tải lúc chạy mà để trong đó là 404 trên bản deploy dù chạy máy cá nhân vẫn thấy bình thường |
| Sổ tay người dùng ở đâu, sửa thế nào | `docs/huong-dan-su-dung.README.md`; bản người dùng đọc là `huong-dan/index.html` (KHÔNG để trong `docs/` — `.vercelignore` loại thư mục đó khỏi bản deploy), link trên màn đăng nhập là `.login-guide` trong `index.html` |
| Vì sao chỉ MỘT hàm dọn dải trạng thái | `main.js` ngay trên `applyClosedCaseUI()` trong `logoutUser` — mỗi chỗ tự xoá một dải là kiểu gì cũng có chỗ quên, đã gặp thật: nút Lưu kẹt ở trạng thái mờ sau khi đăng xuất |
| Vì sao đăng nhập lại phải dọn màn hình khi ĐỔI NGƯỜI | `main.js` gần `_giuViecDangLam` trong `_onLogin` — điều kiện cũ chỉ hỏi "có ca đang mở không", nên người sau đăng nhập vào máy dùng chung thấy nguyên hồ sơ của người trước |
| Vì sao ca của người khác là chỉ đọc, và vì sao phải nói ra | `main.js` ngay trên `_isOthersCase` — `_prepOwner` trả false thì `saveCases` lặng lẽ bỏ qua, app báo "đã lưu" rồi xoá bản nháp: mất trắng công việc |
| Vì sao vùng phải tab Danh sách ca dùng chung cho việc cần làm và chi tiết ca | `main.js` ngay trên `_setCaseDetailHTML` — trước đây ba dải xếp dọc mà nửa bên phải để trống |
| Vì sao khối "Việc cần làm" bỏ tiêu đề nhóm | comment đầu mục `Việc cần làm` trong `src/css/main.css` — bản đầu bị NVXH nhận xét là xấu: 4 tầng tiêu đề, 2 nút mỗi dòng, khung cắt ngang thân một dòng |
| Vì sao `_toDate` đọc riêng chuỗi `YYYY-MM-DD` | `main.js` ngay trong `_toDate` — mốc theo dõi ghi kèm giờ thì `fmtDate` trả null và việc lặng lẽ mất khỏi danh sách |
| Bàn giao ca: vì sao ghi sổ trước khi chuyển | `main.js` gần `transferCase`; và `supabase/migrations/0016_*.sql` |
| Vì sao `_logAudit` phải bọc try/catch | `main.js` ngay trên `_logAudit` — nó chạy ở dòng đầu `loadCaseIntoApp`, ném lỗi là không mở được ca |
| Che danh tính, khôi phục tên | `main.js` gần `pseudonymizeForAI`, `_maskPiiKeys`, `maskAddressInText`, `maskContactsInText`, `restoreIdentityText` |
| Vì sao SĐT/email từng không điền được vào form | `main.js` ngay trên `maskContactsInText` — trước đây thay bằng `***` là mất hẳn giá trị |
| Vì sao trần token là 8192 | `api/chat.js` ngay trên `MAX_TOKENS_CAP` — JSON trích xuất bị cắt cụt là biểu mẫu trống trơn |
| Vớt JSON bị cắt cụt | `src/js/utils.js` gần `_salvageJSON` |
| Vì sao mảng gộp theo hợp, không so số lượng | `src/js/utils.js` gần `mergeArrays`, `_arrIdent` — có ghi cả hai cách làm sai trước đó |
| Vì sao `fmtDate` có cổng chặn ở đầu | `src/js/utils.js` ngay trên `fmtDate` — trước đây một câu dài chứa ngày bị thay trắng |
| Vì sao Mục I Form 4 từng trống | `main.js` gần `_normalizePlan`, `_NC_KW` |
| Vãng gia nhiều buổi: bản gộp vs từng buổi | `main.js` gần `_ensureVgList`, `_vgList`, `_vgFromReport` |
| Xem lại / in lại bản lưu, vì sao phải chặn đường ghi | `main.js` gần `viewSnapshot`, `reprintSnapshot`, `isHistMode`, `_snapD` |
| Hai chỗ hiện lịch sử (khác store) | `renderStageHistory` đọc `c.stageHistory[gđ]` (hiện trên Dashboard); tab Ghi chép của `showCaseDetail` đọc `c.entries`. `renderEntriesPanel` là mã chết — `#entries-panel` không có trên trang |
| Sổ ghi đóng / mở lại ca, vì sao lý do là bắt buộc | `main.js` gần `_logCaseStatus`, `_CLOSE_PROMPT`, và `showConfirm` tham số `prompt` |
| Vì sao lịch sử từng bị mất dù vẫn thấy đủ mốc | `main.js` trong `saveCaseNow`, chỗ `const snap = _snapD()` |
| Chọn in riêng một buổi vãng gia | `main.js` gần `_vgPick`, `_vgShown`, `_vgFileSuffix` |
| Dải 5 chấm tiến trình: đang làm vs đã từng đi tới | `main.js` gần `_stageStates`, `_stageReached` — có ghi cả 2 lỗi đã gặp |
| Truy vết nguồn (chặn AI bịa) | `main.js` gần `F()`, `_checkGround`, `_GROUND_RATIO` |
| Vì sao đối chiếu với ghi chép CẢ ca, không phải lần cuối | `main.js` ngay trên `_allCaseNotes` — có ghi lại đúng ca báo động giả đã gặp |
| Thu gọn / mở rộng khu chat | `main.js` gần `setChatView`, `_restoreChatView` |
| Emoji → icon nét, 3 tông màu báo cáo | `main.js` gần `_SEC_ICON`, `_SEC_TONE`, `_secHead` |
| Vì sao có `escAttr` riêng | `src/js/utils.js` ngay dưới `esc` |
| Vì sao `\b` không dùng được với chữ có dấu | `main.js` ngay trên `_CB_KIN` (và `_WB` ở phần che tên thật) — `\bbố\b` KHÔNG khớp chữ "bố" |
| "thành phố" vs "phố" (tên đường) | `main.js` gần `_ADDR_PHO_ADMIN` |
| "ba mẹ" mà không tích ô "Cha mẹ" | `main.js` gần `_CB_KIN` — bỏ dấu thì "ba" trùng "bà" |
| Bảng quy đổi cỡ chữ, vùng bấm tối thiểu | `src/css/main.css` — khối `VÙNG BẤM TỐI THIỂU` và các comment trong `@media` |
| Biến CSS từng bị dùng mà chưa khai báo | `src/css/main.css` trong khối `:root` (`--bg`, `--bg2`, `--t1`, `--bd2`, `--navy-tint`) |
