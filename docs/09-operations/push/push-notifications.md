# Push notifications (FCM → APNs/Android), DEV setup

## How it works
1. Domain changes write **outbox events** (Ride / FoodOrder status, ride offer received, food order change, partner application).
2. `OutboxRelayService` delivers each event to the socket rooms, then calls the audience rules in `backend/src/modules/communication/notification/notification-audience.ts`, which decide **who** gets a push and what it says:

| Trigger | Recipient | Title |
|---|---|---|
| Food `PLACED` | merchant | "Đơn mới #XXXX" |
| Food `ASSIGNED` | merchant | "Tài xế đang đến lấy đơn #XXXX" |
| Ride `ASSIGNED` | driver | "Khách đã chọn bạn" |
| Other status changes | customer | status text |
| Cancellation | the other parties | "Chuyến/Đơn … đã hủy" |
| First driver offer on a ride | customer | "Có tài xế báo giá" |
| Ride `ASSIGNED`/`EN_ROUTE` → `NEGOTIATING` (ops reassign or start timeout) | driver | "Chuyến #XXXX đã chuyển cho tài xế khác" → driver jobs |
| Same revert | customer | "Đang tìm tài xế khác" → offers |
| Store edited the order (`PENDING`) / customer accepted | customer / merchant | "Quán đã điều chỉnh đơn …" / "Khách đã đồng ý điều chỉnh đơn …" |
| Partner application approved / rejected | applicant | "Hồ sơ đã được duyệt" / "Hồ sơ chưa được duyệt" |

3. These pushes are sent directly, not from the outbox:
   - **New nearby ride request** (`ride-offer-fanout.service.ts`) → drivers in range: "Cuốc xe mới gần bạn · <giá>đ", body "pickup → dropoff". High priority, collapses per ride, TTL = time until the request expires (min 15 s), at most once per driver per ride per minute. Admin settings `RIDE_REQUEST_PUSH_ENABLED` and `RIDE_REQUEST_PUSH_MAX_DRIVERS` (nearest first; 0 = off).
   - **Chat message** (`chat.service.ts`) → the other party: "Tin nhắn mới từ tài xế/khách", body "Chuyến/Đơn #XXXX: mở ứng dụng để xem." The message text is never in the push. At most one push per thread and recipient every 30 s; collapses per thread.
   - **Incoming call** (`voice.service.ts`, `eventType: Call.incoming`) → the callee: "Khách/Tài xế đang gọi cho bạn", body "Chuyến/Đơn #XXXX: chạm để nghe máy." High priority, TTL 40 s (the ring time), collapses per call (`call-<callId>`), `data.callId` set. Always sent while voice calls are on; notification preferences do not apply. Tapping it opens the trip/order screen and the app rings the call screen. In the foreground the app shows no banner for it; the Socket.IO `call` event rings instead. When `APNS_*` is configured the callee's iOS devices also get a PushKit VoIP push (see [Incoming calls: CallKit and PushKit](#incoming-calls-callkit-and-pushkit)).
   - **Missed call** (`eventType: Call.missed`) → the callee when nobody answered or the caller hung up first: "Cuộc gọi nhỡ từ khách/tài xế", body "Chuyến/Đơn #XXXX: mở ứng dụng để gọi lại." Same collapse key, so it replaces the ringing notification. Tapping it (ride or food, either role) opens the job page with `?chat=1`, so the chat with the missed-call note opens on arrival. Skipped when the callee turned the `chat` toggle off. A "📞 Cuộc gọi nhỡ" note is also written into the trip chat.
4. Other pushes respect the user's notification preferences (`PATCH /v1/me/notification-preferences`; toggles `ride`, `food`, `chat`, `promotion`, `news`). SYSTEM pushes (partner application results) always go out. Chat pushes are filtered by the `ride` / `food` toggle of their ride or order; the `chat` toggle does not apply to them.
5. `PUSH_SENDER` sends to every token in `push_device_tokens` for that user:
   - `FcmPushSender` (FCM HTTP v1) when `PUSH_PROVIDER=fcm`;
   - `MockPushSender` (logs only) when `PUSH_PROVIDER` is `mock` or unset, outside production;
   - `UnavailablePushSender` when FCM credentials are missing or the provider is unknown. With `NODE_ENV=production` the API refuses to start unless `PUSH_PROVIDER=fcm` with credentials.
