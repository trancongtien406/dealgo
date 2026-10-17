---
doc_id: DG-AI-005
title: "DealGo — Flutter gap matrix vs dealgo-flutter.mdc"
version: "0.6.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-14"
---

# Flutter gap matrix

> Widget/`analyze` xanh **không** bằng architecture Done. Done = một Dio, ApiPaths, không fake trong presentation, UI → Cubit → client, refresh story trung thực, realtime reconcile bằng REST.

## Verdict

Architecture remediation + WO2 + **WO3 (P0 missing screens)**:

- **Auth phone/OTP pages no longer call `IdentityClient`.** `PhoneAuthCubit` owns challenge/verify/resend/mock; login `ShellRoute` provides the Cubit.
- **One shared Dio** from `createDealGoDio` via DI only.
- **`lib/core/design_system/`** holds tokens + shared primitives: buttons, card, illustration, **`DealGoChip`**, **`DealGoSegmentedControl`**, **`DealGoBanner`**, **`DealGoTabBar`** (merchant/driver). Customer elevated center stays in `CustomerTabBar`.
- Feature chips (`DriverChip` / `MerchantChip` / `RideStatusChip` / `OnboardingStatusChip`) are **thin wrappers** over `DealGoChip`. Material `FilterChip`/`ChoiceChip` removed from driver earnings, driver notifications, merchant KYB; activity/inbox/place filters use `DealGoSegmentedControl`.
- **l10n:** `app_vi.arb` / `app_en.arb` expanded (shell tabs, auth/OTP, role picker, filters, statuses, empty/offline, chat/voice + WO3 P0 screen strings). High-traffic surfaces wired to `AppLocalizations`. Many domain/marketing strings elsewhere still hardcoded VN.
- **Folder hygiene:** `customer_home_widgets.dart` barrel → `home_hero.dart` / `home_services.dart` / `home_sections.dart` (+ `home_shared.dart`). Feature layout already matches `core/` + `features/*/presentation|data|domain`.
- **WO3 P0 screens shipped (mock/fixture OK):** C008 offer detail, C012 pickup code, C014 safety, C016/C035 cancel reason pickers, D031 failed delivery, D034 completed job, M022–M024 shop settings, M028 variants shell. Routes in `app_router` + `*_routes.dart`; CTAs wired from offers/tracking/jobs/products.
- Platform shells (FCM / LiveKit / Maps): unchanged — soft-fail / stub only.
- Motion scaffold started; M2+ still open.
- **No claim of production FCM / LiveKit / Maps SDK** — key-fill and `flutterfire configure` still open (ADR-006).

### God-page extraction progress (LOC ≈ `wc -l`, 2026-10-14)

| Page / widgets | Before | After | Status |
|---|---:|---:|---|
| `otp_page.dart` | ~1055 | ~226 + `otp_widgets.dart` | Extracted |
| `customer_home_page.dart` | ~1283 | ~90 | Extracted |
| `customer_home_widgets.dart` | ~1199 | barrel + 3 files (~350 / ~295 / ~500) | Split (WO2) |
| `ride_offers_page.dart` | ~1076 | ~424 + widgets | Extracted |
| `food_checkout_page.dart` | ~902 | ~221 + widgets | Extracted |

**Still large pages (not this pass):** `driver_home_page`, `ride_matching_page`, `ride_map_page`, `food_discovery_page`, `food_store_page`, `merchant_order_page`, `place_search_page`, `role_picker_page`. Remaining VN hardcodes outside high-traffic surfaces.

## Phase 4 — FCM + LiveKit + Map ports (1A+2A) — DONE (ports / stubs)

- [x] `PushPort` + `FakePush` / `FcmPush`; soft-fail when Firebase absent
- [x] `VoiceClient` → voice-session; Cubit + sheet (LiveKit SDK later)
- [x] Voice button next to chat on ride/food tracking
- [x] `MapPort` + placeholder; soft-fail without `MAPS_API_KEY`
- [x] `DriverDutyCubit` posts presence on online/offline
- [x] Customer activity history list endpoints when present
- [x] Firebase options placeholder + safe bootstrap
- [x] Notification / deeplink / analytics shells in `core/`
- [x] Motion scaffold + proof on role picker → customer shell

## Phase 2 — DONE

