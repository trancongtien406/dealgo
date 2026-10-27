---
doc_id: DG-OPS-001
title: "DealGo — Catalog biến môi trường và secret"
version: "1.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-26"
related_decisions:
  - ADR-006
  - OPEN-002
  - OPEN-008
  - DEC-PROD-020
  - DEC-PROD-045
  - DEC-PROD-050
  - DEC-PROD-051
  - DEC-PROD-052
  - DEC-PROD-053
  - DEC-PROD-054
  - DEC-PROD-058
---

# Catalog secret và biến môi trường

Tài liệu này liệt kê mọi biến môi trường mà backend, Admin web và app Flutter đọc. Nguồn chuẩn là code: `backend/src/platform/config/env.ts` (schema zod + kiểm tra production), `website/lib/api/*`, `mobile/lib/core/config/*`. Không commit giá trị thật; secret nằm trong secret store / CI secrets.

## Biến môi trường và cài đặt Admin

Các tham số nghiệp vụ (giá cước, điều phối, hoa hồng, phí huỷ, cửa sổ liên lạc, số ngày giữ chat…) là **cài đặt Admin** lưu trong bảng `PlatformSetting`, sửa ở Admin › Cài đặt › Tham số. Khi một khoá chưa có trong DB, server lấy giá trị env cùng tên (nếu có) làm giá trị khởi tạo rồi lưu vào DB; từ đó DB là nguồn duy nhất. Danh sách đầy đủ: [Bản đồ cài đặt Admin](../10-ai-execution/open-admin-settings-map.md).

Các khoá có cả env lẫn cài đặt Admin: `RIDE_OFFER_TTL_SECONDS`, `RIDE_MIN_FARE_VND`, `RIDE_MAX_FARE_VND`, `RIDE_REFERENCE_VND_PER_KM`, `FOOD_MIN_DELIVERY_VND`, `FOOD_MAX_DELIVERY_VND`, `FOOD_DELIVERY_VND_PER_KM`, `DRIVER_SEARCH_RADIUS_KM`, `MAX_CONCURRENT_JOBS_PER_DRIVER`, `PAYMENT_METHODS_ENABLED`, `CONTACT_WINDOW_MINUTES`. Với các khoá này env chỉ là giá trị khởi tạo.

## Backend (`backend/.env`)

Sao chép từ `backend/.env.example`. Cột "Production" nêu điều kiện mà `assertProductionProviders` kiểm tra lúc khởi động khi `NODE_ENV=production`; vi phạm thì server không khởi động.

### Runtime và hạ tầng

| Biến | Mặc định | Production | Ghi chú |
|---|---|---|---|
| `NODE_ENV` | `development` | `production` | `development` / `test` / `production` |
| `DEPLOY_ENV` | suy từ `NODE_ENV` | — | `local` / `staging` / `production`. Không đặt → `production` khi `NODE_ENV=production`, ngược lại `local` |
| `PORT` | `3001` | — | Cổng HTTP + Socket.IO |
| `DATABASE_URL` | — | Bắt buộc | Compose local: Postgres port **5433** (`postgresql://dealgo:<mật khẩu>@127.0.0.1:5433/dealgo?schema=public`) |
| `DATABASE_POOL_MAX` | `10` | — | Kết nối tối đa mỗi process (API, worker); tổng các process phải nhỏ hơn `max_connections` |
| `REDIS_URL` | — | Nên có | `/health` ping Redis; BullMQ worker và OTP throttle nhiều instance. Thiếu Redis (ngoài production) → worker chạy theo interval, throttle trong bộ nhớ |
| `TRUST_PROXY` | tắt | Khi sau load balancer | Số hop (vd `1`) hoặc CSV subnet / `loopback`. Sai giá trị → rate limit và IP trong audit sai |
| `CORS_ALLOWED_ORIGINS` | — | Đặt origin thật | CSV. Production dùng đúng danh sách này; ngoài production luôn cộng thêm `http://localhost:3000`, `http://localhost:3001`. Áp dụng cho cả HTTP và Socket.IO |
| `SWAGGER_ENABLED` | bật ngoài production | — | Swagger UI ở `/docs`. Không đặt → tắt ở production; `true`/`false` ghi đè |
| `PUBLIC_WEB_BASE_URL` | — | Nên có | Origin website cho link chia sẻ chuyến (production `https://dealgo.trancongtien.com`) |

