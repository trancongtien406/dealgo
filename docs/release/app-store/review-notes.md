# App Review notes (paste into "Notes" in App Store Connect)

DealGo is one app with three roles: Customer, Merchant (Cửa hàng) and Driver (Tài xế). Users choose a role on the Role Center screen and can switch at any time.

**Demo account** (one review account with Customer, Driver and Merchant roles; switch roles on Role Center):
- On the sign-in screen choose **Email**, enter `appreview@dealgo.trancongtien.com` and the password given in the App Review Information fields. No email or SMS is needed.
- If the app ever asks for an email code for this account, enter the 6-digit review code given in the same fields. It works only for this email.
- Roles on the account:
  - Customer.
  - Driver: approved, motorbike, Đà Nẵng. The driver starts offline.
  - Merchant: approved, store **DealGo Demo Đà Nẵng**, open 24h, with 6 menu items. All KYC/KYB data on this account is fake demo data.

**Operator checklist before each submission (DEC-PROD-052)**
1. The credentials are in `/opt/dealgo/env/app-review.txt` on the VPS, with a copy on the owner's Mac (`~/Desktop/dealgo-app-review.txt`). Paste the password and code into App Store Connect → App Review Information. Never commit them.
2. Production state:
   - EMAIL sign-in is on (Admin → Cài đặt → Phương thức đăng nhập) and Admin → Cài đặt → Email has a passing test.
   - `APP_REVIEW_OTP_CODE` is set in `env/backend.env`.
   - `APP_REVIEW_EMAIL` is the review email and `APP_REVIEW_LOGIN_ENABLED` is on.
3. Seed data: `npm run seed:app-review` (backend, idempotent) creates or refreshes the roles, the demo KYC data, the store and its menu. To remove all of it, including the account, run `npm run seed:app-review:cleanup`. In production both need `SEED_ALLOW_PRODUCTION=true` for that run. See `backend/prisma/seed-app-review.ts`.
4. If the reviewer deleted the account (step 5 below):
   - run the cleanup;
   - register the email again in the app with the review code;
   - run the seed.
5. After approval: turn `APP_REVIEW_LOGIN_ENABLED` off. To remove the demo store from the Đà Nẵng food list, run the cleanup.

**How to test**
1. **Ride.** Customer → Đặt xe → choose pickup and drop-off in Đà Nẵng → Đặt xe. A DealGo test driver (operated by our team during the review window) receives the request and sends an offer. Choose the offer, then track the ride.
   - To see the driver side, use Role Center → Tài xế and go online. Locations can be simulated in Đà Nẵng.
2. **Food.** Customer → Đồ ăn → open **DealGo Demo Đà Nẵng** → add an item → Đặt món.
   - The order goes to the review account's own store. Role Center → Cửa hàng shows the order: accept it, mark it ready, and manage the menu and opening status.
   - Role Center → Tài xế (online, food enabled) shows the delivery job.
3. **In-app call.** On an active ride or food order with an assigned driver, tap the phone button on the tracking screen.
   - The test driver answers on a second device. Audio is live and not recorded.
   - Calls are offered only between the customer and the assigned driver while the trip or order is active.
4. **Merchant.** Role Center → Cửa hàng shows the store, menu (2 categories, 6 items), orders and settings.
5. **Account deletion.** Tài khoản → Xoá tài khoản (also reachable from Bảo mật).
   - Type the confirmation word, tick the box and tap "Tiếp tục xóa".
   - Confirm with the system passkey prompt (Face ID / Touch ID). On this review account, which has no passkey, the app asks for the account password instead.
   - The account is signed out and scheduled for deletion.

**Background location / modes:** see compliance-checks.md §3. **Background audio (`UIBackgroundModes: audio`):** used only to keep an in-app voice call between a customer and their assigned driver connected when the screen locks or the app goes to background during the call. No audio is played or recorded outside a call. **Push:** new ride requests for drivers, ride and order status changes, and new chat messages (no message text in the notification).
**Payments:** cash between rider and driver for physical services, so IAP doesn't apply (Guideline 3.1.3(e) / 3.1.5(a): physical goods and services; VERIFIED rule, payment model ASSUMED).
**Service area:** Đà Nẵng, Việt Nam. Reviewers outside VN should use the demo accounts. Locations in the demo can be simulated.