6. The order code is the last 4 characters of the id (`#BE9B`), the same as in the app.

## Payload and tap target
Each push carries `data`: `aggregateType`, `aggregateId`, `status` (when relevant), `eventType`, `role` (recipient role: CUSTOMER / DRIVER / MERCHANT) and `path`, the app route to open on tap (`push-path.ts`):

| Aggregate | Role | `path` |
|---|---|---|
| Ride | customer | `/customer/ride/offers/:id` while negotiating or for an offer, else `/customer/ride/tracking/:id` |
| Ride | driver | `/driver/jobs` for a new request, a ride still negotiating (except chat) or a cancelled/expired ride, else `/driver/rides/:id/active` |
| FoodOrder | customer | `/customer/food/orders/:id` |
| FoodOrder | driver | `/driver/food/:id` (`/driver/jobs` once cancelled/failed, except chat) |
| FoodOrder | merchant | `/merchant/orders/:id` (`/merchant/orders` once cancelled/failed) |
| SupportTicket | any | `/<role>/account/help/tickets/:id` |
| PartnerApplication | applicant | `/driver/kyc/status` or `/merchant/kyb/status` |
| NotificationCampaign | any | `/<role>/account/notifications` |

The app checks `path` against the signed-in roles and the app's real routes (`NotificationRouter.resolve`). A path for another role, or one the app no longer has, opens the signed-in role's inbox (`/<role>/account/notifications`). Pushes without `path` are routed from `aggregateType`/`status` by the same table (`derivePushPath`), and `test/deep_link_inventory_test.dart` checks that every path above is a real screen.

## Deep links
The app opens three kinds of links. All go through `DeepLinkGate` (`mobile/lib/core/deeplink/deep_link_gate.dart`) and land on the same screens as the push paths:

| Link | Example | Notes |
|---|---|---|
| Custom scheme | `dealgo://driver/jobs`, `dealgo://customer/rides/<id>` | The host is the first path segment. |
| Universal / App Links | `https://dealgo.vn/app/driver/jobs` | `/app/*` is served by `/.well-known/apple-app-site-association` and `assetlinks.json` (`APP_LINKS_*`, DEC-PROD-058). The `/app` prefix is dropped. |
| Push tap | `data.path` | See the table above. |

Rules (`canonicalDeepLinkLocation` and `resolveLinkLocation`):
- Trailing slashes are ignored. `?chat=1` opens the chat sheet on the trip/order screen.
- Short forms are expanded: `/customer/rides/<id>` and `/customer/ride/<id>` → `/customer/ride/tracking/<id>`, `/driver/rides/<id>?chat=1` → `/driver/rides/<id>/active?chat=1` (the active trip carries the chat).
- A real screen for the signed-in role opens as is.
- Bare role links (`dealgo://driver`, `dealgo://customer`, `dealgo://merchant`) and unknown pages under the user's role open that role's home.
- A link for a role the user does not have: account pages (`/<role>/account/...`) open the same page in the user's own role, everything else opens the user's start page (their home, or the role picker when they have several roles).
- `dealgo://` and `dealgo://app` alone just open the app.
- Cold start or signed out: the link is kept, the app signs in first and then applies the same rules, so a link never opens a screen of another role.
- Test on a simulator: `xcrun simctl openurl <udid> 'dealgo://driver/jobs'`. Unit tests: `test/deep_link_inventory_test.dart`, `test/deep_link_chat_test.dart`, `test/push_route_test.dart`.

## New job sounds
New rides, new food delivery jobs and new store orders play a short spoken alert (Vietnamese voice) instead of the default notification sound:

| Push | Who | Sound file | Android channel |
|---|---|---|---|
| `Ride.request.nearby` | driver | `dealgo_new_ride` — "DealGo, có cuốc mới" | `dealgo_new_ride_v1` |
| `FoodOrder.request.nearby` | driver | `dealgo_new_food_job` — "DealGo, có đơn giao mới" | `dealgo_new_food_job_v1` |
| FoodOrder `PLACED` to `MERCHANT` (not a change request) | merchant | `dealgo_merchant_new_order` — "DealGo, quán có đơn mới" | `dealgo_merchant_new_order_v1` |