### Xác thực

| Biến | Mặc định | Production | Ghi chú |
|---|---|---|---|
| `JWT_ACCESS_SECRET` | secret dev | Bắt buộc, khác secret dev | `JWT_SECRET` được nhận làm bí danh khi biến này trống |
| `JWT_ACCESS_TTL_SECONDS` / `JWT_REFRESH_TTL_SECONDS` | `3600` / `1209600` | — | |
| `WEBAUTHN_RP_ID`, `WEBAUTHN_RP_NAME`, `WEBAUTHN_ORIGIN` | — | Khi bật passkey | `WEBAUTHN_ORIGIN` là CSV origin web; origin Android `android:apk-key-hash` tự suy từ `APP_LINKS_ANDROID_CERT_SHA256`. `WEBAUTHN_RP_ID` phải trùng `APP_LINK_HOST` của app |
| `APP_LINKS_IOS_APP_IDS`, `APP_LINKS_ANDROID_PACKAGE`, `APP_LINKS_ANDROID_CERT_SHA256`, `APP_LINKS_PATHS` | — | Khi dùng universal link / passkey | Nest phục vụ `/.well-known/apple-app-site-association` và `/.well-known/assetlinks.json`; website proxy cùng domain. Trống → 404 |
| `OTP_THROTTLE_TTL_MS`, `OTP_THROTTLE_LIMIT` | `60000`, `10` | — | Giới hạn gửi OTP theo IP |
| `OTP_PHONE_LIMIT`, `OTP_PHONE_WINDOW_MS` | `5`, `900000` | — | Giới hạn SMS OTP theo số điện thoại, cộng thêm giới hạn theo IP |
| `APP_REVIEW_OTP_CODE` **SECRET** | — | Chỉ trong đợt duyệt store | 6 số. Chỉ nhận cho SĐT/email review cấu hình trong Admin (`APP_REVIEW_*`) khi `APP_REVIEW_LOGIN_ENABLED=true`; có audit và rate limit |
| `OPS_BOOTSTRAP_EMAIL`, `OPS_BOOTSTRAP_PASSWORD` | — | Mật khẩu khác `change-me-dev-only` | Tài khoản ops đầu tiên |

Phương thức đăng nhập (SĐT / email / passkey) bật tắt ở Admin › Cài đặt › Đăng nhập. Chỉ cần cấu hình provider cho phương thức đang bật.

### SMS và email

| Biến | Production | Ghi chú |
|---|---|---|
| `SMS_PROVIDER` | Không được `mock` | `esms` (chính) / `speedsms` (phụ) / `none`. `fake` là bí danh của `mock` |
| `ESMS_API_KEY`, `ESMS_SECRET_KEY`, `ESMS_BRANDNAME`, `ESMS_SMS_TYPE`, `ESMS_SANDBOX`, `ESMS_BASE_URL` | Ba khoá đầu bắt buộc khi `esms`; `ESMS_SANDBOX=true` bị từ chối | |
| `SPEEDSMS_ACCESS_TOKEN`, `SPEEDSMS_SENDER`, `SPEEDSMS_SMS_TYPE`, `SPEEDSMS_BASE_URL` | Token bắt buộc khi `speedsms` | |
| `SMS_OTP_TEMPLATE` | — | Phải trùng mẫu đã đăng ký với nhà mạng |
| `SMS_HTTP_TIMEOUT_MS`, `SMS_HTTP_MAX_ATTEMPTS` | — | Mặc định `8000`, `2` |
| `EMAIL_PROVIDER` | Không được `mock` | `ses` / `smtp` / `none`. Thiếu cấu hình → đăng ký email trả 503 `EMAIL_DELIVERY_FAILED`, không tạo tài khoản |
| `EMAIL_FROM` | Bắt buộc khi `ses` (identity đã xác minh) | Dùng `SMTP_FROM` nếu trống |
| `SES_REGION`, `SES_ACCESS_KEY_ID`, `SES_SECRET_ACCESS_KEY`, `SES_CONFIGURATION_SET` | Ba khoá đầu bắt buộc khi `ses` | |
| `SMTP_URL` hoặc `SMTP_HOST`/`SMTP_PORT`/`SMTP_USER`/`SMTP_PASSWORD`, `SMTP_FROM`, `SMTP_TLS` | `SMTP_URL` (hoặc bộ 4 biến) khi `smtp` | Bộ 4 biến được ghép thành `SMTP_URL` |
| `EMAIL_HTTP_TIMEOUT_MS` | — | Mặc định `10000` |

