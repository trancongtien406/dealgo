# Mobile App Entry & Onboarding Flow (S001–S007) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hoàn thiện và hiện đại hóa toàn bộ luồng khởi động, onboarding, xác thực và nhập môn của ứng dụng Flutter DealGo theo thiết kế mới (`design/mockups/new/S001.png` đến `S007.png`), đưa người dùng vào thẳng trang người dùng (`/customer`) khi đã có phiên và chuyển vai trò qua trang cá nhân.

**Architecture:** Mở rộng kiến trúc hiện tại của `mobile/`: `GoRouter` quản lý định tuyến xuất phát từ `/splash`, `AuthCubit` và `PhoneAuthCubit` quản lý phiên xác thực, `OnboardingStorage` lưu cờ `has_seen_onboarding`, và các presentation widget sử dụng hệ thống token chuẩn (`DealGoColors`, `DealGoDimensions`, `DealGoSpacing`) kết hợp assets 3D mới (`hero_dealgo_danang.png`, `hero_otp_shield.png`, `role_*_3d.png`).

**Tech Stack:** Flutter 3.47.7 (Dart 3.13.5), `go_router`, `flutter_bloc`, `flutter_secure_storage`.

**Spec:** [docs/superpowers/specs/2026-10-17-mobile-app-entry-flow-design.md](file:///Users/mac/mern/personal/dealgo/docs/superpowers/specs/2026-10-17-mobile-app-entry-flow-design.md)

## Global Constraints

- Một app Flutter duy nhất cho Customer / Merchant / Driver (DEC-PROD-002).
- Không tự ý thêm package bên ngoài mà chưa cần thiết; tận dụng các thư viện sẵn có trong `pubspec.yaml`.
- Đã có session thì vào thẳng trang người dùng (`/customer`), đổi role qua trang cá nhân (`/customer/account` -> `/roles`).
- Chạy `flutter test` sau mỗi thay đổi để đảm bảo chất lượng.

---

### Task 1: OnboardingStorage Helper & Tests

**Files:**
- Create: `mobile/lib/core/storage/onboarding_storage.dart`
- Test: `mobile/test/onboarding_storage_test.dart`

**Interfaces:**
- Produces: `class OnboardingStorage { Future<bool> hasSeenOnboarding(); Future<void> setSeenOnboarding(bool value); }`

- [ ] **Step 1: Write test for OnboardingStorage**
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Implement OnboardingStorage**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 2: Routing & Auth Redirect Updates

**Files:**
- Modify: `mobile/lib/features/identity/domain/auth_redirect.dart`
- Modify: `mobile/lib/app/router/app_router.dart`
- Modify: `mobile/lib/app/dealgo_app.dart`
- Test: `mobile/test/auth_flow_test.dart`

**Interfaces:**
- Consumes: `AuthRoutes.splash`, `AuthRoutes.profileSetup`, `AuthRoutes.permissions`
- Produces: Cập nhật `authRedirect` để người dùng đã đăng nhập vào thẳng `/customer`, hỗ trợ mở `/roles` từ account.

- [ ] **Step 1: Write/Update test for entry route and redirect to customer**
- [ ] **Step 2: Update auth_redirect.dart with new routes and rules**
- [ ] **Step 3: Update app_router.dart and dealgo_app.dart initialLocation = AuthRoutes.splash**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 3: Modernize S001 Splash Screen

**Files:**
- Modify: `mobile/lib/features/identity/presentation/pages/splash_page.dart`
- Test: `mobile/test/onboarding_screens_test.dart`

**Interfaces:**
- Produces: `DealGoSplashScreen` hiển thị logo DealGo, `hero_dealgo_danang.png`, 2 floating pill badges ("Đặt xe", "Đồ ăn"), progress bar gradient hoạt họa và tự động chuyển trang sau khi kiểm tra phiên.

- [ ] **Step 1: Update splash screen test to verify visual components and auto-navigation**
- [ ] **Step 2: Update splash_page.dart with high-fidelity mockup S001 layout**
- [ ] **Step 3: Run test to verify it passes**
- [ ] **Step 4: Commit**

---

### Task 4: Modernize S002 Onboarding Page

**Files:**
- Modify: `mobile/lib/features/onboarding/presentation/pages/customer_onboarding_page.dart`
- Test: `mobile/test/onboarding_screens_test.dart`

**Interfaces:**
- Produces: `CustomerOnboardingPage` 3 slide với hero visual 3D, floating badges, dots indicator, lưu cờ `has_seen_onboarding` khi hoàn tất hoặc bấm "Bỏ qua".

- [ ] **Step 1: Update customer onboarding tests**
- [ ] **Step 2: Update customer_onboarding_page.dart according to S002.png**
- [ ] **Step 3: Run test to verify it passes**
- [ ] **Step 4: Commit**

---

### Task 5: Modernize S003 Phone Login Page

**Files:**
- Modify: `mobile/lib/features/identity/presentation/pages/phone_login_page.dart`
- Test: `mobile/test/phone_login_screen_test.dart`

**Interfaces:**
- Produces: `PhoneLoginPage` với top bar trợ giúp, hero Đà Nẵng, ô nhập SĐT kèm cờ Việt Nam `+84`, nút Tiếp tục, đăng nhập Email/Passkey.

- [ ] **Step 1: Write/update test for S003 PhoneLoginPage**
- [ ] **Step 2: Update phone_login_page.dart according to S003.png**
- [ ] **Step 3: Run test to verify it passes**
- [ ] **Step 4: Commit**

---

### Task 6: Modernize S004 OTP Page

**Files:**
- Modify: `mobile/lib/features/identity/presentation/pages/otp_page.dart`
- Test: `mobile/test/otp_screen_test.dart`

**Interfaces:**
- Produces: `OtpPage` với top bar đổi số, hero `hero_otp_shield.png`, 6 ô nhập PIN rời, đếm ngược 30 giây, card nhắc bảo mật.

- [ ] **Step 1: Write/update test for S004 OtpPage**
- [ ] **Step 2: Update otp_page.dart according to S004.png**
- [ ] **Step 3: Run test to verify it passes**
- [ ] **Step 4: Commit**

---

### Task 7: Implement S005 Profile Setup & S006 Permissions

**Files:**
- Create: `mobile/lib/features/onboarding/presentation/pages/profile_setup_page.dart`
- Create: `mobile/lib/features/onboarding/presentation/pages/permissions_page.dart`
- Test: `mobile/test/profile_and_permissions_test.dart`

**Interfaces:**
- Produces: `ProfileSetupPage` (S005) và `PermissionsPage` (S006).

- [ ] **Step 1: Write tests for S005 ProfileSetupPage and S006 PermissionsPage**
- [ ] **Step 2: Implement profile_setup_page.dart and permissions_page.dart**
- [ ] **Step 3: Wire into app_router.dart**
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

---

### Task 8: Modernize S007 Role Picker Page & Account Integration

**Files:**
- Modify: `mobile/lib/features/shell/presentation/role_picker_page.dart`
- Modify: `mobile/lib/features/shell/presentation/account_page.dart`
- Test: `mobile/test/role_picker_screen_test.dart`

**Interfaces:**
- Produces: `RolePickerPage` hiển thị 3 card 3D (Khách hàng, Cửa hàng, Tài xế). Nút "Chuyển vai trò" từ trang cá nhân mở `/roles`.

- [ ] **Step 1: Write/update tests for S007 RolePickerPage**
- [ ] **Step 2: Update role_picker_page.dart with 3D illustrations**
- [ ] **Step 3: Ensure AccountPage links to /roles cleanly**
- [ ] **Step 4: Run tests to verify they pass**
- [ ] **Step 5: Commit**

---

### Task 9: Full Regression Testing & Verification

**Files:**
- All modified mobile test files

- [ ] **Step 1: Run `flutter analyze` in `mobile/`**
- [ ] **Step 2: Run `flutter test` across all mobile test suites**
- [ ] **Step 3: Final commit and summary**
