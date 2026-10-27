# DealGo Mobile

Ứng dụng Flutter một bản cho ba vai trò **Customer / Driver / Merchant**, phục vụ Ride và Food.

## Chạy

```bash
flutter pub get
./tool/run_dev.sh   # API mặc định http://localhost:3001; Android emulator: API_BASE_URL=http://10.0.2.2:3001
```

Các `--dart-define` chính: `API_BASE_URL` (mặc định `http://localhost:3001`, trùng cổng mặc định của backend), `USE_MOCK_DATA`, `MAPS_API_KEY`, `MAP_TILE_URL`, `SENTRY_DSN`. Bản release từ chối `API_BASE_URL` dạng `http://`.

## Kiểm tra

```bash
flutter analyze
flutter test
```

## Ghi chú

- Package ID: `com.trancongtien.dealgo` (Android / iOS).
- Kiến trúc: `go_router`, `flutter_bloc` (Cubit), `get_it` + `injectable`, một Dio dùng chung; realtime qua Socket.IO; push qua Firebase Cloud Messaging.
- Hiện trạng và khoảng trống: [`../docs/10-ai-execution/mobile-flutter-gap-matrix.md`](../docs/10-ai-execution/mobile-flutter-gap-matrix.md).
- Mockup và asset UI ở `../design/`.
