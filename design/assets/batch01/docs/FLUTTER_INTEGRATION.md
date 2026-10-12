# Tích hợp DealGo Assets vào Flutter

## Cấu trúc đề xuất

```
mobile/
  assets/dealgo/
    svg/
    png/
    photos/
  lib/core/theme/
    dealgo_colors.dart
    dealgo_theme.dart
  lib/core/widgets/
    dealgo_illustration.dart
    dealgo_service_card.dart
    dealgo_state_view.dart
```

## `pubspec.yaml` 

```yaml
flutter:
  assets:
    - assets/dealgo/png/
    - assets/dealgo/svg/
    - assets/dealgo/photos/
```

Có thể dùng `flutter_svg` để hiển thị SVG, nhưng cần kiểm tra phiên bản tương thích với Flutter/Dart của dự án trước khi chọn phiên bản package.

## Ví dụ

```dart
import 'package:flutter/material.dart';

class DealGoIllustration extends StatelessWidget {
  const DealGoIllustration({super.key, required this.name, this.width = 180});
  final String name;
  final double width;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/dealgo/png/$name.png',
    width: width,
    fit: BoxFit.contain,
    semanticLabel: name.replaceAll('_', ' '),
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
```

## Notes

- Không hardcode giá, biển số, địa chỉ hoặc tình trạng nghiệp vụ trong asset hình ảnh.
- Đặt ảnh trong `AspectRatio`, xác định `BoxFit.cover/contain` theo banner hay illustration.
- Không vẽ font/icon UI vào bitmap. Flutter là nguồn chân lý cho localizations, accessiblity và interaction.
- Cần golden test ở nhiều device size, scale chữ 1.0x/1.3x/2.0x và trạng thái dark mode (nếu bật).