### Bản đồ và định tuyến

| Biến | Production | Ghi chú |
|---|---|---|
| `MAPS_PROVIDER` | Bắt buộc `mapbox` / `goong` / `google` kèm key | Geocoding / tìm địa điểm |
| `MAPBOX_ACCESS_TOKEN` | Khi `mapbox` (hoặc `MAPBOX_DIRECTIONS_TOKEN`) | Token public `pk.*` |
| `GOONG_API_KEY` | Khi `MAPS_PROVIDER=goong` | |
| `GOOGLE_MAPS_API_KEY` **SECRET** | Tuỳ chọn | Chỉ ở server. Bật Google Maps làm nhà cung cấp thứ hai mà Admin chọn được theo từng chức năng (Cài đặt › Bản đồ). Key cần Places API (New), Geocoding API, Routes API; nên giới hạn theo IP server và theo 3 API này. Trống → Admin hiện Google "Chưa cấu hình", mọi chức năng dùng Mapbox. Cũng dùng được với `MAPS_PROVIDER=google`. Xem `05-architecture/places-search.md` |
| `PLACES_OSM_SEARCH_URL` | Tuỳ chọn; nếu đặt thì là Photon tự host (bản trích Việt Nam), ví dụ `http://photon:2322` | Thêm ứng viên OSM cho tìm địa điểm (bù chỗ Mapbox thiếu tên đường ở VN). Trống → chỉ Mapbox. Không dùng `photon.komoot.io` cho production (fair-use, chỉ cho dev). Xem `05-architecture/places-search.md` |
| `ROUTING_PROVIDER` | Bắt buộc `mapbox` hoặc `osrm` | Hình học đường đi và ETA cho Admin và app. Ngoài production, không đặt / `none` → đường thẳng |
| `MAPBOX_DIRECTIONS_TOKEN` | Bắt buộc khi `ROUTING_PROVIDER=mapbox` | Chỉ dùng ở server; không dùng `NEXT_PUBLIC_MAPBOX_TOKEN` cho Directions |
| `ROUTING_OSRM_URL` | Bắt buộc khi `osrm`, phải là server tự host | Server demo `router.project-osrm.org` bị từ chối ở production |
| `ROUTING_TIMEOUT_MS` | — | Mặc định `4000` |

### Push, voice, chat

