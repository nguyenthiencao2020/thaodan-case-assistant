# Thảo Đàn AI Case Assistant

Công cụ hỗ trợ Nhân viên Công tác Xã hội (NVXH) tại Thảo Đàn SSC quản lý ca bảo vệ trẻ em theo quy trình 5 giai đoạn (Tiếp cận → Vãng gia → Kế hoạch → Tiến trình → Kết thúc), có AI hỗ trợ trích xuất form và tư vấn chuyên môn.

## Kiến trúc

Vanilla JS (không framework, không bundler cho `main.js`) + Vite (chỉ dùng cho dev server) + Vercel Serverless Functions + Supabase (Postgres + Auth + Storage).

```
index.html              # 1 trang duy nhất, load 4 file JS qua <script> thường (không phải module)
src/js/config.js        # Hằng số, STAGE_CONFIG
src/js/prompts.js       # Toàn bộ system prompt gửi cho AI
src/js/utils.js         # Hàm tiện ích (esc, deepMerge, showNotif...)
src/js/main.js          # Toàn bộ logic app (~5600 dòng)
src/css/main.css        # Design system
api/chat.js             # Proxy gọi Groq — yêu cầu Supabase access token
api/rag.js              # Proxy tìm tài liệu liên quan (pgvector) — yêu cầu token
api/_auth.js            # Helper xác thực token dùng chung cho 2 route trên
supabase/migrations/    # Toàn bộ migration SQL, đánh số thứ tự — xem bên dưới
docs/                   # Tài liệu nghiệp vụ CTXH cho AI học (RAG) — xem docs/README.md
```

**Lưu ý quan trọng:** `main.js` không có bước build/bundler thật (Vite chỉ chạy dev server; `npm run build` không nhúng được các file `<script>` thường). Deploy lên Vercel dùng `buildCommand: "npm install"` + `outputDirectory: "."` — serve thẳng source, không qua bước build. `.vercelignore` loại trừ `docs/`, `supabase/`, `scripts/`, `*.bak` khỏi việc bị public hóa.

## Cài đặt & chạy dev

```bash
npm install
npm run dev
```

## Trạng thái triển khai (cập nhật 04/09/2026)

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
| `docs/nguon-luc/danh-ba-nguon-luc.md` | ⬜ còn khung mẫu, đang chờ dữ liệu thật từ tổ chức (làm được độc lập, không cần khóa OpenAI) |
| `docs/phap-ly/can-cu-phap-ly.md` | ⬜ còn khung mẫu |
| Hồ sơ đánh giá tác động NĐ 13/2023 | ⬜ việc của tổ chức, cần tham vấn pháp lý |

### Hai tính năng đang HOÃN vì chưa có khóa OpenAI

Tổ chức chưa có khóa OpenAI, nên hai tính năng dùng nó đều đã được xử lý gọn để **không gây nhiễu**:

| Tính năng | Trạng thái khi không có khóa |
|---|---|
| Kho tri thức (RAG) | `api/rag.js` trả `{chunks:[]}` — app chạy bình thường, chỉ là AI trả lời bằng kiến thức chung. GitHub Action **tự bỏ qua và thoát 0** nên không đỏ; log in cảnh báo rõ |
| Đọc ảnh trang sổ tay | **Đã TẮT** qua `FEATURES.ocr` — cũng là quyết định riêng về bảo mật, xem mục "đang tạm tắt" |

**Không phải việc cần làm gấp.** Bật lại khi nào tổ chức có khóa: khai `OPENAI_API_KEY` ở Vercel và
GitHub Secrets, đổi `FEATURES.ocr` nếu muốn dùng cả nút 📷. Chi tiết trong
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
| `OPENAI_API_KEY` | `api/rag.js`, **`api/ocr.js`** | MỘT khóa cho HAI việc: tạo embedding truy xuất kho tri thức, và đọc chữ trong ảnh trang sổ tay. |

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

## Tình trạng bảo mật (tính đến phiên rà soát gần nhất)

Đã vá: XSS lưu trữ (hiển thị form/report, import file backup ca), API proxy không xác thực, PII trẻ em gửi gần nguyên văn cho AI, prototype pollution qua lệnh chat sửa form, RLS thiếu/dư trên nhiều bảng, hàm `SECURITY DEFINER` thiếu khóa `search_path`, lộ file nội bộ qua static hosting, race condition mất dữ liệu khi đăng nhập mạng chậm.

Vá ở phiên QA 07/09/2026: **XSS lưu trữ qua tên ca trong bảng thông báo** — đường đọc từ DB đã
`esc()` từ trước nhưng đường dự phòng cục bộ (khi bảng `notifications` rỗng) chèn thẳng
`n.message` vào `innerHTML`, mà message có nhúng tên ca lấy từ `co_ban.ho_ten` do AI trích xuất từ
ghi chép (hoặc từ file backup import vào) — tức nội dung không tin được. Cùng lúc siết `n.id`
trước khi chèn vào thuộc tính `onclick` và `esc(e.message)` ở 2 chỗ hiển thị lỗi.

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
trên 10 biểu mẫu. Nhập bằng cách gõ, bằng **giọng nói** (Web Speech API, miễn phí), hoặc **chụp ảnh
trang sổ tay** (`api/ocr.js`).

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
theo dõi sau đóng ca · audit log.

