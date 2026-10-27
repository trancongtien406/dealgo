# App Review notes (paste into "Notes" in App Store Connect)

DealGo is one app with three roles: Customer, Merchant (Cửa hàng) and Driver (Tài xế). Users choose a role on the Role Center screen and can switch at any time.

**Demo account** (one review account; it holds Customer, Driver and Merchant roles, switch on Role Center):
- Sign in with phone `+84 …` **or** email `…@…` and the 6-digit code `……`. No SMS or email is sent to this account.
- Fill the phone/email/code in at submission time; never commit them.

**Operator checklist before each submission (DEC-PROD-052)**
1. Production env: set `APP_REVIEW_OTP_CODE` (6 digits, new for every review cycle).
2. Admin → Cài đặt: set `APP_REVIEW_PHONE` and/or `APP_REVIEW_EMAIL`, then turn `APP_REVIEW_LOGIN_ENABLED` on. The fixed code works only for these identifiers, only while the switch is on; each use is logged and each sign-in is written to the audit log; issuance is rate-limited.
3. Use the sign-in method that is enabled for launch (phone OTP, email OTP or passkey can each be off). If phone sign-in is off, give the reviewer the email.
4. Make sure the review account's Driver (KYC approved) and Merchant (KYB approved, store open) roles are ready, with a demo menu item.
5. After approval: turn `APP_REVIEW_LOGIN_ENABLED` off and clear `APP_REVIEW_OTP_CODE`.

**How to test**
1. Customer → Đặt xe → choose pickup and drop-off → Đặt xe. A DealGo test driver (operated by our team during the review window) receives the request and sends an offer. Choose the offer, then track the ride.
2. Customer → Đồ ăn → open a store → add an item → Đặt món. A DealGo test store accepts, and a test driver picks up and delivers. The Driver and Merchant screens can be opened from Role Center on the same account.
3. In-app call: on an active ride or food order with an assigned driver, tap the phone button on the tracking screen. The test driver answers on a second device; audio is live and not recorded. Calls are offered only between the customer and the assigned driver while the trip/order is active.
4. Account deletion: Tài khoản → Xoá tài khoản (also reachable from Bảo mật).

**Background location / modes:** see compliance-checks.md §3. **Background audio (`UIBackgroundModes: audio`):** used only to keep an in-app voice call between a customer and their assigned driver connected when the screen locks or the app goes to background during the call. No audio is played or recorded outside a call. **Push:** new ride requests for drivers, ride and order status changes, and new chat messages (no message text in the notification).
**Payments:** cash between rider and driver for physical services, so IAP doesn't apply (Guideline 3.1.3(e) / 3.1.5(a): physical goods and services; VERIFIED rule, payment model ASSUMED).
**Service area:** Đà Nẵng, Việt Nam. Reviewers outside VN should use the demo accounts. Locations in the demo can be simulated.
