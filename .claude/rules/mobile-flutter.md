# Flutter Mobile — DealGo

Áp dụng khi làm việc trong `mobile/`. Chi tiết đầy đủ: `.cursor/rules/mobile-flutter.mdc`.

- Một app multi-role (Customer / Merchant / Driver); không tách ba app.
- Server là nguồn sự thật; không dùng cache/push làm truth cho booking/payment.
- Scaffold hiện tại chưa khóa Bloc / get_it / go_router / Dio bằng ADR — đề xuất thì ghi `PROPOSAL`.
- Tôn trọng `pubspec.yaml`, `analysis_options.yaml` và code đang có.
- Sau thay đổi: `dart format`, `flutter analyze`, test liên quan khi có môi trường.
