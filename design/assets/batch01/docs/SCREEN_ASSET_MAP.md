# DealGo – Screen Asset Map v0.1

## Vai trò từng lớp tài nguyên

| Lớp | Chiến lược | Ví dụ |
|---|---|---|
| Brand | Giữ nguyên logo **DealGo** C001 đã chốt | Không thay bằng logo sinh ngẫu nhiên |
| Photography | Ảnh đồ ăn/quán thực tế, có giấy phép sử dụng | Món ăn tại C022, C025, C026, M026 |
| Editorial illustration | Dùng PNG/WebP hoặc SVG minh họa không chứa chữ | Banner C001, voucher C044, onboarding S002 |
| Domain art | Hình phương tiện, người giao hàng, địa điểm | C004, D016, D029, S007 |
| System states | Hình trạng thái, không thay cho thông báo có thể đọc | Empty, offline, expired, fail, success |
| Functional iconography | Không dùng ảnh tạo tự động; nên dùng một bộ vector icon qua Flutter | Search, map-pin, cart, notifications, back |
| Dynamic map | Render bằng map SDK + marker/widget | C002, C013, D021, D029 |

## Ánh xạ asset – màn hình

| Màn hình | Asset nền/ảnh | Asset nội dung | Lưu ý |
|---|---|---|---|
| C001 Trang chủ | `banner_danang_hero`, `card_ride`, `card_food`, `banner_promo_gift` | Ảnh món/quán thực tế | Hero là phương án vector; bản ảnh chụp gốc vẫn ưu tiên khi chưa duyệt thay đổi |
| C002-C004 Đặt xe | Động: map SDK | `vehicle_sedan`, `vehicle_7seat`, `vehicle_motorbike`, `accent_pickup_route` | Giá, loại xe và route luôn là widget/data |
| C005-C011 Thương lượng | Map SDK | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | Không chứa text hay số tiền trong asset |
| C022-C028 Đồ ăn | Ảnh quán/món thực | `card_food`, `role_food`, `state_no_search` | Ảnh cũ chỉ là placeholder |
| C032-C048 Đơn/ưu đãi | Ảnh quán thực | `state_success`, `accent_promo_gift`, `state_no_orders` | Thanh toán là dữ liệu runtime |
| S002/S007 Onboarding/vai trò | `role_customer`, `role_shop`, `role_driver` | – | Chữ và CTA riêng trên Flutter |
| S015/S017 | – | `state_no_search`, `state_payment_error`, `state_offline` | Không hardcode UI error trong ảnh |
| M001-M013 Đăng ký Shop | – | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | KYC do backend xác minh |
| M015/M026 Shop vận hành | – | `state_no_orders`, ảnh món thực | Reuse template list/card |
| M040 Ưu đãi Shop | `banner_promo_gift` | `accent_promo_gift` | CTA nằm ngoài asset |
| D001/D016/D021 Tài xế | Map SDK | `role_driver`, `vehicle_delivery`, `accent_pickup_route` | Map realtime do SDK cung cấp |
| D018/D030/D033 | – | `state_no_driver`, `state_success`, `state_no_orders` | Driver ảnh minh họa, không giả hình xác minh |
| D044 An toàn | – | `state_security` | SOS ưu tiên icon + chữ contrast tốt |

## Định dạng gợi ý

- Dùng SVG cho icon/illustration đơn giản, tránh nhiều filter nếu dùng trên Flutter.
- Ảnh món/restaurant nên chuyển WebP/AVIF tùy hỗ trợ runtime, có placeholder và cache; lưu license/source khi có ảnh thật.
- PNG trong suốt dùng để tạo prototype nhanh; nếu DPI tăng cần dùng đúng kích thước hoặc SVG.
- Tài nguyên mới chỉ là **Batch 01 để duyệt phong cách**, chưa đóng băng Design System.
