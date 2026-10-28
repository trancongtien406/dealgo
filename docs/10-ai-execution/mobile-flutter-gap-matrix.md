---
doc_id: DG-AI-005
title: "DealGo — Flutter gap matrix"
version: "1.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-26"
---

# Flutter gap matrix

> Green widget tests / `flutter analyze` are not Done. Done = one shared Dio, `ApiPaths`, no fake data in presentation, UI → Cubit → client, honest refresh, realtime reconciled with REST.

Current state of `mobile/` (one app with Customer, Driver and Merchant shells). Code is the source of truth.

## Architecture

- `core/network/`: one shared Dio (`createDealGoDio`) injected via `app/di.dart`; `ApiPaths`; envelope + `ApiException`; single-flight token refresh. Release builds refuse `http://` base URLs (`assertSecureApiBaseUrl`).
- Features follow `features/*/{data,domain,presentation}`; pages talk to Cubits only. Mock data lives in `core/mock/` and is used only when `useMockData` is on.
- `core/design_system/`: tokens and shared primitives (`DealGoChip`, `DealGoSegmentedControl`, `DealGoBanner`, `DealGoTabBar`, buttons, cards).
- l10n: `app_vi.arb` / `app_en.arb` via `AppLocalizations`.

## Feature status

| Area | In code | Gaps |
|---|---|---|
| Auth | Phone OTP, passkey, email + password (sign-up OTP, reset); role picker; partner onboarding (driver KYC, merchant KYB) | — |
| Customer Ride | Fare suggestion, own offer, live driver offers over Socket.IO (no polling), choose driver, pickup code (driver enters it to start), tracking, cancel with reason, share trip, safety page | — |
| Customer Food | Discovery, store, single-store cart, checkout with voucher, order tracking, order-change card (accept new total or cancel free) | — |
| Driver | Duty toggle with presence; GPS policy 15 s / 50 m / 60 s; ride bargaining (offer / counter, socket-only outcome); active ride; food pickup and delivery, failed delivery; earnings history with the platform fee per job and per week | The open-jobs list refreshes only on open, duty change or retry; it does not listen to the server's new-request socket event (drivers learn of new requests via push) |
| Merchant | Orders queue and detail, order-change sheet, catalog CRUD with photos and variants, shop settings | — |
| Chat / voice | Transaction chat on ride and food tracking. In-app voice calls customer ↔ assigned driver (`features/voice`, `livekit_client`): call button on ride/food tracking and the driver contact actions (shown only when `GET /v1/calls/config` says enabled); full-screen call overlay over every route with accept / decline, mute, speaker, timer; incoming via the Socket.IO `call` event or the `Call.incoming` push; a bundled ring loops with vibration while ringing (`AssetCallRinger`, `audioplayers`); native call UI through `flutter_callkit_incoming`: CallKit on iOS (PushKit VoIP push wakes a killed app once the APNs key is set; the PushKit token is uploaded again whenever iOS rotates it) and a self-managed ConnectionService full-screen incoming call on Android (shown from the FCM background handler); answer / decline / hang-up on the native UI drive the same call cubit; mic permission asked on first call, Android 12+ also asks `BLUETOOTH_CONNECT` for headset audio; iOS `audio` + `voip` background modes | CallKit/PushKit cannot be tested on the iOS Simulator and is untested on a device. The APNs key is set in dev, and token auth is accepted on both the sandbox and production hosts (a dummy token returns `BadDeviceToken`). Without the key, iOS falls back to the FCM alert. With VoIP on, iOS rings once (the FCM copy skips iOS). Android gets a data-only call push, so only the native UI shows, and Android 14+ asks once for the full-screen call permission. The R8 release APK and AAB build with the keep rules (debug-signed locally; the release keystore `android/key.properties` does not exist yet). Real-device tests are pending: no iPhone is connected |
| Push | `firebase_messaging` with `GoogleService-Info.plist` / `google-services.json`; token register / unregister on sign-out; tap opens `data.path` checked against the user's roles, else the inbox | Real-device test of each push type pending |
| Maps | `flutter_map` raster tiles (Mapbox or `MAP_TILE_URL`), placeholder when no key; route line from `/v1/rides/route`; saved map style (standard / satellite / dark) on Mapbox; shared pick-on-map screen with cached reverse geocoding | No vector map SDK (no 3D buildings / offline packs) |
| Deep links | `dealgo://` and `https://<app-link-host>/app/*` registered in the Android manifest and iOS entitlements; parsed by `DeepLinkRouterHook` | — |

## Code-health debt

| Level | Item |
|---|---|
| Med | Large files over 900 lines: `dio_food_remote_datasource.dart`, `driver_kyc_pages.dart`, `merchant_kyb_pages.dart`, `app/di.dart`, `app_router.dart`, `food_checkout_widgets.dart` |
| Low | Some low-traffic strings are still hard-coded Vietnamese instead of ARB |

## Out of scope

- Inventing backend APIs or mock fallback in release builds.
- Shipping real Firebase project IDs or secrets in the repo docs.