| Biến | Production | Ghi chú |
|---|---|---|
| `PUSH_PROVIDER` | Bắt buộc `fcm` | FCM HTTP v1 |
| `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` **SECRET** hoặc `FCM_SERVICE_ACCOUNT_PATH` / `GOOGLE_APPLICATION_CREDENTIALS` | Bắt buộc một trong hai cách | Xem [push-notifications.md](push/push-notifications.md) |
| `VOICE_PROVIDER` | `livekit` khi mở gọi thoại; `mock` bị từ chối | Không đặt / `none` → API gọi trả 503 `VOICE_UNAVAILABLE`, app ẩn nút gọi. `mock` chỉ cho test (token giả). `livekit` → server ký JWT LiveKit chỉ cho phép publish/subscribe audio, phạm vi một phòng/chuyến, hết hạn 10 phút |
| `LIVEKIT_URL` | Bắt buộc khi `livekit`, phải `wss://` (production từ chối `ws://`, không khởi động) | URL signalling app kết nối. Production tự host: `wss://livekit.<domain>` từ bộ `deploy/livekit` (runbook `docs/09-operations/livekit-self-host.md`); bản release của app cũng chỉ nhận `wss://`. Dev: `docker compose up -d livekit`, `ws://<IP LAN của máy dev>:7880` (điện thoại không tới được `localhost`). Chạy `LIVEKIT_NODE_IP=<cùng IP LAN> docker compose up -d livekit` để LiveKit quảng bá IP đó trong ICE candidate thay cho IP container `172.x` |
| `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` **SECRET** | Bắt buộc khi `livekit`; secret ≥ 32 ký tự | Phải đặt cùng nhau. Production: `deploy/livekit/gen-keys.sh` tạo trên VPS `keys.yaml` (file khoá của LiveKit) và `backend.env.snippet`, cả hai chmod 600, không in secret; chép 3 dòng vào env production rồi xoá snippet. Dev: `devkey` / `secret` (mặc định của `livekit-server --dev`) |
| `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID` | Nên đặt khi mở gọi thoại trên iOS | Không bí mật, đã điền sẵn: `TL36K38ZKR`, `6J3522877H`, `com.trancongtien.dealgo`. Dùng để gửi push PushKit (VoIP), giúp CallKit đổ chuông khi app iOS ở nền hoặc đã tắt. Topic là `<APNS_BUNDLE_ID>.voip`. Nếu chưa có khoá, server không gửi VoIP và cuộc gọi vẫn báo qua push FCM thường. Xem [push-notifications.md](push/push-notifications.md) |
| `APNS_KEY_PATH` (tên cũ `APNS_PRIVATE_KEY_PATH`) hoặc `APNS_PRIVATE_KEY` **SECRET** | Đi cùng các biến `APNS_*` ở trên | Đường dẫn tới file `AuthKey_TL36K38ZKR.p8` (APNs Auth Key theo team, dùng được cho cả Sandbox lẫn Production), hoặc dán nội dung PEM vào biến. Đây là chính khoá đã tải lên Firebase Cloud Messaging. Không commit file `.p8` (`*.p8` đã nằm trong .gitignore). Ở production, nếu đặt mà file không đọc được, khoá sai, hoặc thiếu key id/team id thì server không khởi động |
| `APNS_ENV` (`sandbox` \| `production`), `APNS_SANDBOX` | `production` ở production | `sandbox` gửi tới `api.sandbox.push.apple.com` (bản debug cài từ Xcode); `production` gửi tới `api.push.apple.com` (TestFlight / App Store). Nếu không đặt: theo `APNS_SANDBOX`, nếu cũng không có thì theo `NODE_ENV` |
| `CHAT_ENCRYPTION_KEY` **SECRET** | Bắt buộc | Base64 đúng 32 byte (`openssl rand -base64 32`); kiểm tra định dạng ở mọi môi trường |
| `CHAT_ENCRYPTION_KEY_VERSION`, `CHAT_ENCRYPTION_PREVIOUS_KEYS` | — | Xoay khoá: [chat-encryption-keys.md](chat-encryption-keys.md) |
| `CONTACT_WINDOW_MINUTES` | — | Giá trị khởi tạo cho cài đặt Admin cùng tên (mặc định 120) |

### Thanh toán

