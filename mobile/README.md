# DealGo Mobile

Ứng dụng Flutter một bản cho ba vai trò **Customer / Driver / Merchant**, phục vụ Ride và Food.

## Chạy

```bash
flutter pub get
./tool/run_dev.sh   # API mặc định http://localhost:3001; Android emulator: API_BASE_URL=http://10.0.2.2:3001
```

Các `--dart-define` chính: `API_BASE_URL` (debug/profile mặc định `http://localhost:3001`; release mặc định `https://api-dealgo.trancongtien.com`), `APP_LINK_HOST` (mặc định `dealgo.trancongtien.com`), `USE_MOCK_DATA`, `MAPS_API_KEY`, `MAP_TILE_URL`, `SENTRY_DSN`. Bản release từ chối `API_BASE_URL` dạng `http://`.

## Build production

Bản release tự trỏ về VPS, không cần truyền `API_BASE_URL`:

| Thành phần | Production | Cấu hình ở |
|---|---|---|
| REST + Socket.IO | `https://api-dealgo.trancongtien.com` (socket `wss://` cùng host) | `lib/core/config/api_base_url.dart` (`prodApiBaseUrl`) |
| LiveKit (gọi thoại) | `wss://livekit-dealgo.trancongtien.com` | Server trả về (`LIVEKIT_URL` trong `backend.env` VPS) |
| Ảnh / avatar | đường dẫn tương đối ghép vào API host | `resolveMediaUrl` |
| Universal link, passkey, link web | `dealgo.trancongtien.com` (`/app/*`) | `APP_LINK_HOST` (`lib/core/config/app_env.dart`), `ios/Flutter/*.xcconfig`, `android/gradle.properties` |

```bash
cd mobile
MAPS_KEY="$(grep '^MAPBOX_ACCESS_TOKEN=' ../backend/.env | cut -d= -f2-)"   # token public pk.*
DEFINES=(--dart-define="MAPS_API_KEY=$MAPS_KEY" --dart-define="MAP_ATTRIBUTION=© Mapbox © OpenStreetMap")

flutter build ipa --release "${DEFINES[@]}"         # iOS, team 6J3522877H
flutter build appbundle --release "${DEFINES[@]}"   # Android, cần android/key.properties
flutter run --release -d <thiết bị> "${DEFINES[@]}" # chạy thử bản release với API VPS
```

Profile build vẫn dùng API local; thêm `--dart-define=API_BASE_URL=https://api-dealgo.trancongtien.com` nếu cần đo trên VPS.
Chạy debug với API VPS: `API_BASE_URL=https://api-dealgo.trancongtien.com ./tool/run_dev.sh`.

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