- **Backend** (`integrations/push/new-job-sound.ts`, `notification/new-job-alert.ts`): these pushes carry `PushNotification.alert`. When the admin setting `NEW_JOB_CUSTOM_SOUND_ENABLED` and the user's `newJobSound` preference (`PATCH /v1/me/notification-preferences`, "Âm báo có đơn mới") are both on, FCM gets `aps.sound = <name>.caf`, `android.notification.channel_id = <name>_v1`, `sound = <name>` and `data.alertSound = <name>`. Otherwise it gets `channel_id = dealgo_new_job_default_v1` and `sound = default`. A settings or prefs read error falls back to the custom sound. Merchant new-order pushes are high priority.
- **Files**: iOS `mobile/ios/Runner/<name>.caf` (bundled in Runner Resources); Android `res/raw/<name>.ogg` (kept by `res/raw/keep.xml`); Flutter `mobile/assets/sounds/<name>.mp3` for the foreground player. Each clip is 4–5 s (iOS allows up to 30 s).
- **Android channels** are created at app start (`NewJobChannels.kt`, called from `MainActivity.onCreate`): the three above plus `dealgo_new_job_default_v1`, all IMPORTANCE_HIGH with vibration. A channel's sound cannot change once created on a device: a new sound needs a new `_vN` id in the app and the backend together. Until the app has run once, Android uses the FCM fallback channel.
- **Foreground**: Android shows no system notification for a foreground push, so `NewJobAlert` (`mobile/lib/core/push/new_job_alert.dart`) vibrates and plays the asset with `flutter_ringtone_player` (`data.alertSound` present → spoken file, absent → default notification sound). The merchant order board also triggers it when a reload finds an unseen `PLACED` order. Triggers within 6 s of the last sound (longer than any clip) are dropped, so a burst of jobs plays once. iOS presents foreground pushes with their sound itself, so socket triggers do not play there.
- **Users** turn it off under Tài khoản › Thông báo › "Âm báo có đơn mới" (drivers and merchants only). The app caches the choice locally for socket triggers.
- **Voice source**: the clips were generated with Microsoft Edge read-aloud TTS (`vi-VN-NamMinhNeural`). Its commercial licence is unclear; replace them with an Azure Speech export or a recorded voice before a public release (same names, new `_vN` channel ids).

## Device token API
| Method | Path | Body |
|---|---|---|
| POST | `/v1/me/push-tokens` | `{ "token": "<fcm token>", "platform": "ios" \| "android" }` (idempotent upsert) |
| DELETE | `/v1/me/push-tokens` | `{ "token": "<fcm token>" }` (on sign-out; the app calls it from `AuthCubit.beforeSignOut`, 3 s limit) |

iOS also registers its PushKit token with `platform: "ios-voip"` on the same endpoint and removes it on sign-out. When iOS issues or rotates the PushKit token later (it often arrives after sign-in), the app uploads it again (`NativeCallUi.voipTokenChanges` → `FcmPush`). `ios-voip` tokens are only used by the APNs VoIP sender; FCM never receives them.

## Env (backend/.env — placeholders only, never commit real values)
```
PUSH_PROVIDER=fcm            # mock in dev; production requires fcm
FCM_PROJECT_ID=<firebase-project-id>
FCM_CLIENT_EMAIL=<service-account-email>
FCM_PRIVATE_KEY=<PEM, \n-escaped>
# or FCM_SERVICE_ACCOUNT_PATH=./<service-account>.json / GOOGLE_APPLICATION_CREDENTIALS

# iOS incoming calls (PushKit VoIP over APNs token auth). Key id and team id are not secret.
APNS_KEY_ID=TL36K38ZKR
APNS_TEAM_ID=6J3522877H
APNS_KEY_PATH=                                # ./secrets/AuthKey_TL36K38ZKR.p8; blank = VoIP off
# or APNS_PRIVATE_KEY=<PEM, \n-escaped>       (APNS_PRIVATE_KEY_PATH is still read as an old name)
APNS_BUNDLE_ID=com.trancongtien.dealgo        # VoIP topic = <bundle id>.voip
APNS_ENV=sandbox                              # production for TestFlight / App Store builds
```
`backend/.env.example` (dev) and `backend/.env.production.example` (production) list these. Without `APNS_ENV`, the host follows `APNS_SANDBOX`, else `NODE_ENV` (production → `api.push.apple.com`, otherwise `api.sandbox.push.apple.com`).

