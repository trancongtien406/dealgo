# Store listing — Tiếng Việt (vi-VN)

> Dùng cho `Trang chủ cửa hàng → Thông tin ứng dụng chính` của Google Play Console.
> Giới hạn: tên **30**, mô tả ngắn **80**, mô tả đầy đủ **4000**, "Có gì mới" **500** ký tự.

## 1. Tên ứng dụng

```
DealGo
```

## 2. Mô tả ngắn (66 ký tự)

```
Đặt xe và giao đồ ăn tại Việt Nam: giá rõ ràng, theo dõi trực tiếp.
```

## 3. Mô tả đầy đủ (1.483 ký tự)

```
DealGo là ứng dụng đặt xe và giao đồ ăn tại Việt Nam, dành cho khách hàng, tài xế và cửa hàng trong cùng một ứng dụng.

ĐẶT XE
• Chọn xe máy hoặc ô tô, xem giá ước tính trước khi đặt.
• Ghim điểm đón, điểm đến trên bản đồ và theo dõi tài xế trực tiếp.
• Thanh toán tiền mặt hoặc qua phương thức thanh toán trực tuyến được hỗ trợ.
• Lịch sử chuyến, hoá đơn và hỗ trợ khi cần.

GIAO ĐỒ ĂN
• Tìm quán gần bạn, xem thực đơn, giá và thời gian giao.
• Thêm món, chọn tuỳ chọn, áp ưu đãi và theo dõi đơn từ lúc quán nhận đến khi giao xong.
• Đánh giá quán và tài xế sau mỗi đơn.

DÀNH CHO TÀI XẾ
• Nhận cuốc xe và đơn giao đồ ăn theo khu vực.
• Xem thu nhập, phí nền tảng và số dư tạm ứng phí.
• Tài xế có thể nộp trước phí nền tảng để tự động cấn trừ vào phí phát sinh. Khoản này chỉ dùng để trừ phí phải trả DealGo, không chuyển được cho người khác, không rút tiền mặt và không dùng để mua hàng.

DÀNH CHO CỬA HÀNG
• Quản lý thực đơn, nhận và xử lý đơn, tạo ưu đãi và xem đánh giá của khách.

AN TOÀN & MINH BẠCH
• Tài khoản được xác thực; hồ sơ đối tác được kiểm duyệt.
• Quyền vị trí chỉ dùng khi bạn dùng ứng dụng để đặt xe/giao đồ ăn.
• Chính sách quyền riêng tư và điều khoản dịch vụ công khai trên website.
• Có thể yêu cầu xoá tài khoản ngay trong ứng dụng.

DealGo không cung cấp ví điện tử, cho vay, tín dụng, chuyển tiền hay dịch vụ tiền mã hoá. Giá và phương thức thanh toán hiển thị trong ứng dụng là giá đã chốt tại thời điểm đặt; chính sách huỷ/hoàn theo Điều khoản dịch vụ.
```

> **Điều kiện:** chỉ giữ câu "có thể nộp trước" nếu bản nộp có `DRIVER_TOP_UP_ENABLED=true` và PSP đã cấu hình. Nếu tính năng đang tắt, bỏ câu này (và cân nhắc ẩn thẻ nạp phí) để store listing khớp bản nộp; cập nhật lại khi bật.

## 4. Danh mục và tag

| Trường | Giá trị | Ghi chú |
|---|---|---|
| Danh mục ứng dụng | **Bản đồ và chỉ đường (Maps & Navigation)** | **ASSUMED** — phù hợp app đặt xe; **không** chọn Finance vì không phải app tài chính |
| Tag | `ride-hailing`, `food delivery`, `transport`, `local services` | Chọn trong danh sách gợi ý của Play nếu có |
| Loại ứng dụng | Ứng dụng (không phải game) | — |
| Miễn phí / trả phí | Miễn phí | Không có IAP kỹ thuật số |

## 5. Thông tin liên hệ

| Trường | Giá trị |
|---|---|
| Email | `support@dealgo.laptrinhapp.com` — **ASSUMED**, xác nhận hộp thư hoạt động |
| Website | `https://dealgo.laptrinhapp.com` — **VERIFIED** (domain chốt 04/11/2026; cần trỏ DNS + SSL trước khi Submit) |
| Điện thoại | `+84…` — điền số hỗ trợ thật |
| Chính sách quyền riêng tư | `https://dealgo.laptrinhapp.com/privacy` |

Play yêu cầu URL chính sách **mở công khai, không cần đăng nhập**, có tên app/developer khớp store listing.

## 6. "Có gì mới" (254 ký tự)

```
Bản đầu tiên trên Google Play.
• Đặt xe máy và ô tô, theo dõi tài xế trực tiếp.
• Gọi đồ ăn, áp ưu đãi và theo dõi đơn.
• Tài xế xem thu nhập và nộp trước phí nền tảng.
• Cửa hàng quản lý thực đơn, đơn hàng và ưu đãi.
• Xoá tài khoản ngay trong ứng dụng.
```

## 7. Đồ hoạ cần chuẩn bị

| Tài sản | Kích thước | Trạng thái |
|---|---|---|
| Biểu tượng ứng dụng | 512 × 512 PNG, không alpha | **ACTION** |
| Ảnh nổi bật (feature graphic) | 1024 × 500 PNG/JPEG | **ACTION** |
| Ảnh chụp màn hình điện thoại | tối thiểu 2, tối đa 8; 16:9 hoặc 9:16 | **ACTION** — dùng build DEV + seed, không dùng dữ liệu thật |
| Ảnh chụp 7" / 10" | không bắt buộc | tuỳ chọn |
| Video quảng bá | YouTube, không bắt buộc | tuỳ chọn |

Ảnh chụp phải khớp bản nộp: không hiện màn hình nạp phí nếu tính năng đang tắt; không hiện giá/fare thử nghiệm không có thật.

## 8. Điều không được ghi

- "Ví DealGo", "ví điện tử", "nạp/rút ví", "hoàn tiền vào ví" cho khách.
- "Lãi suất", "vay", "trả sau", "hạn mức tín dụng".
- "Bảo mật tuyệt đối", "giá rẻ nhất", "nhanh nhất" — không kiểm chứng được.
- Số liệu người dùng/đối tác không có thật.
- Hứa hẹn tính năng chưa mở (ví khách, giao hàng liên tỉnh…).
