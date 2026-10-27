---
doc_id: ADR-006
title: "Cổng tích hợp ngoài và catalog secret"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - OPEN-002
  - OPEN-008
  - OPEN-020
  - OPEN-021
  - DEC-PROD-006
  - DEC-PROD-007
---

# ADR-006 — Cổng tích hợp ngoài

## Status

`PROPOSED`. Không chọn nhà cung cấp nào thành hợp đồng thương mại. Mỗi cổng có adapter `mock` chạy không cần key, và adapter thật chỉ bật khi đủ biến môi trường.

**Hiện trạng trong code:** adapter mock/thật trong `backend/src/integrations/*`. Quyết định chờ chủ dự án chuyển sang `ACCEPTED` hoặc thay thế.

## Context

`OPEN-008` chưa chốt vendor. Sản phẩm vẫn cần passkey, SMS, email, bản đồ, push, thanh toán và thoại. Chủ dự án yêu cầu thiết kế để sau này chỉ điền key.

## Decision

Mỗi năng lực là một port trong backend. Biến `*_PROVIDER` chọn implementation.

| Năng lực | Provider code | Khi nào dùng | Biến bắt buộc khi không phải mock |
|---|---|---|---|
| Bản đồ / geocode (Places) | `mock`, `mapbox`, `goong`, `google` (`maps.module.ts:22-41`) | **`mapbox` là provider đang dùng** (`.env.example` `MAPS_PROVIDER=mapbox`); goong/google là phương án thay; `PlacesService.reverse` cache theo ô ~11 m (4 chữ số thập phân), 1000 ô, TTL 1 giờ, không cache khi provider unavailable. Tìm kiếm: thêm ứng viên OSM qua Photon (tuỳ chọn, `PLACES_OSM_SEARCH_URL`; trống → chỉ Mapbox; production dùng Photon tự host bản trích Việt Nam), xếp hạng lại ở server — xem `places-search.md` | `MAPBOX_ACCESS_TOKEN` / `GOONG_API_KEY` / `GOOGLE_MAPS_API_KEY` / `PLACES_OSM_SEARCH_URL` (tuỳ chọn) |
| Routing (polyline/ETA) | `none`, `mapbox`, `osrm` (`routing.service.ts:39-59`) | `mapbox` preferred; `osrm` chỉ self-hosted — OSRM public demo = DEV only | `MAPBOX_DIRECTIONS_TOKEN` (server-only) / `ROUTING_OSRM_URL` |
| SMS OTP | `mock`, `esms`, `speedsms`, `none` | eSMS chính, SpeedSMS phụ. Mock in mã ra log dev đã redact một phần, không gửi mạng | `ESMS_*` hoặc `SPEEDSMS_*` |
| Email | `mock`, `smtp` | Xác minh email và thư vận hành | `SMTP_URL` |
| Passkey | `local` | `@simplewebauthn` trên server; không cần key hãng | `WEBAUTHN_RP_ID`, `WEBAUTHN_ORIGIN` |
| Đẩy thông báo | `mock`, `fcm` | FCM cho Android/iOS | `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` |
| Thanh toán online | `sandbox`, `vnpay`, `momo` | Sandbox không thu tiền thật | `VNPAY_*` hoặc `MOMO_*` |
| COD | `ledger` | Ghi nghĩa vụ trong sổ, không gọi cổng | Không key |
| Thoại trong app | `none`, `mock`, `livekit` (`voice.module.ts` `createVoicePort`) | LiveKit SFU: server ký token chỉ audio cho đúng phòng của chuyến/đơn; app dùng `livekit_client`. Không ghi âm, không video. `none`/không đặt → `VOICE_UNAVAILABLE`. Production tự host: `deploy/livekit` (`docs/09-operations/livekit-self-host.md`) | `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET` |
| Hồ sơ KYC | `mock`, `s3` | Ảnh giấy tờ qua URL có hạn, không public vĩnh viễn | `S3_*` |

OTP trong mock chỉ tồn tại ở môi trường `development` và `test`. Production từ chối boot nếu `SMS_PROVIDER=mock` hoặc JWT secret còn giá trị dev.

## Consequences

- File mẫu: `backend/.env.example`, `website/.env.example`, `mobile/env/dev.json.example`. Không commit `.env`.
- Phí, timeout thương lượng, vùng phục vụ đọc từ cấu hình có phiên bản. Giá trị dev ghi nhãn `TEST_ONLY` và không phải chính sách `OPEN-003` / `OPEN-019` đã duyệt.
