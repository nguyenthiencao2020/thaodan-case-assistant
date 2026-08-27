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

## Biến môi trường (Vercel → Project Settings → Environment Variables)

| Biến | Dùng ở đâu | Ghi chú |
|---|---|---|
| `GROQ_KEY_1`, `GROQ_KEY_2`, `GROQ_KEY_3` | `api/chat.js` | Round-robin giữa 3 key để giảm rate limit. Model hiện dùng: `openai/gpt-oss-120b`. |
| `SUPABASE_URL`, `SUPABASE_SERVICE_KEY` | `api/rag.js` | Service key — **không** để lộ ra client. |
| `OPENAI_API_KEY` | `api/rag.js` | Dùng để tạo embedding cho tìm kiếm tài liệu (pgvector). |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | `api/_auth.js` | Xác thực token người dùng gửi lên từ client. Có fallback hard-code giá trị public hiện tại nếu không set — nên set tường minh nếu key thay đổi. |

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

**Cơ chế admin hiện tại:** hard-code theo email (`ADMIN_EMAIL` trong `src/js/main.js`, khớp với `hangcong.nguyen@thaodancenter.org.vn` trong các policy SQL) — nếu đổi admin, sửa cả 2 chỗ.

## Tình trạng bảo mật (tính đến phiên rà soát gần nhất)

Đã vá: XSS lưu trữ (hiển thị form/report, import file backup ca), API proxy không xác thực, PII trẻ em gửi gần nguyên văn cho AI, prototype pollution qua lệnh chat sửa form, RLS thiếu/dư trên nhiều bảng, hàm `SECURITY DEFINER` thiếu khóa `search_path`, lộ file nội bộ qua static hosting, race condition mất dữ liệu khi đăng nhập mạng chậm.

**Cố tình chưa làm** (rủi ro cao hơn lợi ích trước mắt, cần phiên riêng có kế hoạch backup):
- Mã hóa toàn bộ khối JSONB `cases_v2.data` (chứa mọi chi tiết ca) — khác với 2 cột đã mã hóa ở `0012`, khối này được toàn bộ app đọc/ghi liên tục, mã hóa sai cách rủi ro làm hỏng tính năng lưu/tải ca cho mọi người dùng.
- UI quản lý nhóm/gán officer đầy đủ cho RBAC — hiện admin gán `team_id` cho từng ca qua UI đơn giản (màn chi tiết ca) hoặc SQL trực tiếp.

## Tính năng chính

- 5 giai đoạn quản lý ca, AI trích xuất form từ ghi chép tự do (không cần nhập tay từng ô)
- Chat tư vấn CTXH có RAG (tham chiếu tài liệu nghiệp vụ đã index) + cảnh báo pháp lý hiển thị trên UI
- Popup cảnh báo chủ động khi AI phát hiện rủi ro mức Cao
- Mã số ca tự sinh (`CA-YYYY-MM-STT`), dashboard thống kê, xuất báo cáo Word/PDF
- Theo dõi sau đóng ca (follow-up), audit log, DASS-21/42, genogram

## Khôi phục lịch sử/quyết định

Các quyết định thiết kế quan trọng (vì sao chọn cách này thay vì cách khác) được ghi chú trực tiếp trong code — đặc biệt xem comment đầu mỗi file migration trong `supabase/migrations/`, và các đoạn comment trong `main.js` gần `pseudonymizeForAI`, `_maskPiiKeys`, `F()`.
