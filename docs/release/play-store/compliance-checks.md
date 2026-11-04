# Compliance checks — Google Play

> Chụp nhanh trước khi Submit. Đánh giá theo code + policy tại 11/2026.
> **PASS** = đã đối chiếu; **ACTION** = phải làm; **ASSUMED** = cần xác nhận của chủ dự án/legal.

## 0. Bảng tổng

| # | Hạng mục | Kết luận |
|---|---|---|
| 1 | Khai báo Tính năng tài chính | **ACTION** — chọn `Other`, dán mô tả |
| 2 | Payments policy (dịch vụ vật lý) | **PASS** |
| 3 | Quyền ảnh/video (`READ_MEDIA_IMAGES`) | **PASS** — đã bỏ quyền ảnh khỏi manifest |
| 4 | Quyền vị trí (foreground) | **PASS** |
| 5 | Xoá tài khoản — trong app | **PASS** |
| 6 | Xoá tài khoản — URL web | **PASS** — `/account-deletion` |
| 7 | An toàn dữ liệu | **ACTION** — điền form |
| 8 | Chính sách quyền riêng tư | **ACTION** — cập nhật financial info |
| 9 | Quảng cáo / AD_ID | **PASS** |
| 10 | Target API | **ACTION** — xác nhận |
| 11 | AAB / 64-bit | **PASS** |
| 12 | App access | **ACTION** — đặt mật khẩu review |
| 13 | Content rating | **ACTION** |
| 14 | Target audience / Families | **ACTION** — chọn 18+ |
| 15 | Quyền nhạy cảm khác | **PASS** |
| 16 | Play App Signing | **ACTION** |
| 17 | Developer verification | **ACTION** |
| 18 | Closed testing (tài khoản cá nhân) | **ACTION** |
| 19 | Store listing khớp tính năng | **PASS** — sau khi bỏ “Ví DealGo” |
| 20 | Pháp lý NĐ 52/2024 | **ASSUMED** — Legal xác nhận |

## 1. Khai báo Tính năng tài chính — ACTION

- Chọn **duy nhất `Other`**, dán mô tả trong `financial-features.md` §4.
- Không chọn `Mobile payments and digital wallets`, không chọn `none` khi UI tài xế còn hiện.
- Kiểm tra `Policy status` sau khi lưu.
- **Bằng chứng:** `payment-method.catalog.ts` (không có `DEALGO_WALLET`), `driver-credit/*`, `driver_earnings_page.dart`.
- Nếu bật/tắt nạp tiền hoặc thêm ví khách → khai lại **trước** release.

## 2. Payments policy — PASS

- Chuyến xe và đồ ăn là **physical services** → không bắt buộc Google Play Billing.
- Không bán digital goods, không subscription, không tiền ảo.
- Không có nút/link dẫn người dùng mua digital goods ngoài Play.
- **Bằng chứng:** `payment-method.catalog.ts`; không có `in_app_purchase` trong `mobile/pubspec.yaml`.

## 3. `READ_MEDIA_IMAGES` — PASS (đã bỏ quyền)

- Đã bỏ `READ_MEDIA_IMAGES` và `READ_EXTERNAL_STORAGE` khỏi `mobile/android/app/src/main/AndroidManifest.xml`.
- App chỉ **chọn** ảnh KYC/avatar bằng `image_picker` (Android SAF / iOS PHPicker); đã bỏ `Permission.photos.request()` khỏi luồng chọn avatar — không còn prompt quyền ảnh.
- Merged **release** manifest (kiểm tra bằng `:app:processReleaseMainManifest`) không còn `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`.
- `READ_EXTERNAL_STORAGE` còn lại do plugin `camera_android_camerax` khai kèm `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion 28`, Android ≤ 9); không thuộc khai báo "Photo and Video Permissions" của Play.
- Khi thêm plugin mới có đọc thư viện ảnh, kiểm tra lại merged manifest trước khi build AAB.
- **Bằng chứng:** `AndroidManifest.xml`, `app_permission_service.dart`, `profile_form.dart`, `build/app/intermediates/merged_manifest/release/...`.

## 4. Vị trí — PASS

- Chỉ `ACCESS_COARSE_LOCATION` / `ACCESS_FINE_LOCATION`; **không** `ACCESS_BACKGROUND_LOCATION`.
- Chỉ xin khi người dùng đặt xe/giao đồ ăn; có giải thích trong UI.
- **Bằng chứng:** manifest; `app_permission_service.dart`.

## 5. Xoá tài khoản trong app — PASS

- Entry: Tài khoản → Xoá tài khoản; Bảo mật → Xoá tài khoản (mọi role).
- Flow request → xác thực → confirm; purge PII sau grace period.
- **Bằng chứng:** `mobile/lib/features/account_deletion/`, `backend/src/modules/account-deletion/`.

## 6. URL xoá tài khoản ngoài app — PASS

- URL: `https://dealgo.laptrinhapp.com/account-deletion` (dùng đúng domain đã khai cho `/privacy`).
- Play yêu cầu URL công khai, mở được, không cần đăng nhập/tải app → trang tĩnh trong `website/app/account-deletion/`, có bản `?lang=en`.
- Nội dung: cách xoá trong app; form yêu cầu khi đã gỡ app; dữ liệu bị xoá; dữ liệu giữ lại (chuyến/đơn/sổ cái/thu nhập/đánh giá, ẩn danh hoá); thời hạn (mặc định 7 ngày, cấu hình 0–90); điều kiện chặn; huỷ/khôi phục.
- Form gọi `POST /api/public/support` (`category=ACCOUNT`) → phiếu hiện ở **Admin → Hỗ trợ**, trả mã phiếu cho người gửi.
- Vẫn kiểm tra thực tế trước khi Submit: mở ẩn danh, gửi thử, xác nhận phiếu trong Admin.
- **Bằng chứng:** `website/app/account-deletion/`, `website/features/account-deletion/copy.ts`, `website/app/api/public/support/route.ts`.