- [x] Driver/Merchant feature data layers + role-scoped Cubits
- [x] `flutter_localizations` + ARB `vi` / `en` (expanded in WO2)
- [x] Snapshot realtime + reconnect → REST in tracking Cubits
- [x] Partner applications client; KYC/KYB when `!useMockData`
- [x] Chat ApiPaths + client + DI + tracking sheet

## Phase 3b — merchant catalog write — DONE

- [x] Merchant catalog GET + item create/update/availability write surface

## WO2 — design system + l10n + hygiene — DONE (this pass)

- [x] `DealGoChip` (tones: neutral/brand/success/warning/danger/promo)
- [x] `DealGoSegmentedControl` (replaces Material filter/choice chip groups)
- [x] `DealGoBanner` (info/warning/offline/empty)
- [x] `DealGoTabBar` for merchant/driver; `CustomerTabBar` kept (elevated Đặt)
- [x] Feature chip wrappers → shared `DealGoChip`
- [x] ARB vi/en expanded; high-traffic strings localized
- [x] `customer_home_widgets` split into hero/services/sections
- [x] WO3 P0 screens: C008, C012, C014, C016, C035, D031, D034, M022–M024, M028
- [ ] Remaining P0 partials (D023 OTP enter, C036 invoice, driver lifecycle fidelity, M027 editor, KYC/KYB depth, maps)
- [ ] Remaining hardcoded VN on low-traffic / domain marketing copy

## Vi phạm / gaps còn lại

| Mức | Vấn đề |
|---|---|
| Med | Real Google Maps / Mapbox SDK not linked (placeholder until key-fill) |
| Med | Production Firebase / `flutterfire configure` / APNs not done — FCM shell only |
| Med | LiveKit room join SDK not linked (token + room name stub) |
| Med | Remaining P0 PARTIAL/MISSING: D023, C036, D021–D030 fidelity, M017/M019, M027, KYC/KYB steps, D036/M021 soft |
| Med | God-page debt reduced further (home widgets split); other pages still ≥500 LOC; residual VN hardcodes |
| Med | OS app_links / universal links not registered (parser + hook shell only) |
| Med | Motion applied to few routes; most screens still default Material transitions |
| Med | Tab icons still Material (temporary; brand assets not wired to tabs) |
| Done | MapPort + soft-fail placeholder |
| Done | PushPort + FcmPush soft-fail + token register path |
| Done | VoiceClient + tracking voice CTA |
| Done | Driver presence on duty toggle |
| Done | Customer ride/food history list client |
| Done | Merchant owner catalog write surface |
| Done | Transaction chat sheet on ride/food tracking |
| Done | design_system under `core/` + chip/segment/banner/tab primitives |
| Done | Dio clients require injected shared Dio |
| Done | Shared Dio + ApiPaths + single-flight refresh |
| Done | Fixtures khỏi presentation |
| Done | Page network → Cubit |
| Done | Driver/Merchant feature data layers |
| Done | Role-scoped feed/queue Cubits |
| Done | l10n bootstrap + high-traffic auth/shell/OTP/role/filters |
| Done | Snapshot realtime in tracking Cubits + reconnect → GET |
| Done | Partner application API wiring |
| Done | Chat ApiPaths + thin client + DI |
| Med | Socket client is single-process; Redis adapter / multi-instance not on mobile |
| Low | Pixel redesign / design fidelity across full screen inventory |

## Phase 1 — infrastructure + boundary — DONE

- [x] `core/network/`: shared Dio, ApiPaths, ApiException, envelope
- [x] Một Dio inject vào Dio*Client; refresh single-flight
- [x] Fixtures khỏi presentation
- [x] Cubits + route/page BlocProvider coverage for core flows
- [x] `app/di.dart`

## Không làm (out of scope this phase)

- Pixel rewrite / redesign of all screens
- Deferred P1/P2 screens (ratings, wallet, scheduled, promo, supermarket)
- Remaining P0 PARTIAL fidelity (driver OTP enter, kitchen board, map SDK)
- UseCase tree rỗng
- Invent Nest APIs
- Mock fallback trong release
- Claim “đã tích hợp production” FCM / LiveKit / Maps SDK
- Run `flutterfire configure` or ship real Firebase project IDs
