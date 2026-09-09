# Sổ tay người dùng — nguồn và cách sửa

`huong-dan-su-dung.html` là **bản dựng sẵn**, đừng sửa trực tiếp. Sửa ở
`huong-dan-su-dung.src.html` (cùng nội dung nhưng ảnh còn là chỗ trống
`__IMG_01__`…`__IMG_10__`), rồi dựng lại.

## Vì sao tách hai file

Mười ảnh màn hình được nhúng thẳng vào HTML dưới dạng data URI, nên bản dựng
nặng ~950 KB và không đọc được bằng mắt. Bản `.src.html` giữ nội dung ở dạng
sửa được; bản `.html` là thứ đem giao và mở được offline, không phụ thuộc file
ảnh rời nào.

## Ảnh màn hình

Chụp bằng `guide-shots.mjs` (Playwright) với **dữ liệu hư cấu hoàn toàn** — tên
trẻ, gia đình, địa chỉ, email đều là ví dụ. Thư mục `docs/` được Vercel phục vụ
công khai, nên tuyệt đối không chụp ảnh từ ca thật và không đưa email nhân sự
thật vào đây.

## Dựng lại

Chuỗi thay thế: mỗi `__IMG_nn__` đổi thành data URI của ảnh tương ứng; bản
`.html` thêm `<!doctype html>` + `<head>` (bản `.src.html` viết theo dạng nhúng
Artifact nên không có hai thứ đó — thiếu doctype thì trình duyệt chạy ở chế độ
quirks và bố cục lệch).