## 7. An toàn dữ liệu — ACTION

- Điền theo `data-safety.md`; đặc biệt `Financial info → Other financial info`.
- Khai chia sẻ cho PSP/Sentry/FCM/LiveKit/SMS.
- Data deletion: khai URL ở §6.
- **Bằng chứng:** `crash_reporting.dart` (`sendDefaultPii=false`, scrub), `driver_top_ups`, `ChatMessage`, `PartnerApplication`.

## 8. Chính sách quyền riêng tư — ACTION

- URL `/privacy` công khai, không login.
- Phải nhắc: vị trí, ảnh/giấy tờ, audio cuộc gọi, dữ liệu tài chính tài xế, processor, thời gian lưu, quyền xoá.
- Kiểm tra bản tiếng Anh (`?lang=en`) không thiếu mục.

## 9. Quảng cáo / AD_ID — PASS

- Không có SDK quảng cáo; không khai `AD_ID` trong manifest.
- Không bán dữ liệu.

## 10. Target API — ACTION

- Play yêu cầu target API theo năm; kiểm tra cảnh báo trong Console.
- Build bằng Flutter 3.47.x; xem **App bundle explorer → Target SDK**.
- Nếu thấp hơn yêu cầu: nâng Flutter/target SDK và build lại; đừng chỉ sửa manifest.

## 11. AAB / 64-bit — PASS

- `flutter build appbundle --release` tạo AAB có arm64-v8a.
- Không dùng APK cho Production.

## 12. App access — ACTION

- Đặt `APP_REVIEW_PASSWORD` (≥12 ký tự), chạy seed review.
- Ghi email/mật khẩu vào hộp bảo mật của Play Console, không ghi trong mô tả công khai.
- Giữ tài khoản hoạt động trong suốt thời gian review.

## 13. Content rating — ACTION

- Làm bảng IARC; khai **UGC = Có**, **chia sẻ vị trí = Có**, **quảng cáo = Không**, **mua hàng số = Không**.
- Không tự đặt rating; dùng kết quả IARC.

## 14. Target audience / Families — ACTION

- Chọn **18+**; app không thiết kế cho trẻ em.
- Không tham gia Families.
- Nếu chọn nhóm tuổi thấp hơn, phải đáp ứng Families policy (không phù hợp app tài xế).

## 15. Quyền nhạy cảm khác — PASS

- Không `READ_CONTACTS`, `READ_SMS`, `READ_CALL_LOG`, `QUERY_ALL_PACKAGES`, `MANAGE_EXTERNAL_STORAGE`, `SYSTEM_ALERT_WINDOW`.
- `RECORD_AUDIO` chỉ dùng cuộc gọi; `CAMERA` chỉ KYC/ảnh; `BLUETOOTH_CONNECT` chỉ audio cuộc gọi.
- Kiểm tra merged manifest sau khi thêm SDK.

## 16. Play App Signing — ACTION

- Bật trước khi upload AAB đầu tiên.
- Lưu upload keystore + mật khẩu ngoài repo; bật 2FA cho tài khoản developer.

## 17. Developer verification — ACTION

- Android yêu cầu xác minh developer/đăng ký package để cài trên thiết bị certified.
- Làm theo banner trong Play Console; không bỏ qua.

## 18. Closed testing — ACTION (nếu tài khoản cá nhân)

- Tài khoản developer **cá nhân** tạo sau 13/11/2023 cần **≥12 tester** trong **14 ngày liên tục** trước khi mở Production.
- Kiểm tra mục "Production access" trong Console; chuẩn bị tester thật, không dùng tài khoản nội bộ.

## 19. Store listing khớp tính năng — PASS

- Đã bỏ "Ví DealGo (Sắp ra mắt)" khỏi payment picker/admin.
- Metadata không dùng "ví", "wallet", "nạp/rút ví".
- Mô tả tài xế nạp phí khớp màn hình thật.
- Ảnh chụp từ build review, không có dữ liệu thật.

## 20. Pháp lý NĐ 52/2024 — ASSUMED

- Lập luận closed-loop đã ghi trong `docs/02-domain/driver-credit-topup.md` §2 và `financial-features.md` §7.
- **Chưa phải ý kiến pháp lý.** Phải có Legal xác nhận trước khi bật `DRIVER_TOP_UP_ENABLED=true` trên production.
- Nếu Legal yêu cầu giấy phép: giữ tính năng tắt, ẩn UI, khai `none`, và chỉ mở sau khi có giấy phép/đối tác.

## 21. Deep links — ASSUMED

- Manifest có `autoVerify` cho `https://${appLinkHost}/app/*`.
- Cần `/.well-known/assetlinks.json` trên domain; nếu không, link mở trình duyệt (không phải lỗi review, nhưng nên sửa).

## 22. Việc kiểm tra sau khi Submit

- [ ] `Policy status` không còn cảnh báo.
- [ ] Data safety hiển thị đúng trên store listing.
- [ ] Trang xoá tài khoản (`/account-deletion`) mở được từ store listing, không login, gửi được yêu cầu.
- [ ] Internal testing cài được trên máy thật.
- [ ] Không có crash khi mở app lần đầu, đăng nhập, đặt xe/đồ ăn.
