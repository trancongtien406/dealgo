# DealGo – Asset Library Batch 02 / Flutter Handoff

## Cấu trúc
- `png/`: ảnh PNG tương thích rộng; file tên `asset_id.png`.
- `webp/`: ảnh WebP chất lượng 87, phù hợp phát hành, dùng bản có alpha khi cần.
- `docs/asset_manifest.csv`: kích thước, nguồn dựng và màn hình sử dụng.
- `previews/`: contact sheet để review.

## Flutter
```yaml
flutter:
  assets:
    - assets/dealgo/batch02/webp/
```

```dart
Image.asset('assets/dealgo/batch02/webp/service_ride_clean.webp', fit: BoxFit.cover);
```

Với banner dùng `AspectRatio` hoặc `ClipRRect` + `BoxFit.cover`, overlay chữ/nút bằng Flutter `Stack`, tuyệt đối không bake text vào ảnh. Có thể chọn vùng cắt bằng `alignment` và thêm gradient foreground để bảo vệ độ tương phản.

## Lưu ý chất lượng và nguồn
- Bản này là tài nguyên prototype/visual handoff. Một phần nguồn gốc được crop từ ảnh minh họa hiện có và upscale để phù hợp khung mockup; **kích thước pixel xuất lớn không đồng nghĩa ảnh nguồn có độ phân giải cao tương đương**.
- Ảnh phương tiện, cửa hàng từ concept sheet nhỏ: dùng thumbnail, cần chốt tài nguyên gốc độ phân giải cao trước khi public production.
- Nếu ảnh cửa hàng có dấu hiệu thương hiệu, không dùng để đại diện shop thật nếu chưa có quyền sử dụng.
- Không thay logo DealGo/C001 đã duyệt.
- Tài nguyên bản đồ/phương tiện trong mockup không chứng minh tọa độ, hình xe hoặc nhãn thực tế.
