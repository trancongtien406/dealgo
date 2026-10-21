---
doc_id: DG-AI-003
title: "DealGo — Backend gap matrix (honest)"
version: "0.1.10"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-18"
related_decisions:
  - ADR-001
  - ADR-002
  - ADR-003
  - ADR-006
  - DEC-PROD-007
---

# Backend gap matrix

> **Không dùng “test xanh” làm Definition of Done.** Done = đúng nghiệp vụ docs + rules `dealgo-nestjs` + contract + persistence thật + nhánh lỗi/concurrency khi áp dụng.

## Verdict

Backend là **modular vertical slice** (~**90%+** Phase 1–8 **foundation**). Có identity + ride negotiate→trip complete + food place→deliver, fail-closed persistence, OpenAPI skeleton, requestId, merchant catalog, sandbox COD ledger + PaymentIntent, ops explorer, KYC/KYB mock, dispatch radius (TEST_ONLY), OTP throttling, health live/ready, outbox + Socket.IO, **FCM HTTP v1 adapter when keys set** (else unavailable; prod refuses mock), **MapsPort**, **VoicePort mock/livekit** (DEC-PROD-007 **1A** kept), **TEST_ONLY `CONTACT_WINDOW_MINUTES`** on chat+voice (not OPEN-021), **VNPAY/MoMo create-redirect + webhook stubs** (**2A** full adapters with env keys; no capture claim without webhook), ride-expiry worker, CI unit + Postgres/Redis integration.

**Chưa** Done (vẫn OPEN policy / product): fee/commission production (`OPEN-003`…), real settlement/payout, contact retention policy (`OPEN-021`), full P0 concurrency matrix, production Firebase/Maps/LiveKit key-fill. **Phase H+I Nest landed:** FCM HTTP v1 + `PushDeviceToken` / `POST /v1/me/push-tokens`, voice-session, PSP redirect stubs, ops cancel/reassign, customer history, driver presence, FoodStore lat/lng. **Admin intervene UI landed** (detail cancel/reassign); customers/drivers/stores boards still fixture.

Owner decisions noted: **1A** keep DEC-PROD-007 chat+voice; **2A** adapters with env keys; fee/window numbers = TEST_ONLY labeled, **not** approved OPEN-* policy.

## Phase status

| Phase | Status | Ghi chú |
|---|---|---|
| 0 Docs/ADR/secrets | PARTIAL | ADR còn `PROPOSED` |
| 1 Health/config/DB/Redis | PARTIAL | `/health/live` + `/health/ready`; Redis ping + Socket.IO adapter + OTP Redis throttler |
| 2 Auth + roles | PARTIAL | OTP/passkey mock; email+password (OTP đăng ký + reset qua `MailSender`); KYC/KYB mock + ops review; sandbox auto-ACTIVE + eligibility bypass ngoài production; grant `SUSPENDED` chỉ ops mở lại |
| 3 Ride | PARTIAL | Lifecycle tới `COMPLETED` + COD journal; customer history; driver presence filters open list; MapsPort; expiry worker; chưa fee policy |
| 4 Food | PARTIAL | Lifecycle tới `DELIVERED`/`FAILED`; store lat/lng + ready radius prefers store; customer order history; claim gated; outbox |
| 5 Ledger/COD | PARTIAL | Double-entry sandbox + PaymentIntent; VNPAY/MoMo **redirect create only** + webhook stub; **ops settlements** heuristic; **không** real payout |
| 6 Ops admin APIs | PARTIAL | Login + grant/KYC + ride/food + exceptions + settlements + **CAP-OPS-05 cancel/reassign** + **auth-methods** flags; Admin detail intervene DONE; **ops customers/drivers/staff APIs exist** (`/v1/ops/customers`, drivers, staff) |
| 7 Realtime/push/chat/voice | PARTIAL | Socket.IO + Redis; outbox→snapshot; **FCM HTTP v1 when keys** + device-token registry; chat + **voice-session**; TEST_ONLY contact window; Flutter FCM/`flutterfire configure` still key-fill |
| 8 CI + P0 matrix | PARTIAL | Unit + integration; chưa full P0 matrix / runbook |

## Backlog ưu tiên (backend)

### A — Foundation (largely landed)

1–8. OpenAPI skeleton, fail-closed persistence, ride/food lifecycle, merchant catalog, dispatch filter, OTP throttle, requestId/readiness — **done as foundation**

### B — Pilot / tiền sandbox

9–13. Ledger/KYC/ops/outbox/expiry — **partial**; idempotency races still thin beyond ride select

### C — Adapter ports (Phase H / 2A)

14. Maps/Push/Payment/Voice — **Maps done**; **FCM HTTP v1 done** + `PushDeviceToken` / `POST /v1/me/push-tokens` (empty tokens → no-op send); **Voice mock/livekit done**; **VNPAY/MoMo createRedirectIntent + webhook stubs done**; sandbox still default
15. Socket snapshot — done
16. Chat + voice (1A) — text chat + voice-session REST; TEST_ONLY window; retention/`OPEN-021` still open

## Remaining gaps (honest)

