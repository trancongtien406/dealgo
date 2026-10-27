# Compliance checks (Guidelines snapshot: App Review Guidelines as of 2026, re-read before submitting)

## 1. Sign in with Apple (Guideline 4.8) — NOT REQUIRED (VERIFIED)
4.8 applies only when the app uses a third-party or social login (Google, Facebook, …) for the primary account.
DealGo's login methods are **phone + OTP**, **email + password (with reset)** and **passkeys** (`identity/presentation/pages/*`, `passkeys` package). There is no google_sign_in, facebook or other social SDK in `pubspec.yaml`.
→ SIWA is not needed. If social login is added later, SIWA (or an equivalent privacy-preserving option) becomes mandatory.

## 2. Account deletion (5.1.1(v)) — PASS (VERIFIED)
- Entry points: **Tài khoản → Xoá tài khoản** (`shell/presentation/account_page.dart`) and **Bảo mật → Xoá tài khoản** (`security_page.dart`). Both are available in every role shell.
- Flow: `DeleteAccountPage` → `POST /v1/me/account-deletion` → confirm `/v1/me/account-deletion/:id/confirm` (DEC-PROD-037).
- Note for review: if deletion is delayed for obligations still open (an active trip/order, partner settlement), the UI must say so. ASSUMED that the current copy does; re-check the text on the page.

## 3. Location permission strings and background modes (5.1.1, 2.5.4) — PASS (VERIFIED)
- `NSLocationWhenInUseUsageDescription` (vi): "DealGo cần vị trí của bạn để đặt xe, giao đồ ăn và hiển thị tài xế gần bạn." The purpose is specific.
- Info.plist declares neither `UIBackgroundModes: location` nor `NSLocationAlwaysAndWhenInUseUsageDescription`, because the app never tracks location in background (`LocationService`: "Background tracking is out of scope"; nothing sets `allowBackgroundLocationUpdates`). Declaring an unused background mode is a common 2.5.4 rejection reason.
- `UIBackgroundModes` contains `remote-notification` (push) and `audio`. `audio` keeps an in-app call (LiveKit/WebRTC) talking when the user locks the phone or switches app mid-call; it is active only while a call is connected, never for playback or tracking. Say this in the review notes. The guard test `test/app/ios_background_location_guard_test.dart` fails if the location mode or the Always string is added without real background tracking.
- If driver background tracking is built later: add both entries back, use `AppleSettings(allowBackgroundLocationUpdates: true, showBackgroundLocationIndicator: true)` only during active jobs, and explain it in the review notes.
- Other strings (VERIFIED present and purpose-specific): Camera (KYC), Photo Library and Add (KYC, receipts), Microphone (in-app calls customer ↔ assigned driver; asked the first time the user places or answers a call; audio is never recorded).
- Info.plist strings are Vietnamese only. Add `en.lproj/InfoPlist.strings` for the English locale (open item; ASSUMED low risk).

## 4. Push
- `aps-environment` is `development` in `Runner.entitlements`. It must be **production** for App Store builds. Xcode sets this automatically with a Distribution profile. See `docs/09-operations/push/`.

## 5. Other
- 3.1: physical services paid in cash, so no IAP (3.1.3(e)/3.1.5(a)).
- 1.5 / 5.1.1(i): `/support` and `/privacy` routes exist on the website. The production URLs must be live before submission.
- Partner KYC collects CCCD data. The privacy policy must disclose this (see app-privacy.md).

## Export compliance (App Encryption Documentation)

Status: VERIFIED in code (2026-10-26).

- What the app encrypts: HTTPS/TLS for REST (dio) and Socket.IO (WSS); FCM/APNs over platform TLS; tokens stored in iOS Keychain via flutter_secure_storage. No custom or proprietary cryptography; no `crypto`/`encrypt`/`pointycastle`/`cryptography` packages in `mobile/lib`.
- This is exempt encryption (standard protocols / OS-provided), so **no encryption documentation upload and no CCATS/ERN is needed**.
- `mobile/ios/Runner/Info.plist`: `ITSAppUsesNonExemptEncryption = NO`, so App Store Connect stops asking the export-compliance question on every build.
- App Store Connect, if asked: "Does your app use encryption?" → Yes, only exempt (standard HTTPS / OS encryption) → no documentation.
- Chat (2026-10-26, owner t46u): message bodies are encrypted **server-side** (AES-256-GCM in the NestJS backend, Node crypto). Nothing was added to the iOS app, so the app still only uses exempt encryption and `ITSAppUsesNonExemptEncryption` stays **NO**.
- Re-check this if we ever add end-to-end chat encryption (crypto inside the app → likely YES + encryption documentation in App Store Connect), a VPN, or a custom crypto library.
- Refs: https://help.apple.com/xcode/mac/current/en.lproj/dev0dc15d044.html , https://developer.apple.com/documentation/appstoreconnectapi/app-encryption-declarations.md