**Đang tạm tắt** — công tắc `FEATURES` trong `src/js/config.js`, đổi `false`→`true` để bật lại.
Code, modal, endpoint và dữ liệu đã lưu đều còn nguyên, không phải viết lại gì:

| Cờ | Tính năng | Vì sao tắt |
|---|---|---|
| `dass` | Thang đo DASS-21/42 | Chờ thiết kế lại — bộ câu hỏi là bản tự khai ngôi thứ nhất của người lớn, chỉ thẩm định cho ≥17 tuổi, mà màn hình không hỏi ai là người trả lời |
| `genogram` | Sơ đồ phả hệ | Chờ thiết kế lại — thiếu đúng phần cốt lõi là đường quan hệ (thân thiết/xung đột/xa cách/cắt đứt) và không sửa được bằng tay |
| `ocr` | Đọc chữ trong ảnh sổ tay | **Quyết định của tổ chức.** Đây là luồng DUY NHẤT gửi dữ liệu định danh chưa che ra ngoài — tên thật và địa chỉ nằm ngay trong nét chữ, không regex nào che được. Bật lại cần cả `OPENAI_API_KEY` và quyết định về NĐ 13/2023 |

Nút 🎤 **nhập bằng giọng nói vẫn bật** — dùng Web Speech API sẵn trong Chrome/Edge, miễn phí, và
văn bản đọc ra vẫn đi qua đúng bộ che tên/SĐT/địa chỉ trước khi tới Groq. Với NVXH vừa đi vãng gia
về, kể lại bằng miệng còn nhanh hơn chụp ảnh trang sổ rồi sửa lỗi đọc.

## Kiểm thử

Không có test tự động trong repo (app là script không module, không có bước build cho `main.js`).
Kiểm thử được viết dưới dạng script Playwright chạy ngoài, dựng máy chủ tĩnh trên `localhost:8899`
và giả lập Supabase + Groq + OpenAI để chạy được toàn bộ luồng mà không cần khóa thật.

**Lần QA gần nhất: 07/09/2026 — 226 kiểm tra, 0 lỗi**, phủ 17 nhóm:

| Nhóm | Phủ những gì |
|---|---|
| Quy trình 5 giai đoạn | Phân tích → đổ dữ liệu vào form → chuyển giai đoạn → đóng ca; `deepMerge` không ghi đè dữ liệu giai đoạn trước; GĐ4 nối thêm đúng |
| Nhánh phụ | Lùi giai đoạn, mở lại ca, backup/khôi phục (id độc bị vô hiệu), cảnh báo thiếu trường |
| Truy vết nguồn | 10 ca thử, trong đó bắt đúng 3 giá trị bịa hoàn toàn và không báo động giả với giá trị chuẩn hóa |
| Dấu BẢN NHÁP | Dấu trên cả 3 đường xuất; xác nhận rồi thì đổi dấu; phân tích lại thì thu hồi |
| Che danh tính | Địa chỉ (12 câu mẫu: 5 phải che, 7 phải giữ nguyên), nhiều tên với placeholder riêng |
| Chống mất dữ liệu | Mất mạng khi lưu, nháp `localStorage`, chỉ ghi ca thực sự đổi (200 ca: 0 và 1 lệnh ghi) |
| XSS | Khai thác thật bằng tên ca chứa `<img onerror>` và id độc trong `onclick` |
| Giao diện | 6 kích thước × 4 tab, ngăn kéo biểu mẫu, nút ghim đáy, hàng nút theo số tính năng bật |
| In & xuất | Đọc XML file Word xuất ra: số mục La Mã, KHẨN CẤP, chữ ký, số trang, 10 biểu mẫu, công văn chuyển gửi |
| Tính năng có cờ | Tắt thì ẩn nút, bật lại thì chạy đúng (kiểm cả hai chiều) |

Script kiểm thử **không lưu trong repo** — chúng dùng dữ liệu giả và bám vào chi tiết cài đặt nội
bộ, nên giữ lại dễ mục ruỗng hơn là có ích. Khi cần QA lại, dựng lại theo mô tả trong bảng trên.

## Khôi phục lịch sử/quyết định

Các quyết định thiết kế quan trọng (vì sao chọn cách này thay vì cách khác) được ghi chú trực tiếp trong code — đặc biệt xem comment đầu mỗi file migration trong `supabase/migrations/`, và các đoạn comment trong `main.js` gần `pseudonymizeForAI`, `_maskPiiKeys`, `F()`.
