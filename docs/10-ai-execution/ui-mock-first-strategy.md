---
doc_id: DG-AI-002
title: "DealGo — UI mock-first trước khi tích hợp API"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-14"
related_decisions:
  - DEC-PROD-001
  - DEC-PROD-002
  - ADR-004
  - ADR-005
  - ADR-006
---

# UI mock-first

## Mục tiêu

Hoàn thiện giao diện Flutter và Admin Web theo PNG trong `design/mockups/screens/` bằng **fixture/mock cùng contract API**, trước khi nối backend thật. Backend vẫn phát triển song song; client không phụ thuộc Nest để demo UI.

## Quy tắc

1. Mock/fixture dùng cùng model, enum trạng thái và lỗi như client Dio/BFF sẽ gọi sau này.
2. Bật mock bằng cờ môi trường (`USE_MOCK_DATA`, `ADMIN_UI_MOCK`). Production/release build từ chối bật mock.
3. Visual bám PNG Golden: `C001`, `C004`, `C028`, `S007`, `M013`, `D016`, `A003`.
4. Không tuyên bố “đã tích hợp production” khi còn chạy mock.
5. Khi backend phase tương ứng sẵn sàng: chỉ đổi composition root / data source; không viết lại page.

## Thứ tự phase UI

| Phase | Phạm vi | Owner |
|---|---|---|
| UI-A | Mock composition + Golden shell + thay placeholder P0 | Flutter, Frontend |
| UI-B | Ride negotiation + Food core + Merchant queue + Driver feed theo design | Flutter |
| UI-C | Admin ops queues (KYC/KYB, refunds, disputes) + shell token | Frontend |
| UI-D | Onboarding KYC/KYB mobile + states (empty/error/offline) | Flutter |
| INT-A | Đổi mock → Dio/BFF theo contract đã ổn định | Flutter, Frontend, Backend |

## Gate thoát UI-A

- App chạy offline với seed mock: Customer home, Ride entry, Food discovery, Merchant home, Driver home.
- Admin duyệt được toàn bộ trang mock không cần Nest.
- Placeholder “Giai đoạn 1 chưa có…” không còn trên tab P0.

### UI-A Mobile (2026-10-14) — DONE (verified)

- `flutter run --dart-define=USE_MOCK_DATA=true` + nút **Vào demo (mock)** / OTP bất kỳ.
- P0 tabs: trips, merchant products/stats, driver earnings/notifications có UI mock.
- C001 assets batch02; C026 options sheet.
- `flutter analyze` clean; targeted tests PASS. Chưa chạy trên device thật.

### UI-B Mobile (2026-10-14) — DONE (verified)

- Ride C004 vehicle → fare; C007/C011/C017 polish; Food C032 + cancel stub; Driver notifications; Merchant kitchen/handoff.
- `flutter analyze` + targeted tests PASS. Còn: Map SDK, full screen set, server handoff.

### UI-D Mobile (2026-10-14) — DONE (verified, mock-only)

- `/driver/kyc/*`, `/merchant/kyb/*` multi-step; account/role-picker entry; draft→pending→rejected.
- Analyze + `onboarding_kyc_test` PASS. Chưa: upload/S3, full D/M step set, ops API.

### UI-A Admin Web (2026-10-14) — DONE (verified)

- `ADMIN_UI_MOCK=1` + **Đăng nhập demo** (không cần Nest).
- Shell 238×64; routes A002/A019/A022/A023/A025–A028 + fixtures.
- `tsc --noEmit` + `npm run lint` PASS.
- Còn: UI-C visual polish vs A003+, interactive filters, A013/A014 out of MVP.

### UI-C Admin Web (2026-10-14) — DONE (verified)

- Overview/monitor/rides/food/KYC/disputes polish + skeleton/empty + client filters.
- `tsc` + lint PASS. Còn nợ: map crop thật, chart multi-series, deep-link mọi row.
