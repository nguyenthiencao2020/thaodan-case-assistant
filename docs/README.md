# Kho tri thức của Thảo Đàn (RAG)

Mọi file `.md` / `.txt` trong thư mục này được nạp vào Supabase pgvector và
**truy xuất tự động mỗi lần AI phân tích ca**. Đây là cách biến AI từ "biết
công tác xã hội nói chung" thành "biết cách Thảo Đàn làm".

Nếu thư mục này trống hoặc chưa nạp, AI vẫn trả lời — nhưng bằng kiến thức
chung của internet, không phải quy trình và nguồn lực thật của tổ chức.

## RAG cần những gì

Chia làm 3 phần: hạ tầng đã xong, cấu hình cần chuẩn bị đúng **một** thứ, nội dung là phần quyết
định RAG có giá trị hay không.

### Hạ tầng — đã xong, không phải làm gì

| Thành phần | Ở đâu |
|---|---|
| Bảng `documents` + pgvector + hàm `match_documents` | `supabase/migrations/0001_rag_documents.sql` |
| Endpoint truy xuất | `api/rag.js` |
| Script nạp tài liệu (cắt mẩu theo tiêu đề, có `--dry-run`) | `scripts/index-docs.js` |
| Tự nạp lại mỗi khi push `docs/**` lên `main` | `.github/workflows/index-docs.yml` |
| App gọi RAG mỗi lần phân tích ca và mỗi câu chat | `fetchRagContext()` trong `src/js/main.js` |

### Cấu hình — chỉ cần một khóa OpenAI

`OPENAI_API_KEY` là thứ **duy nhất** còn thiếu. RAG cần nó để biến chữ thành vector (embedding) —
cả lúc nạp tài liệu lẫn lúc truy xuất.

- Lấy ở `platform.openai.com` → **API keys** → Create new secret key
- Tài khoản mới không có credit miễn phí — cần nạp tối thiểu vào **Billing**
- Model dùng: `text-embedding-3-small`, loại rẻ nhất. 27 mẩu tài liệu hiện có tốn không đáng kể;
  mỗi lần NVXH bấm Phân tích thêm 1 embedding cho câu truy vấn
- Nên đặt **Usage limit** ở `platform.openai.com/settings/limits` trước khi phát cho NVXH dùng
- Khai vào **cả hai nơi**: Vercel (app truy xuất) và GitHub Secrets (Action nạp) — xem README gốc

### Vì sao không có cách thay thế

| Cách | Vấn đề |
|---|---|
| Dùng embedding của Groq | Groq **không có** API embedding |
| Thêm nhà cung cấp thứ ba | Lại thêm một luồng dữ liệu ra nước ngoài cần đưa vào hồ sơ NĐ 13/2023 |
| Bỏ RAG, nhét thẳng SOP vào prompt | SOP dài 11KB; nhét hết vào mỗi lời gọi Groq tốn token Groq nhiều hơn hẳn và dễ vượt giới hạn. RAG chỉ lấy 3 mẩu liên quan nhất nên rẻ hơn |

Nếu tổ chức quyết định **không dùng OpenAI**, phương án thực tế là bỏ RAG hẳn — tắt qua `FEATURES`
để không ai mất thời gian tìm lý do AI trả lời chung chung.

### Nội dung — ai chuẩn bị phần nào

| File | Ai chuẩn bị |
|---|---|
| `quy-trinh-ctxh-co-ban.md`, `sop-quan-ly-ca-ctxh-v1.md` | ✅ đã có sẵn trong repo |
| `nguon-luc/danh-ba-nguon-luc.md` | NVXH có kinh nghiệm hoặc giám sát ca — người đã thực sự gọi điện, đi làm thủ tục |
| `phap-ly/can-cu-phap-ly.md` | Người phụ trách pháp lý của tổ chức |
| `ca-mau/` | Giám sát ca duyệt trước khi thêm (xem quy tắc ẩn danh trong `ca-mau/README.md`) |