At boot the backend logs one `VoipPush` line: VoIP on (key id, team, topic, host), or off and why. Nothing set, or only the key id and team id, is a clean no-op: calls ring through the FCM alert. With `NODE_ENV=production`, a half-done setup stops the boot with a clear error: key file missing or unreadable, key not a valid `.p8`, key without key id or team id, or an `APNS_ENV` other than `sandbox`/`production`. A sandbox host under `NODE_ENV=production` only logs a warning.

## iOS
- Upload the **APNs Auth Key (.p8)** to Firebase Console → Project settings → Cloud Messaging → Apple app configuration, with Key ID `TL36K38ZKR` and Team ID `6J3522877H`. Normal iOS pushes go through FCM, so this is their only APNs setup; the backend has no other APNs config. The same team-scoped key (Sandbox & Production) also signs the VoIP pushes.
- `mobile/ios/Runner/GoogleService-Info.plist` must come from the same Firebase project.
- `Runner.entitlements` has `aps-environment` development (debug) and `Runner-Release.entitlements` has production (Release, TestFlight and App Store). The Push Notifications and Background Modes → Remote notifications capabilities must be on.
- Simulator: real FCM tokens are not delivered to the iOS Simulator. Test the display with `xcrun simctl push` (below).

## Android
- `mobile/android/app/google-services.json` comes from the same Firebase project. Android 13+ asks for the POST_NOTIFICATIONS permission at runtime.

## Incoming calls: CallKit and PushKit
- **Ringing in the app.** While a call rings, the app loops the device ringtone and vibrates (`SystemCallRinger`): Android plays the default ringtone natively; iOS replays the system sound on a timer. It stops on answer, decline, hang-up, timeout or when the other side cancels.
- **Native call UI** (`CallkitNativeCallUi`, `flutter_callkit_incoming`): CallKit on iOS, a self-managed ConnectionService call with a full-screen incoming UI on Android. Answer, decline and hang-up on the native UI drive the same call flow as the in-app call screen. Platform errors are swallowed, so the in-app screen always works.
- **App in the background or killed:**
  - Android: `Call.incoming` is a high-priority **data-only** FCM message (`androidDataOnly`: no `notification` block; `title`/`body` are in `data`). The FCM background handler shows the native full-screen incoming-call UI, so no second tray notification appears beside it. iOS still gets a visible alert from `aps.alert` and web a `webpush` card.
  - Android 14+: full-screen call intents need the user's consent unless Google Play grants it. After notifications are allowed, the app checks `canUseFullScreenIntent()` and, if it is off, opens the system setting once per install (`ensureFullScreenCalls`). Without it, the call shows as a heads-up notification that still rings.
  - iOS: `VoiceService` sends a PushKit VoIP push to every `ios-voip` token of the callee (`ApnsVoipPushSender`, ES256 token auth, topic `<APNS_BUNDLE_ID>.voip`, priority 10, expires with the ring time). Tokens APNs reports as gone (410 / BadDeviceToken / Unregistered) are removed. `AppDelegate` reports a CallKit call for every VoIP push, as Apple requires, even for a malformed payload or before the plugin is attached (then it ends that call right away). Without an APNs key (`DisabledVoipPushSender`), iOS only gets the FCM alert push.