| Biến | Production | Ghi chú |
|---|---|---|
| `PAYMENT_PROVIDER` | Bắt buộc `cash-only`, `vnpay` hoặc `momo` | `cash-only` = ra mắt chỉ tiền mặt. `sandbox` (mặc định dev, `fake` là bí danh) bị từ chối ở production. `vnpay`/`momo` tạo intent chuyển hướng `PENDING_REDIRECT`, webhook kiểm chữ ký; chưa có capture thật |
| `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `VNPAY_URL` | Bắt buộc khi `vnpay` | |
| `MOMO_PARTNER_CODE`, `MOMO_ACCESS_KEY`, `MOMO_SECRET_KEY`, `MOMO_ENDPOINT` | Bắt buộc khi `momo` | |

### Lưu trữ file và đối tác

| Biến | Mặc định | Ghi chú |
|---|---|---|
| `OBJECT_STORAGE_PROVIDER` | test → `memory`, development → `local`, production → không có (upload trả 503) | `memory` / `local` / `s3` |
| `OBJECT_STORAGE_LOCAL_DIR` | `./var/object-storage` | Khi `local` |
| `S3_ENDPOINT`, `S3_REGION`, `S3_BUCKET`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY` | — | Khi `s3`; thiếu → upload trả 503. Bí danh: `S3_BUCKET_NAME`, `S3_API_ENDPOINT`. URL tải có hạn |
| `KYC_STORAGE_PROVIDER` | — | Bí danh cũ: `s3` chọn S3 khi `OBJECT_STORAGE_PROVIDER` trống. Cấu hình mới dùng `OBJECT_STORAGE_PROVIDER` |
| `PARTNER_ELIGIBILITY_BYPASS` | `true` chỉ khi `DEPLOY_ENV=local` | Bỏ qua KYC/KYB đã duyệt khi tài xế xem đơn / nhận đơn đồ ăn. `true` bị từ chối khi `NODE_ENV` hoặc `DEPLOY_ENV` là production |
| `PARTNER_CAR_KYC_EXTRA_DOCS` | `true` ở production, `false` nơi khác | Tài xế ô tô phải có `VEHICLE_INSURANCE` khi nộp hồ sơ và gửi giá |

### Điều phối, vị trí và worker

| Biến | Mặc định | Ghi chú |
|---|---|---|
| `DISPATCH_FALLBACK_LIMIT` | `20` | Số đơn tối đa trả về khi tài xế không gửi toạ độ |
| `DRIVER_LOCATION_ON_TRIP_INTERVAL_MS` / `DRIVER_LOCATION_IDLE_INTERVAL_MS` | `5000` / `15000` | Chu kỳ gửi GPS khi đang chở / rảnh |
| `DRIVER_LOCATION_ON_TRIP_MIN_DISTANCE_M` / `DRIVER_LOCATION_IDLE_MIN_DISTANCE_M` | `10` / `50` | Quãng đường tối thiểu giữa hai lần gửi |
| `DRIVER_LOCATION_MAX_SILENCE_MS` | `30000` | Khoảng im lặng tối đa |
| `DRIVER_LOCATION_MIN_ACCEPT_INTERVAL_MS` | `1000` | Server bỏ qua cập nhật dày hơn mức này |
| `RIDE_EXPIRY_INTERVAL_MS`, `OUTBOX_RELAY_INTERVAL_MS` | `5000`, `2000` | Chu kỳ worker hết hạn chuyến và relay outbox |
| `UPLOAD_ORPHAN_CLEANUP_INTERVAL_MS` | 6 giờ | Ngưỡng tuổi file là cài đặt Admin |
| `ACCOUNT_PURGE_INTERVAL_MS` | 1 giờ | Ẩn danh tài khoản đã hết thời gian chờ xoá |
| `CHAT_RETENTION_PURGE_INTERVAL_MS` | 1 giờ | Số ngày giữ chat là cài đặt Admin `CHAT_RETENTION_DAYS` |
| `WORKER_HEARTBEAT_INTERVAL_MS`, `WORKER_HEARTBEAT_STALE_MS` | `15000`, `60000` | `/health/worker` trả 503 khi worker im lặng quá ngưỡng |
| `OUTBOX_LAG_ALERT_MS`, `OPS_ALERT_WEBHOOK_URL` | `60000`, — | Cảnh báo `worker.down` / `outbox.lag` ghi log và gửi webhook |

### Giám sát

| Biến | Ghi chú |
|---|---|
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | DSN trống = tắt |
| `LOG_FORMAT` | `json` mặc định ở production |

### Seed

