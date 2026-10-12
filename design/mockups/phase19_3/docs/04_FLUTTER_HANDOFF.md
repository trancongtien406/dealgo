# Flutter handoff – DealGo Phase 19.3

## Tài sản

- `screens/Cxxx.png`, `screens/Mxxx.png`, `screens/Dxxx.png`: 26 ảnh *bản sửa*.
- `screens/*.html`: bản layout tĩnh tham khảo, không phải source Flutter và không có logic nghiệp vụ.
- `docs/golden_order.json`: golden fixture được chia sẻ xuyên ba vai trò.
- `docs/patch_manifest.csv`: mã thay thế + hash đối chiếu.
- `preview/gallery.html`: thư viện offline xem ảnh; mở được trong trình duyệt desktop.

## Design System

Giữ C001 là nguồn cảm hứng nhận diện: tím chủ đạo, xanh lá cho thành công, nền trắng, card bo lớn, CTA tím. Tạo một thư viện chung gồm `AppScaffold`, `AppBar`, `OrderStatusChip`, `PriceBreakdown`, `MerchantCard`, `DriverCard`, `MapPanel`, `OrderTimeline`, `PrimaryCTA`, `FeedbackBanner`, `Empty/Error/LoadingState`.

## Tổ chức app

`lib/app`, `lib/core/design_system`, `lib/core/network`, `lib/core/auth`, `lib/features/customer`, `lib/features/merchant`, `lib/features/driver`, `lib/features/orders/shared`, `lib/features/wallet`, `lib/features/kyc`.

- Một `Order` và `OrderSnapshot` duy nhất dùng chung, không tạo ba DTO giá khác nhau giữa các vai trò.
- Order + quote + delivery + payment + ledger có status typed enum riêng.
- Bloc/Cubit phù hợp nhóm luồng rõ ràng, chỉ cấp provider ở scope cần; không nhồi mọi màn vào một singleton toàn app.
- Giao diện hiển thị số tiền tính từ backend snapshot immutable, không cộng lại theo chuỗi hiển thị.
- Khi vào màn từ notification/deep link, điều hướng tới role đúng nhưng không làm mất assignment đang hoạt động.

## Golden E2E scenarios

1. Customer chọn món → quote 25k → xác nhận → Shop nhận → bếp chuẩn bị → driver nhận việc → Shop bàn giao bằng 2891 → driver nhập mã → giao → nhận COD 150k → thanh toán đã ghi nhận → COD đối soát 130k.
2. Customer từ chối thay trà tắc; đơn không tự chuyển sang v2 và không đổi tổng tiền.
3. Shop đề xuất thay nước chanh 25k; customer approve thì snapshot tăng version có audit, vẫn 150k.
4. Driver đề xuất tăng phí giao 30k: quote v2 không tự áp dụng cho customer; chỉ commit nếu khách xác nhận và repricing tổng tiền.
5. Driver giao thất bại: không ghi DELIVERED và không credit earning/thu COD khi chưa chứng minh.
6. Request hoàn thành giao gửi hai lần với cùng idempotency key: ledger phát sinh một lần.
7. Quyền truy cập: Shop A không thể sửa đơn của Shop B, tài xế khác không thể hoàn tất assignment không thuộc mình.
8. COD đã thu nhưng ứng dụng offline: hiển thị đang đồng bộ, xử lý reconcile qua backend, không tự gắn “đã đối soát”.

## Definition of Done

Golden fixtures qua unit tests; widget golden tests với 360/390/430 logical px và text scaling; test keyboard and safe areas; integration E2E đi xuyên 3 role; accessibility Semantics/contrast/touch area; xử lý crash/offline/timeouts/retry; không log số giấy tờ hoặc thông tin nhạy cảm. Các mockup hiện chưa chứng minh điều kiện này.