Ngay khi có khóa OpenAI, **27 mẩu quy trình + SOP nạp được liền** — đủ để AI trả lời đúng SLA và
biểu mẫu bắt buộc của Thảo Đàn thay vì kiến thức chung. Không phải chờ danh bạ.

## Cấu trúc

| Đường dẫn | Nội dung | Trạng thái |
|---|---|---|
| `quy-trinh-ctxh-co-ban.md` | Quy trình 5 giai đoạn, triết lý, ma trận rủi ro | ✅ đã có |
| `sop-quan-ly-ca-ctxh-v1.md` | SOP từng giai đoạn, SLA, RACI, playbook | ✅ đã có |
| `nguon-luc/danh-ba-nguon-luc.md` | Trường, bệnh viện, quỹ, đầu mối khẩn cấp **có thật** | ⬜ khung mẫu, chờ điền |
| `phap-ly/can-cu-phap-ly.md` | Điều khoản hay viện dẫn, ngưỡng can thiệp | ⬜ khung mẫu, chờ điền |
| `ca-mau/` | Ca đã đóng, đã ẩn danh, kèm kết quả thật | ⬜ chưa có ca nào |

File nào còn dòng `<!-- SKIP-INDEX -->` sẽ **không** được nạp — để khung mẫu
chưa điền không làm nhiễu kho tri thức. Điền xong thì xóa dòng đó.

## Nạp vào kho

```bash
# 1. Xem trước cách cắt mẩu — KHÔNG cần API key, KHÔNG ghi database
node scripts/index-docs.js --dry-run

# 2. Nạp thật (cần 3 biến môi trường)
export SUPABASE_URL=...
export SUPABASE_SERVICE_KEY=...      # service_role key, KHÔNG phải anon key
export OPENAI_API_KEY=...            # dùng cho text-embedding-3-small
node scripts/index-docs.js
```

Chạy lại bất cứ lúc nào — mỗi file được xóa và nạp lại theo `source_file`,
không sinh bản trùng.

## Trạng thái hiện tại (04/09/2026)

**Kho tri thức CHƯA được nạp** — Action `Index docs → Supabase RAG` đang lỗi vì thiếu secret
`OPENAI_API_KEY` trong GitHub (tổ chức chưa có khóa OpenAI). `SUPABASE_URL` và
`SUPABASE_SERVICE_KEY` đã khai xong.

Khi có khóa, nạp được ngay **27 mẩu** từ `quy-trinh-ctxh-co-ban.md` (8) và `sop-quan-ly-ca-ctxh-v1.md`
(19). Hai file `nguon-luc/` và `phap-ly/` vẫn bị bỏ qua vì còn dấu `SKIP-INDEX` — đang chờ dữ liệu
thật từ tổ chức.

## Để tính năng hoạt động trên bản chạy thật

`api/rag.js` cần 3 biến môi trường trên **được cấu hình trong Vercel**.
Nếu thiếu bất kỳ biến nào, endpoint trả về rỗng một cách âm thầm và AI mất
hoàn toàn phần tri thức tổ chức — không có thông báo lỗi nào.

Kiểm tra nhanh: phân tích một ca rồi hỏi trong khung chat *"quy trình giai
đoạn 2 của Thảo Đàn yêu cầu gì?"*. Nếu AI trả lời đúng SLA 72h và các biểu
mẫu bắt buộc → RAG đang chạy. Nếu trả lời chung chung → chưa chạy.

## Bảo mật — đọc trước khi thêm file

Nội dung trong thư mục này **được gửi cho nhà cung cấp AI ở nước ngoài** khi
truy xuất. Vì vậy:

- ❌ Không đưa hồ sơ trẻ chưa ẩn danh vào đây
- ❌ Không đưa tên thật, số nhà, số điện thoại của thân chủ
- ✅ Được đưa đầu mối dịch vụ công khai (trường, bệnh viện, quỹ)
- ✅ Được đưa ca mẫu **đã ẩn danh** và có xác nhận của giám sát ca