| Gap | Why not Done |
|---|---|
| Production FCM fan-out | Registry + adapter landed; needs real Firebase keys + client `flutterfire configure` |
| `OPEN-003` fee / commission | TEST_ONLY env bounds only; no invented settlement math |
| Real PSP capture / reconcile | Redirect + CAPTURED_STUB webhook only; not ledger settlement |
| Real settlement / payout | Ops day-bucket heuristic |
| Contact retention `OPEN-021` | `CONTACT_WINDOW_MINUTES` is TEST_ONLY heuristic on status+updatedAt |
| Food store geocoords | Optional lat/lng + merchant PATCH; ready list uses store when set; delivery fare still TEST_ONLY (no invented fee %) |
| Full P0 concurrency matrix | Ride select + **food claim** race specs (`test/concurrency/*.race.spec.ts`); capacity gate still TEST_ONLY (`OPEN-005`) |
| Ops customers/users list | **Landed:** `GET /v1/ops/customers` (+ drivers/staff); Admin board may still use fixtures until wired |
| Promotion redemption | `POST /v1/promotions/validate` chỉ báo giá; chưa ghi redemption/trừ ngân sách, `userLimit` chưa thực thi |
| Food claim race vs Postgres | `food-claim.race.spec.ts` đỏ khi chạy với Postgres (merchant catalog 404 trước bước claim) — có từ trước 2026-10-18 |
| Ops RBAC chi tiết | `OpsSessionGuard` chỉ kiểm grant `OPS`; staff role/scope chưa thực thi |
| SMS production | Chỉ `mock`/unavailable; chưa adapter ESMS/Twilio |
| Migration timestamp collision | Historical `20261014160000_*` triple prefix remains; new indexes use `20261015173000_hot_path_indexes` |

## Fixes landed (2026-10-15)

| Item | Notes |
|---|---|
| S3 KYC storage | `KYC_STORAGE_PROVIDER=s3` + S3_* env; SigV4 PUT; aliases `S3_BUCKET_NAME` / `S3_API_ENDPOINT` |
| Food claim concurrency | Conditional `READY AND assignedDriverId IS NULL` + `test/concurrency/food-claim.race.spec.ts` |
| `MAX_CONCURRENT_JOBS_PER_DRIVER` | Enforced on food claim + ride select (ride+food active statuses); TEST_ONLY / OPEN-005 |
| Hot-path indexes | `rides(status,createdAt)`, `food_orders(status,createdAt)`, `food_stores(lat,lng)` |
| Ride expiry spam | Outbox duplicate used `create`+catch P2002 which **aborts PG TX**; switched to `createMany({ skipDuplicates })` |
| SMTP discrete env | `SMTP_HOST/PORT/USER/PASSWORD` → `SMTP_URL`; `EMAIL_PROVIDER=smtp` uses SmtpMailSender |

## Fixes landed (2026-10-18)

| Item | Notes |
|---|---|
| Promotions persistence | Bảng `promotions` (migration `20261018202000_promotions`), repository Prisma/Memory; dữ liệu mẫu chỉ trong `prisma/seed.ts` và unit test |
| Promotion validate auth | `POST /v1/promotions/validate` yêu cầu customer session; `customerId` lấy từ session (field body cũ bị bỏ qua) |
| Email register | Hai bước OTP: `email_signup_challenges` (migration `20261018220000_email_signup_challenges`); Account/grant/session chỉ tạo sau `…/register/:id/verify`; login email chưa verify → 403 + OTP kích hoạt (`20261018230000_email_challenge_activation`, `DEC-PROD-008`) |
| Password reset | `POST /v1/auth/email/password-resets` (202, không lộ email tồn tại) + `/:id/confirm`; bảng `password_resets`; revoke customer sessions |
| Phone OTP sign-up | Không tạo user trước verify (`phone_challenges.userId` nullable); cấp `CUSTOMER` `ACTIVE` ở mọi môi trường khi verify lần đầu |
| Suspended grant | `POST /v1/me/role-grants` trả 403 `ROLE_GRANT_SUSPENDED`, không tự mở lại |
| Avatar body limit | JSON 3mb chỉ cho `POST /v1/me/avatar`; route khác giữ 100kb; lỗi body-parser trả 413/400 thay vì 500 |
| Prisma pool | `DATABASE_POOL_MAX` (mặc định 10/process) |
| Worker boot | Standalone worker import `ThrottlerModule` để DI `ThrottlerGuard` không lỗi |
| CI | Backend thêm `npm run typecheck` (gồm test/prisma/scripts) + `npm run lint`; Node từ `.nvmrc` |

## Definition of Done (áp dụng lại)

- Schema/migration phản ánh invariant
- Service ownership + object-level authz
- Không tin role/price từ client
- Test concurrency cho race P0
- Không mock âm thầm ở production
- Contract OpenAPI khớp code

## Phase H policy notes (1A / 2A)

- **1A:** DEC-PROD-007 chat + in-app voice kept; audio-only metadata; no phone numbers in payloads.
- **2A:** Provider adapters activate when env keys present; otherwise unavailable (fail-closed). Production refuses `PUSH_PROVIDER=mock` and `VOICE_PROVIDER=mock`.
- **Contact window:** `CONTACT_WINDOW_MINUTES` (default 120) — TEST_ONLY; **not** approved OPEN-021.
- **Payment:** `PAYMENT_PROVIDER=sandbox` default; `vnpay`/`momo` persist `PENDING_REDIRECT` + `paymentUrl`/`providerRef`; webhooks verify signature when secrets set and mark `CAPTURED_STUB` / `SANDBOX_RECORDED` idempotently — **no claim of real capture**.
- **Push:** FCM without keys → unavailable; with keys → HTTP v1 (OAuth JWT via Node crypto, no google-auth dep).
- **Voice:** `POST /v1/rides/:id/voice-session` and `POST /v1/food/orders/:id/voice-session`; authz = chat `canSubscribe` + contact window.