| Biến | Ghi chú |
|---|---|
| `SEED_ALLOW_PRODUCTION` | Seed từ chối chạy khi `NODE_ENV=production` trừ khi biến này là `true` (dùng một lần, có chủ đích) |
| `SEED_USER_PASSWORD` | Mật khẩu user demo; trống → dùng `OPS_BOOTSTRAP_PASSWORD`; ngoài production nếu cả hai trống thì sinh ngẫu nhiên và in một lần |

## Admin web (`website/.env.local`)

Sao chép từ `website/.env.example`.

| Biến | Vai trò |
|---|---|
| `DEALGO_API_BASE_URL` (hoặc `API_BASE_URL`) | Origin Nest cho các lệnh gọi BFF phía server; mặc định `http://localhost:3001` |
| `NEXT_PUBLIC_API_BASE_URL` | Đọc lúc build, chỉ để thêm origin vào CSP `connect-src`. Trình duyệt luôn gọi BFF cùng origin |
| `NEXT_PUBLIC_MAPBOX_TOKEN` | Token public `pk.*` (giới hạn URL trong Mapbox) cho tile bản đồ Admin. Trống → tile OSM/Carto. Đường đi lấy từ API định tuyến của server |
| `NEXT_PUBLIC_APP_ENV` | Nhãn môi trường hiển thị ở trang Cài đặt (mặc định `DEVELOPMENT`) |
| `OPS_SESSION_PROBE_TTL_MS` | Thời gian cache kết quả kiểm tra phiên ops thành công; mặc định 15 s, giới hạn 5–30 s |
| `NEXT_PUBLIC_SENTRY_DSN`, `NEXT_PUBLIC_SENTRY_ENVIRONMENT`, `NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE`, `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | Sentry; trống = không tải SDK |
| `NEXT_OUTPUT=standalone` | Build Docker (`website/Dockerfile`) |

Phiên ops lưu trong cookie do BFF `/api/ops/session` đặt; không lưu token trong `localStorage`. Không đặt token hay secret trong biến `NEXT_PUBLIC_*`.

## App Flutter (`--dart-define`)

| Biến | Mặc định | Vai trò |
|---|---|---|
| `API_BASE_URL` | debug/profile `http://localhost:3001`; release `https://api-dealgo.trancongtien.com` | Origin Nest (REST + Socket.IO cùng host), trùng `PORT` mặc định của backend; `mobile/tool/run_dev.sh` dùng cùng mặc định. Android emulator: `http://10.0.2.2:3001`. Bản release từ chối `http://`; bản debug chỉ cho `http://` với `localhost`, `127.0.0.1`, `10.0.2.2` |
| `USE_MOCK_DATA` | `false` | `true` = dùng client giả và dữ liệu seed, không cần backend |
| `MAPS_API_KEY` | — | **Bắt buộc cho mọi bản build dùng bản đồ thật** (debug, simulator, release). Token Mapbox public `pk.*`; tile mặc định Mapbox Streets `streets-v12`. `mobile/tool/run_dev.sh` truyền sẵn từ `MAPBOX_ACCESS_TOKEN`; lệnh `flutter build`/`flutter run` tự gõ phải thêm `--dart-define=MAPS_API_KEY=…` và `MAP_ATTRIBUTION`. Thiếu → bản đồ minh hoạ (`PlaceholderMapPort`): không có tile, nhưng điểm đón/đến và tuyến vẫn vẽ đúng toạ độ thật theo phép chiếu. Tuyến đường luôn lấy từ server (routing) |
| `MAP_TILE_URL`, `MAP_ATTRIBUTION` | — | Ghi đè nguồn tile (`https://…/{z}/{x}/{y}…{key}`). Không dùng tile OSM công cộng cho production. Bản đồ giữ một tile provider suốt vòng đời màn hình; chỉ lớp tuyến chạy hiệu ứng, nên tile không tải lại theo từng khung hình |
| `APP_LINK_HOST` | `dealgo.trancongtien.com` | Domain universal link + passkey; phải trùng `dealgoAppLinkHost` (`android/gradle.properties`), `DEALGO_APP_LINK_HOST` (`ios/Flutter/*.xcconfig`) và `WEBAUTHN_RP_ID` |
| `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | trống, `production`/`development` theo build, `0` | Crash reporting; DSN trống = tắt |
| `SMOKE_ACCESS_TOKEN`, `SMOKE_REFRESH_TOKEN` | — | Chỉ cho smoke test tự động |

Khác:

- `android/key.properties` (git-ignore; mẫu `android/key.properties.example`) ký bản release Android; thiếu thì `assembleRelease` dừng với thông báo rõ.
- Chỉ để thử R8 trên máy dev khi chưa có keystore: `ORG_GRADLE_PROJECT_dealgoDebugSignRelease=true flutter build apk --release` ký bằng khoá debug (Gradle in cảnh báo). Bản này không được tải lên Play. Trên Mac dùng JDK đi kèm Android Studio cho riêng lệnh build: `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`.
- Access/refresh token lưu trong secure storage.
- Không nhúng FCM private key, payment secret hay khoá ký API trong binary app.

## Thứ tự điền key khi lên staging

1. `DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`, `DEPLOY_ENV=staging`, `CORS_ALLOWED_ORIGINS`
2. Chọn phương thức đăng nhập trong Admin; điền provider cho phương thức đang bật: `SMS_PROVIDER` + eSMS/SpeedSMS, `EMAIL_PROVIDER` + SES/SMTP, `WEBAUTHN_*` + `APP_LINKS_*`
3. `CHAT_ENCRYPTION_KEY`, `TRUST_PROXY`, `SENTRY_DSN`, `OPS_ALERT_WEBHOOK_URL`
4. `MAPS_PROVIDER` + key, `ROUTING_PROVIDER` + `MAPBOX_DIRECTIONS_TOKEN` hoặc OSRM tự host
5. `PUSH_PROVIDER=fcm` + thông tin service account; `APNS_*` (khoá `.p8`) cho cuộc gọi đến trên iOS
6. `PAYMENT_PROVIDER=cash-only` (hoặc `vnpay`/`momo` khi `OPEN-002` được duyệt)
7. `OBJECT_STORAGE_PROVIDER=s3` + `S3_*`
8. `VOICE_PROVIDER=livekit` + `LIVEKIT_*` (LiveKit Cloud hoặc server tự host bằng `deploy/livekit`, có TURN/TLS trên 443), rồi bật `VOICE_CALLS_ENABLED` ở Admin › Cài đặt

## Kiểm tra trước production

- [ ] Server khởi động với `NODE_ENV=production` (mọi kiểm tra trong `env.ts` đều qua)
- [ ] `OPS_BOOTSTRAP_PASSWORD` không phải `change-me-dev-only`
- [ ] `PARTNER_ELIGIBILITY_BYPASS` không đặt; `PARTNER_CAR_KYC_EXTRA_DOCS` không đặt `false`
- [ ] `OBJECT_STORAGE_PROVIDER=s3` và upload thử thành công
- [ ] `CORS_ALLOWED_ORIGINS` chỉ chứa origin thật; `SWAGGER_ENABLED` không bật
- [ ] App build release không có `USE_MOCK_DATA=true`, `API_BASE_URL` là `https://`, có `MAPS_API_KEY`
- [ ] `APNS_ENV=production` và `APNS_KEY_PATH` trỏ tới `AuthKey_TL36K38ZKR.p8` (team `6J3522877H`) khi bật gọi thoại trên iOS. Log khởi động `VoipPush` phải báo `iOS VoIP pushes on`
- [ ] Secret nằm ở vault / CI secrets, không trong git
- [ ] `APP_REVIEW_LOGIN_ENABLED` tắt sau khi duyệt xong; `APP_REVIEW_OTP_CODE` đổi mỗi đợt
- [ ] `/.well-known/apple-app-site-association` và `assetlinks.json` trả 200 trên domain thật
- [ ] `android/key.properties` và keystore được backup ngoài git
