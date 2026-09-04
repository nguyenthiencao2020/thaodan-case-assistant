# Kho tri thức của Thảo Đàn (RAG)

Mọi file `.md` / `.txt` trong thư mục này được nạp vào Supabase pgvector và
**truy xuất tự động mỗi lần AI phân tích ca**. Đây là cách biến AI từ "biết
công tác xã hội nói chung" thành "biết cách Thảo Đàn làm".

Nếu thư mục này trống hoặc chưa nạp, AI vẫn trả lời — nhưng bằng kiến thức
chung của internet, không phải quy trình và nguồn lực thật của tổ chức.

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
