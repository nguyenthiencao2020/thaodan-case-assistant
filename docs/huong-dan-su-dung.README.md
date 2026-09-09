<!-- SKIP-INDEX --> <!-- ghi chú kỹ thuật cho người bảo trì, không phải tri thức CTXH -->

# Sổ tay người dùng — nguồn và cách sửa

Bản người dùng đọc là **`/huong-dan/index.html` ở thư mục gốc của repo** — đừng
sửa file đó, nó là bản dựng sẵn. Sửa ở `docs/huong-dan-su-dung.src.html` (cùng
nội dung nhưng ảnh còn là chỗ trống `__IMG_01__`…`__IMG_10__`), rồi dựng lại.

**Vì sao bản dựng KHÔNG nằm trong `docs/`:** `.vercelignore` loại cả thư mục
`docs/` khỏi bản deploy, nên để trong đó là người dùng mở ra gặp 404 — đã gặp
thật. Cùng lý do, danh bạ nguồn lực nằm ở `nguon-luc/danh-ba-nguon-luc.md`, không
phải `docs/nguon-luc/`. Quy tắc: **file nào trình duyệt phải tải lúc chạy thì
không được nằm trong `docs/`.**

## Vì sao tách hai file

Mười ảnh màn hình được nhúng thẳng vào HTML dưới dạng data URI, nên bản dựng
nặng ~950 KB và không đọc được bằng mắt. Bản `.src.html` giữ nội dung ở dạng
sửa được; bản dựng là thứ đem giao và mở được offline, không phụ thuộc file ảnh
rời nào.

## Ảnh màn hình

Chụp bằng `guide-shots.mjs` (Playwright) với **dữ liệu hư cấu hoàn toàn** — tên
trẻ, gia đình, địa chỉ, email đều là ví dụ. Thư mục `docs/` được Vercel phục vụ
công khai, nên tuyệt đối không chụp ảnh từ ca thật và không đưa email nhân sự
thật vào đây.

## Dựng lại

Chuỗi thay thế: mỗi `__IMG_nn__` đổi thành data URI của ảnh tương ứng; bản dựng
thêm `<!doctype html>` + `<head>` (bản `.src.html` viết theo dạng nhúng Artifact
nên không có hai thứ đó — thiếu doctype thì trình duyệt chạy ở chế độ quirks và
bố cục lệch). Ghi ra `huong-dan/index.html`.
