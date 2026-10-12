# DealGo – Phase 19.3: Cross-role Order Consistency

**Phạm vi:** chuẩn hóa 26 màn hình của một đơn Đồ ăn xuyên ba vai trò Khách hàng (10), Shop (6) và Tài xế (10). Giữ nguyên C001 và các bản sửa KYC/KYB Phase 19.2. Đây là *mockup + data contract tham chiếu*, không phải hệ thống backend đã chạy.

## Golden fixture thống nhất

- **Order ID:** `DG123456`, snapshot đơn version `1`; customer **Trần Thị Mai**.
- **Shop:** Bún Bò Huế O Cô, 123 Lê Lợi, Hải Châu, Đà Nẵng.
- **Tài xế:** Trần Minh Anh; Honda Vision, biển số `43H1-123.45`.
- **Món:** bún bò đặc biệt 60.000đ + bún bò thường 40.000đ + trà tắc 25.000đ = **125.000đ**.
- **Phí giao:** 25.000đ, mã quote `SHIP-Q-014`, version 1, không giảm giá.
- **Khách thanh toán:** COD **150.000đ** (chỉ thu khi giao).
- **Tài xế được hưởng:** 20.000đ; **phí giao nền tảng:** 5.000đ.
- **Tiền COD tài xế cần nộp/đối soát:** 130.000đ = 125.000đ Shop + 5.000đ nền tảng.

## Danh sách màn được thay

- **Khách hàng:** C027 C028 C030 C031 C032 C033 C034 C035 C036 C037.
- **Shop:** M015 M016 M017 M018 M019 M035.
- **Tài xế:** D018 D019 D020 D026 D027 D028 D029 D030 D031 D036.

**Chú ý:** C034 và M018 là nhánh *proposed substitution* đang chờ khách đồng ý, C035 là nhánh yêu cầu hủy, D031 là nhánh giao không thành công. Chúng là ví dụ độc lập; không đồng thời xảy ra với luồng chính giao thành công.

## P0 được giải quyết ở mockup

1. Giá tiền món/phí giao/tổng COD cố định trên toàn bộ hành trình; báo giá thay đổi phải phát hành snapshot mới, khách phê duyệt.
2. Không coi **đặt hàng thành công** là **đã thanh toán**; COD được ghi nhận thu khi hoàn tất giao hợp lệ.
3. Shop chỉ xác nhận PREPARING, READY_FOR_PICKUP; cần mã bàn giao và bằng chứng lấy hàng để PICKED_UP.
4. D030 không ghi toàn bộ tiền thu hộ vào ví tài xế; ghi riêng khoản thu nhập và tiền phải đối soát.
5. M035 chưa được đánh dấu đã nhận tiền khi payout/ledger chưa xác nhận.
6. Trạng thái giao thất bại không tự phát sinh thanh toán và không tự kết thúc thành công.

## Cần xác minh khi tích hợp sản phẩm thật

Bảng phí/hoa hồng/hệ thống trả thưởng và nghĩa vụ thuế của DealGo chưa được xác định theo hợp đồng thực tế. Bản đồ, ETA, người dùng, phương tiện và số tiền đều là **dữ liệu minh họa**. UI không được quyết định giao dịch tài chính; backend cần quyết định bằng ledger, state machine, truy cập theo vai trò và quyền thực tế.
