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
| 13 migration Supabase `0001`→`0013` | ✅ đã chạy |
| Khóa Vault `case_encryption_key` | ✅ đã tạo — kiểm chứng mã hóa/giải mã vòng tròn OK |
| Mã hóa ca cũ | ✅ 4/4 ca có `data_enc`, 0 ca còn plaintext |
| Vercel: `GROQ_KEY_1/2/3`, `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `SUPABASE_ANON_KEY` | ✅ đã khai |
| Vercel: `OPENAI_API_KEY` | ⬜ **chưa có khóa OpenAI** |
| GitHub Secrets: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` | ✅ đã khai |
| GitHub Secrets: `OPENAI_API_KEY` | ⬜ **chưa có khóa OpenAI** |
| Kho tri thức đã nạp | ⬜ chưa — Action chưa chạy được vì thiếu secret trên |
| `docs/nguon-luc/danh-ba-nguon-luc.md` | ⬜ còn khung mẫu, đang chờ dữ liệu thật từ tổ chức |
| `docs/phap-ly/can-cu-phap-ly.md` | ⬜ còn khung mẫu |
| Hồ sơ đánh giá tác động NĐ 13/2023 | ⬜ việc của tổ chức, cần tham vấn pháp lý |

### Hiện tại KHÔNG hoạt động vì chưa có `OPENAI_API_KEY`

Một khóa OpenAI duy nhất chặn 3 việc. Cả 3 đều **lỗi âm thầm hoặc bán âm thầm** — app vẫn chạy
bình thường nên rất dễ tưởng là đã xong:

| Việc | Biểu hiện khi thiếu khóa |
|---|---|
| Truy xuất kho tri thức (RAG) | `api/rag.js` trả `{chunks:[]}` **không báo lỗi** → AI trả lời bằng kiến thức chung của internet thay vì quy trình và nguồn lực thật của Thảo Đàn |
| Nạp tài liệu vào kho | GitHub Action dừng, chỉ thấy ✗ trong tab Actions — app không báo gì |
| Đọc ảnh trang sổ tay | **Đã TẮT** qua `FEATURES.ocr` — quyết định của tổ chức, xem mục dưới |

**Cách kiểm RAG đã chạy hay chưa** (vì nó không báo lỗi): phân tích một ca rồi hỏi trong khung chat
*"Quy trình giai đoạn 2 của Thảo Đàn yêu cầu những gì?"* — trả lời đúng **SLA 72 giờ** và tên biểu
mẫu bắt buộc là đang chạy; trả lời chung chung là chưa.

Những phần **không** phụ thuộc khóa OpenAI và đang chạy đủ: phân tích ca và chat (Groq), 10 biểu
mẫu, truy vết nguồn, dấu BẢN NHÁP, ẩn danh, tra cứu tiền lệ, nhập bằng giọng nói, xuất Word/PDF,
mã hóa hồ sơ.

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

Vá tiếp trong các phiên sau: lưu thất bại nhưng vẫn báo "Đã lưu" (nay `await` kết quả và hiện
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

## Khôi phục lịch sử/quyết định

Các quyết định thiết kế quan trọng (vì sao chọn cách này thay vì cách khác) được ghi chú trực tiếp trong code — đặc biệt xem comment đầu mỗi file migration trong `supabase/migrations/`, và các đoạn comment trong `main.js` gần `pseudonymizeForAI`, `_maskPiiKeys`, `F()`.
