# DealGo Mobile Asset Library — Batch 01

Đường dẫn trong monorepo: `design/assets/batch01/`.

Bộ **26 asset illustration/vector gốc** theo trang chủ DealGo đã chốt; cộng **7 ảnh đồ ăn hiện có** để dùng mẫu.

## Nguyên tắc
- Giữ nguyên wordmark/logo đã chốt ở C001; không thay logo bằng chữ/icon mới.
- Tài nguyên vector SVG được tạo dưới dạng source độc lập; PNG xuất đúng kích thước, giữ alpha cho illustration trong suốt.
- Đặt **text, CTA, icon chức năng và giá tiền trong Flutter**, không vẽ vào banner.
- Icon điều hướng và trạng thái phải dùng cùng 1 họ icon Flutter, không crop từ bảng thiết kế sinh ảnh.
- Hero Đà Nẵng trong pack là **minh họa cầu Rồng cách điệu**, không thay thế ảnh banner thực tế của C001 nếu chưa duyệt.

## Số lượng theo nhóm
- `accent`: 2
- `banners`: 2
- `role_illustrations`: 4
- `service_cards`: 4
- `states`: 10
- `vehicles`: 4

## Cấu trúc
- `svg/`: SVG original có thể tùy biến qua code
- `png/`: PNG dùng trực tiếp trong Flutter
- `photos/`: ảnh món ăn minh họa từ mockup cũ (cần thay bằng ảnh đối tác thực khi chạy thật)
- `previews/`: bảng duyệt hình ảnh theo nhóm
- `docs/asset_manifest.csv`: bảng map file → màn hình gợi ý
- `docs/assets.json`: metadata cấu trúc

## Flutter ví dụ
```dart
Image.asset('assets/dealgo/png/card_ride.png', fit: BoxFit.cover);
Image.asset('assets/dealgo/png/vehicle_motorbike.png', fit: BoxFit.contain);
// SVG: flutter_svg package (kiểm tra phiên bản tương thích trước khi cài)
SvgPicture.asset('assets/dealgo/svg/state_no_orders.svg');
```

## Kích thước
- Banner: 1200×480 và 1200×280 px
- Card: 680×360 px
- Xe: 520×320 px (trong suốt)
- Illustration vai trò: 500×380 px (trong suốt)
- Trạng thái: 512×512 px (trong suốt)

## Việc cần duyệt trước khi dùng production
- Asset style: minh họa vector/soft gradient so với banner ảnh chụp thật ở trang chủ.
- Tối ưu SVG/PNG theo mục tiêu dung lượng và nền tảng.
- Asset dark theme nếu app bật dark mode.
- Kiểm tra contrast, alt semantics và fit trên thiết bị thật.
