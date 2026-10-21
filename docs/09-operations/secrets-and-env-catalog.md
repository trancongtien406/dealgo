---
doc_id: DG-OPS-001
title: "DealGo — Catalog biến môi trường và secret"
version: "0.1.1"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-18"
related_decisions:
  - ADR-006
  - OPEN-002
  - OPEN-008
---

# Catalog secret và biến môi trường

Mục tiêu: sau này chỉ điền key vào `.env` / secret store. Không commit giá trị thật. Adapter mặc định là `mock` hoặc `sandbox`.

## Backend (`backend/.env`)

Sao chép từ `backend/.env.example`.

| Nhóm | Biến | Khi nào bắt buộc | Ghi chú |
|---|---|---|---|
| Runtime | `NODE_ENV`, `PORT` | Luôn | API mặc định `3001` |
| Postgres | `DATABASE_URL` | Luôn (trừ `NODE_ENV=test`) | Compose local: port **5433** → `postgresql://dealgo:dealgo_dev@127.0.0.1:5433/dealgo?schema=public` |
| Postgres pool | `DATABASE_POOL_MAX` | Optional | Số kết nối tối đa mỗi process (API, worker) — mặc định `10`; tổng các process phải dưới `max_connections` |
| Redis | `REDIS_URL` | Health + BullMQ workers + OTP throttler multi-instance | Ping ở `/health`; missing Redis → interval workers + in-memory OTP throttle non-prod |
| Workers | `RIDE_EXPIRY_INTERVAL_MS`, `OUTBOX_RELAY_INTERVAL_MS` | Optional | Defaults 5000 / 2000 ms |
| JWT | `JWT_ACCESS_SECRET`, TTL access/refresh | Luôn | Production từ chối secret dev |
| WebAuthn | `WEBAUTHN_RP_ID`, `WEBAUTHN_RP_NAME`, `WEBAUTHN_ORIGIN` | Passkey | Local: `localhost` |
| Maps | `MAPS_PROVIDER`, `GOONG_API_KEY` hoặc `GOOGLE_MAPS_API_KEY` | Khi không `mock` | Fail-closed without key; ride fare falls back to haversine |
| Maps (app) | `--dart-define=MAP_TILE_URL=https://…/{z}/{x}/{y}.png?key={key}`, `MAPS_API_KEY`, `MAP_ATTRIBUTION` | Bản đồ thật trên app | Thiếu/không hợp lệ → bản đồ minh hoạ; không dùng tile OSM công cộng cho production (DEC-PROD-030) |
| Maps (Admin web) | `NEXT_PUBLIC_MAPBOX_TOKEN=pk.…` trong `website/.env.local` (public token, giới hạn URL trong Mapbox) | Tile + chỉ đường Mapbox trên bản đồ Admin | Trống → tile OSM/Carto + OSRM kèm ghi nguồn; mã không chứa token mặc định (DEC-PROD-032) |
| SMS | `SMS_PROVIDER`, `ESMS_*` hoặc `TWILIO_*` | Khi không `mock` | Production từ chối `mock` |
| Email | `EMAIL_PROVIDER`, `SMTP_URL` (hoặc `SMTP_HOST/PORT/USER/PASSWORD`), `SMTP_FROM` | Khi không `mock` | OTP đăng ký email, xác minh email đổi trong hồ sơ, đặt lại mật khẩu; thiếu cấu hình → unavailable: đăng ký email trả 503 `EMAIL_DELIVERY_FAILED` (không tạo Account) |
| Push | `PUSH_PROVIDER`, `FCM_*` | Khi không `mock` | `fcm` + project/email/private key → FCM HTTP v1; thiếu key → unavailable; prod từ chối `mock` |
| Payment | `PAYMENT_PROVIDER`, `VNPAY_*` / `MOMO_*` | Online pay | `sandbox` mặc định (COD); `vnpay`/`momo` tạo redirect intent (`PENDING_REDIRECT`); webhook stub verify chữ ký; **không** claim capture thật |
| Voice | `VOICE_PROVIDER`, `LIVEKIT_*` | Chat thoại (1A / DEC-PROD-007) | `mock` non-prod; `livekit` ký JWT audio-only; prod từ chối `mock` |
| Contact window TEST_ONLY | `CONTACT_WINDOW_MINUTES` | Chat + voice | Default 120; heuristic `status`+`updatedAt` — **không** phải `OPEN-021` |
| KYC storage | `KYC_STORAGE_PROVIDER`, `S3_*` | Upload giấy tờ | URL có hạn, không public vĩnh viễn |
| Ride TEST_ONLY | `RIDE_*` | Dev/test | Không phải chính sách `OPEN-003` đã duyệt |
| Food TEST_ONLY | `FOOD_MIN/MAX_DELIVERY_VND` | Dev/test | Bounds sandbox |
| Ops bootstrap | `OPS_BOOTSTRAP_EMAIL`, `OPS_BOOTSTRAP_PASSWORD` | Local admin | Production từ chối password mặc định |

## Admin Web (`website/.env.local`)

Sao chép từ `website/.env.example`.

| Biến | Vai trò |
|---|---|
| `DEALGO_API_BASE_URL` | Nest origin (vd `http://localhost:3001`) |
| `NEXT_PUBLIC_API_BASE_URL` | Optional, **đọc lúc build**: origin được thêm vào CSP `connect-src`. Trình duyệt vẫn gọi BFF cùng origin; không đặt token/secret ở `NEXT_PUBLIC_*` |
| `ADMIN_UI_MOCK` | `1` = duyệt UI bằng session mock, không cần Nest |
| Cookie ops | Set bởi BFF `/api/ops/session` — không lưu token dài hạn trong `localStorage` |

CI website không còn đặt `NEXT_PUBLIC_NEST_API_URL` (code không đọc biến này).

## Flutter

| Cơ chế | Vai trò |
|---|---|
| `--dart-define=USE_MOCK_DATA=true` | Composition root inject Fake* clients + seed |
| `--dart-define=API_BASE_URL=...` | Nest origin khi tắt mock |
| Secure storage | Access/refresh token — không SharedPreferences |

Không nhúng API signing key, FCM private key, hay payment secret trong binary app.

## Thứ tự điền key khi lên staging

1. `DATABASE_URL`, `REDIS_URL`, `JWT_ACCESS_SECRET`
2. `SMS_PROVIDER` + vendor keys (bỏ `mock`)
3. `EMAIL_PROVIDER` + `SMTP_URL`
4. `MAPS_PROVIDER` + key bản đồ
5. `PUSH_PROVIDER` + FCM
6. `PAYMENT_PROVIDER` sandbox → vendor khi có phê duyệt `OPEN-002`
7. `KYC_STORAGE_PROVIDER` + S3
8. `VOICE_PROVIDER` + LiveKit khi mở chat thoại

## Kiểm tra trước production

- [ ] Không còn `SMS_PROVIDER=mock` / `PUSH_PROVIDER=mock` / `VOICE_PROVIDER=mock`
- [ ] JWT secret không phải giá trị mẫu
- [ ] `OPS_BOOTSTRAP_PASSWORD` không phải `change-me-dev-only`
- [ ] `USE_MOCK_DATA` / `ADMIN_UI_MOCK` tắt
- [ ] Secret nằm ở vault/CI secrets, không trong git
- [ ] FCM / LiveKit / VNPAY / MoMo keys chỉ khi bật provider tương ứng (2A)
