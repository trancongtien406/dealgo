# DealGo Mobile

Ứng dụng Flutter một bản cho ba vai trò **Customer / Driver / Merchant**, phục vụ Ride và Food.

## Chạy

```bash
flutter pub get
./tool/run_dev.sh   # API mặc định http://localhost:3001; Android emulator: API_BASE_URL=http://10.0.2.2:3001
```

Các `--dart-define` chính: `API_BASE_URL` (debug/profile mặc định `http://localhost:3001`; release mặc định `https://api-dealgo.laptrinhapp.com`), `APP_LINK_HOST` (mặc định `dealgo.laptrinhapp.com`), `USE_MOCK_DATA`, `MAPS_API_KEY`, `MAP_TILE_URL`, `SENTRY_DSN` (mặc định bật ở build có flavor/release, rỗng = tắt). Bản release từ chối `API_BASE_URL` dạng `http://`.

## Build production

Bản release tự trỏ về VPS, không cần truyền `API_BASE_URL`:

| Thành phần | Production | Cấu hình ở |
|---|---|---|
| REST + Socket.IO | `https://api-dealgo.laptrinhapp.com` (socket `wss://` cùng host) | `lib/core/config/api_base_url.dart` (`prodApiBaseUrl`) |
| LiveKit (gọi thoại) | `wss://livekit-dealgo.laptrinhapp.com` | Server trả về (`LIVEKIT_URL` trong `backend.env` VPS) |
| Ảnh / avatar | đường dẫn tương đối ghép vào API host | `resolveMediaUrl` |
| Universal link, passkey, link web | `dealgo.laptrinhapp.com` (`/app/*`) | `APP_LINK_HOST` (`lib/core/config/app_env.dart`), `ios/Flutter/*.xcconfig`, `android/gradle.properties` |

```bash
cd mobile
MAPS_KEY="$(grep '^MAPBOX_ACCESS_TOKEN=' ../backend/.env | cut -d= -f2-)"   # token public pk.*
DEFINES=(--dart-define="MAPS_API_KEY=$MAPS_KEY" --dart-define="MAP_ATTRIBUTION=© Mapbox © OpenStreetMap")

flutter build ipa --release "${DEFINES[@]}"         # iOS, team 6J3522877H
flutter build appbundle --release "${DEFINES[@]}"   # Android, cần android/key.properties
flutter run --release -d <thiết bị> "${DEFINES[@]}" # chạy thử bản release với API VPS
```

Profile build vẫn dùng API local; thêm `--dart-define=API_BASE_URL=https://api-dealgo.laptrinhapp.com` nếu cần đo trên VPS.
Chạy debug với API VPS: `API_BASE_URL=https://api-dealgo.laptrinhapp.com ./tool/run_dev.sh`.

## Build bằng Xcode (scheme `dev` / `prod`)

Plugin iOS dùng Swift Package Manager, không dùng CocoaPods (`flutter config --enable-swift-package-manager`). Lần đầu (hoặc sau khi đổi plugin) chạy để sinh `ios/Flutter/Generated.xcconfig` và gói Swift `ios/Flutter/ephemeral/Packages`:

```bash
cd mobile && flutter pub get && flutter build ios --config-only --flavor dev
open ios/Runner.xcworkspace
```

| Scheme | Cấu hình (Run / Profile / Archive) | API | APNs | Tên trên máy |
|---|---|---|---|---|
| `dev` | `Debug-dev` / `Profile-dev` / `Release-dev` | Debug, Profile: `http://localhost:3001` (máy ảo); Release: VPS | Debug: development, còn lại: production | DealGo Dev |
| `prod` | `Debug-prod` / `Profile-prod` / `Release-prod` | luôn `https://api-dealgo.laptrinhapp.com` | Debug: development, còn lại: production | DealGo |
| `Runner` | `Debug` / `Profile` / `Release` | như `flutter run` / `flutter build ipa` không `--flavor` | như trên | DealGo |

- Cả ba dùng bundle id `dealgo.nguyengoctien.com`, team `6J3522877H`, associated domains `applinks:` + `webcredentials:`
  `dealgo.laptrinhapp.com` (`DEALGO_APP_LINK_HOST` trong `ios/Flutter/App.xcconfig`). Cài `dev` sẽ thay bản `prod` trên cùng máy.
- Scheme chọn flavor qua `FLAVOR` trong `ios/Flutter/Dev.xcconfig` / `Prod.xcconfig`; app đọc bằng `FLUTTER_APP_FLAVOR`
  (`lib/core/config/api_base_url.dart`). `--dart-define=API_BASE_URL=...` vẫn thắng mọi mặc định.
- Build trong Xcode dùng `--dart-define` của lần chạy `flutter` gần nhất (lưu trong `Generated.xcconfig`). Token Mapbox app lấy
  từ Admin (`GET /v1/public/client-config`); `MAPS_API_KEY` chỉ là dự phòng khi Admin để trống.
- CLI tương đương: `flutter run --flavor dev`, `flutter build ipa --flavor prod`.

Kiểm tra cấu hình: `xcodebuild -list -workspace ios/Runner.xcworkspace` phải có scheme `dev`, `prod`, `Runner`.

## Kiểm tra

```bash
flutter analyze
flutter test
```

## Ghi chú

- Package ID: `dealgo.nguyengoctien.com` (Android / iOS).
- Kiến trúc: `go_router`, `flutter_bloc` (Cubit), `get_it` + `injectable`, một Dio dùng chung; realtime qua Socket.IO; push qua Firebase Cloud Messaging.
- Hiện trạng và khoảng trống: [`../docs/10-ai-execution/mobile-flutter-gap-matrix.md`](../docs/10-ai-execution/mobile-flutter-gap-matrix.md).
- Mockup và asset UI ở `../design/`.

## Release iOS + Sentry symbols

`tool/release_ios.sh` builds the IPA with `--obfuscate --split-debug-info=build/debug-info`
and then runs `dart run sentry_dart_plugin` to upload Dart debug symbols and the iOS
dSYMs to Sentry (org `tiendev`, project `flutter`, block `sentry:` in `pubspec.yaml`).

```bash
export SENTRY_AUTH_TOKEN=<token org Sentry, scope project:releases + project:write>  # không commit
tool/release_ios.sh
```

Without `SENTRY_AUTH_TOKEN` (or a gitignored `sentry.properties`) the build still
runs and only the upload is skipped. An archive made from the Xcode UI does not
obfuscate or split debug info, so Sentry cannot symbolicate Dart frames for it;
use the script for TestFlight/App Store builds.