- **Permissions and capabilities.** iOS Info.plist background modes `audio`, `voip`, `remote-notification`. Android declares `BLUETOOTH_CONNECT` (asked at runtime on Android 12+ before a call, for headset audio); the call plugin's own manifest adds what its full-screen incoming UI needs.
- **Known limitations:**
  - CallKit and PushKit do not work on the iOS Simulator; they are untested on a real device.
  - iOS rings once: the backend sends the VoIP push first and, when at least one is delivered, sends the FCM `Call.incoming` copy with `skipPlatforms: ['ios']`. In the foreground, `AppDelegate` `willPresent` hides the `Call.incoming` banner. The in-app ringer stays silent while the native UI rings (`nativeRinging`). Android shows only the native UI (data-only push).
  - Android uses `launchMode="singleTask"` and `proguard-rules.pro` keeps flutter_callkit_incoming, LiveKit/WebRTC and Firebase. The R8 release APK and AAB build, and the R8 mapping keeps `CallkitIncomingActivity`, `LiveKitPlugin`, `org.webrtc.*` and `FirebaseMessagingService` under their own names.
- **Dev APNs check:** the dev `backend/.env` points `APNS_KEY_PATH=./AuthKey_TL36K38ZKR.p8` (git-ignored) with `APNS_ENV=sandbox`, and the boot log says `iOS VoIP pushes on … https://api.sandbox.push.apple.com`. To prove token auth without a phone, run a push to a dummy token on both hosts (`node <script>` that builds `ApnsVoipPushSender` from `dist/integrations/push/apns-voip-sender.js` with `APNS_ENV=sandbox` and then `production`). Both hosts answer `400 BadDeviceToken`, so the key, key id and team are accepted (a bad key gives `403 InvalidProviderToken`). A real-device CallKit test still needs an iPhone connected to the Mac.
- **Owner key setup (the code is ready; only the key is needed):**
  1. Apple Developer → Certificates, IDs & Profiles → Keys: the key `TL36K38ZKR` (APNs, Sandbox & Production, team `6J3522877H`). Download `AuthKey_TL36K38ZKR.p8` once and keep it in a password manager.
  2. Firebase Console → Project settings → Cloud Messaging → Apple app configuration: upload the same `.p8` with Key ID `TL36K38ZKR` and Team ID `6J3522877H` (normal iOS pushes).
  3. Server: copy the `.p8` next to the backend, outside git (`*.p8` is git-ignored), readable only by the service user (`chmod 600`). Set `APNS_KEY_PATH=<path>` (or `APNS_PRIVATE_KEY`). Leave `APNS_KEY_ID=TL36K38ZKR`, `APNS_TEAM_ID=6J3522877H` and `APNS_BUNDLE_ID=com.trancongtien.dealgo`. Set `APNS_ENV=production` for TestFlight/App Store builds, or `sandbox` for Xcode debug installs.
  4. Restart and look for the `VoipPush` log line saying `iOS VoIP pushes on` with the expected host.
  5. Apple Developer → Identifiers → `com.trancongtien.dealgo`: Push Notifications on (the entitlements are already in the project). Set up prod LiveKit (`VOICE_PROVIDER=livekit`).
  6. Test on a real iPhone and a real Android phone: locked, in the background and killed. Expect one ring, the native call screen, and no extra tray notification on Android.

## Local display test (simulator)
```
xcrun simctl push <udid> com.trancongtien.dealgo docs/09-operations/push/sample-food-placed.apns
```

## Tests
- Backend: `npx vitest run src/modules/communication src/integrations/push` covers the audience rules, the FCM sender, token register/unregister and offer pushes.
- Backend: `npx vitest run src/integrations/voice` covers the call pushes.
- Backend: `npx vitest run src/integrations/push` also covers `apns-voip-sender` (config/no-op reasons, key file or inline key, sandbox vs production host, JWT, topic, dead-token cleanup) and the data-only incoming-call FCM message. `src/platform/config/env.spec.ts` covers the production APNs checks.
- Mobile: `test/driver_job_resume_test.dart` (socket hint instead of polling); `test/voice_call_test.dart` (push tap before and after sign-in rings the call screen); `test/voice_native_call_test.dart` (ringer, native answer/decline/hang-up, no echo back to the native UI, caller label from a data-only push); `test/deep_link_inventory_test.dart` (every push path and deep link resolves to a real screen for the right role).
