# App content — câu trả lời cho Play Console

> Đường dẫn: **Chính sách và chương trình → Nội dung ứng dụng**.
> Nhãn: **VERIFIED** / **ASSUMED** / **ACTION**.

## 1. Tổng quan các mục

| Mục trong Play Console | Trả lời | Trạng thái |
|---|---|---|
| Chính sách quyền riêng tư | `https://dealgo.laptrinhapp.com/privacy` | **VERIFIED** domain; kiểm tra URL công khai khi Submit |
| Quyền truy cập ứng dụng (App access) | Có tài khoản demo, mô tả trong `review-notes.md` | **ACTION** — đặt mật khẩu review |
| Quảng cáo (Ads) | **Không** | **VERIFIED** — không có SDK quảng cáo trong `pubspec.yaml` |
| Xếp hạng nội dung (Content rating) | Làm bảng IARC; kết quả do IARC cấp | **ACTION** |
| Đối tượng mục tiêu (Target audience) | **18 tuổi trở lên** | **ACTION** — xác nhận chính sách tuổi |
| Tin tức (News) | **Không** | **VERIFIED** |
| An toàn dữ liệu (Data safety) | Xem `data-safety.md` | **ACTION** |
| Ứng dụng chính phủ | **Không** | **VERIFIED** |
| Tính năng tài chính | **Other** + mô tả | **ACTION** — xem `financial-features.md` |
| Ứng dụng y tế | **Không** | **VERIFIED** |
| Thanh toán | **Dịch vụ vật lý — không dùng Google Play Billing** | **VERIFIED** |
| Xoá tài khoản | Có trong app + URL web `/account-deletion` | **PASS** — xem §7 |
| Gia đình / trẻ em | **Không** tham gia chương trình Families | **VERIFIED** |
| Quyền nhạy cảm | Ảnh/video (đã bỏ quyền), vị trí, micro, camera | **PASS** — xem §5 |
| Target API | Theo Flutter hiện tại (3.47.x) | **ACTION** — xác nhận trong App bundle explorer |
| Play App Signing | Bật | **ACTION** — bật trước khi upload AAB đầu |

## 2. App access (quyền truy cập ứng dụng)

Chọn **"Tất cả hoặc một số chức năng bị hạn chế"** và cung cấp:

```
Email: appreview@dealgo.laptrinhapp.com
Password: <đặt APP_REVIEW_PASSWORD, tối thiểu 12 ký tự, giữ nguyên đến khi review xong>
```

Tài khoản này có đủ `CUSTOMER`, `DRIVER`, `MERCHANT` (seed `backend/prisma/seed-app-review.ts`). Nếu dùng OTP thay mật khẩu, bật `APP_REVIEW_LOGIN_ENABLED=true` + `APP_REVIEW_OTP_CODE` và ghi mã trong review notes.

**ACTION:**
- Chạy `npm run seed:app-review` trên môi trường review với `APP_REVIEW_PASSWORD`.
- Không đổi mật khẩu/xoá tài khoản trong thời gian review.
- Nếu app chặn đăng nhập theo vùng, đảm bảo tài khoản review vượt qua.

## 3. Ads, News, Government, Health, Families

| Mục | Chọn | Bằng chứng |
|---|---|---|
| Ads | **No ads** | Không có `google_mobile_ads`, AdMob, Unity Ads, AppLovin… trong `mobile/pubspec.yaml` |
| News | **No** | Không phải app tin tức |
| Government | **No** | Không phải app chính phủ |
| Health | **No** | Không có Health Connect / dữ liệu sức khoẻ |
| Families | **Không** tham gia | App 18+, không thiết kế cho trẻ em |

## 4. Content rating (IARC)

Chọn nhóm gần nhất: **"Tiện ích, Năng suất, Liên lạc hoặc Khác"** (ASSUMED — tên hiển thị có thể thay đổi theo ngôn ngữ Console).

Câu trả lời dự kiến:

| Câu hỏi | Trả lời | Lý do |
|---|---|---|
| Bạo lực | Không | Không có nội dung bạo lực |
| Nội dung tình dục / khêu gợi | Không | — |
| Ngôn từ thô tục | Không | Chat/review có kiểm duyệt? **ASSUMED** — nếu có chat tự do, chọn "Có" và mô tả moderation |
| Ma tuý / rượu / thuốc lá | Không | — |
| Cờ bạc | Không | — |
| Nội dung do người dùng tạo | **Có** | Đánh giá quán, chat với tài xế, ảnh đại diện, ảnh KYC |
| Chia sẻ vị trí | **Có** | Vị trí dùng cho đặt xe/giao hàng |
| Mua hàng trong app | **Không** | Không có IAP kỹ thuật số; chuyến xe/đồ ăn là dịch vụ vật lý |
| Quảng cáo | **Không** | — |
| Chia sẻ thông tin cá nhân với bên thứ ba | **Có** | PSP, LiveKit, Sentry, FCM — xem Data safety |

Hệ thống có thể trả **PEGI 3 / Everyone** hoặc **Teen** do UGC. **Không tự đặt rating**; nộp bảng và dùng kết quả IARC.

## 5. Quyền và khai báo quyền nhạy cảm

Manifest hiện tại (`mobile/android/app/src/main/AndroidManifest.xml`):

| Quyền | Mục đích | Đánh giá |
|---|---|---|
| `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` | Đặt xe, giao đồ ăn, theo dõi tài xế | Hợp lệ; **chỉ foreground**, không có `ACCESS_BACKGROUND_LOCATION` |
| `CAMERA` | Chụp ảnh KYC/ảnh đại diện/ảnh chat | Hợp lệ, có giải thích trong UI |
| `RECORD_AUDIO` | Gọi thoại trong app | Hợp lệ; không ghi âm |
| `POST_NOTIFICATIONS` | Push cuốc/đơn | Hợp lệ |
| `BLUETOOTH`, `BLUETOOTH_CONNECT` | Tai nghe/route âm thanh cuộc gọi | Hợp lệ |
| ~~`READ_MEDIA_IMAGES` + `READ_EXTERNAL_STORAGE`~~ | Chọn ảnh KYC/avatar | **Đã bỏ** — xem §5.1 |
| `INTERNET`, `ACCESS_NETWORK_STATE`, `CHANGE_NETWORK_STATE`, `MODIFY_AUDIO_SETTINGS` | Mạng/âm thanh | Bình thường |

Không có: `READ_CONTACTS`, `READ_SMS`, `READ_CALL_LOG`, `QUERY_ALL_PACKAGES`, `ACCESS_BACKGROUND_LOCATION`, `SYSTEM_ALERT_WINDOW`, `MANAGE_EXTERNAL_STORAGE`.

### 5.1. Quyền ảnh/video — PASS (đã bỏ quyền)

Play **Photo and Video Permissions policy**: app target API 33+ chỉ được khai `READ_MEDIA_IMAGES` nếu **Android Photo Picker không đủ** cho chức năng cốt lõi. Chọn ảnh KYC/avatar **đủ bằng picker hệ thống** → không giữ quyền này.

Đã áp dụng cách khuyến nghị:

- Bỏ `READ_MEDIA_IMAGES` và `READ_EXTERNAL_STORAGE` khỏi `mobile/android/app/src/main/AndroidManifest.xml`.
- Bỏ `Permission.photos.request()` khỏi luồng chọn avatar (`profile_form.dart`); picker mở trực tiếp nên không cần prompt.
- Không cần khai **Photo and Video Permissions declaration**.
- Kiểm tra lại sau build: merged **release** manifest (`:app:processReleaseMainManifest`) không còn `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`.
- `READ_EXTERNAL_STORAGE` vẫn xuất hiện trong merged manifest do `camera_android_camerax` khai kèm `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion 28`); đây là quyền bộ nhớ cũ, không thuộc khai báo quyền ảnh của Play.
- Nếu thêm plugin đọc thư viện ảnh: kiểm tra lại merged manifest trước khi upload AAB.

## 6. Payments (thanh toán)

Chọn: **"Ứng dụng của tôi bán hàng hoá/dịch vụ vật lý"** (nếu Console hỏi), **không** dùng Play Billing.

Căn cứ:

- Chuyến xe = dịch vụ vận chuyển; đồ ăn = giao hàng — **physical services**, được dùng phương thức thanh toán ngoài.
- Không bán vật phẩm số, không subscription, không tiền ảo.
- Phí nền tảng của tài xế là **phí dịch vụ B2B**, không phải hàng hoá số cho người tiêu dùng.
- Không có link/nút dẫn người dùng mua digital goods ngoài Play.

## 7. Xoá tài khoản (Data deletion)

### Trong app — PASS (VERIFIED)

- **Tài khoản → Xoá tài khoản** và **Bảo mật → Xoá tài khoản** (mọi role).
- Flow: `POST /v1/me/account-deletion` → xác thực → `confirm`; xoá mềm, purge PII sau `ACCOUNT_DELETION_GRACE_DAYS`.
- Xem `mobile/lib/features/account_deletion/presentation/delete_account_page.dart`.

### Trên web — PASS (đã có trang)

Play bắt buộc **URL công khai** để người đã gỡ app vẫn yêu cầu xoá. Đã có:

- URL: `https://dealgo.laptrinhapp.com/account-deletion` (dùng đúng domain của `/privacy`).
- Trang: `website/app/account-deletion/page.tsx` + `account-deletion-client.tsx`, nội dung song ngữ tại `website/features/account-deletion/copy.ts`.
- Nội dung đáp ứng yêu cầu Play:
  - Cách xoá ngay trong app (Tài khoản/Bảo mật → Xoá tài khoản).
  - Form gửi yêu cầu khi đã gỡ app — tạo phiếu hỗ trợ (`category=ACCOUNT`), trả mã phiếu, không cần đăng nhập.
  - Dữ liệu bị xoá (hồ sơ, thông tin đăng nhập, địa chỉ, thông báo, hồ sơ KYC/KYB, liên hệ trên phiếu cũ).
  - Dữ liệu giữ lại (chuyến/đơn/sổ cái/thu nhập/đánh giá) và việc ẩn danh hoá sau khi xoá.
  - Thời hạn: mặc định 7 ngày (`ACCOUNT_DELETION_GRACE_DAYS`, cấu hình 0–90), có thể khôi phục trong thời gian chờ.
  - Điều kiện chặn: chuyến/đơn đang chạy, đơn cửa hàng chưa xong, công nợ COD/phí, tài khoản Ops.
  - Kênh liên hệ: hotline/email lấy từ Admin › Website settings, fallback `/support`.

Dán URL vào **Data safety → Data deletion**.

Kiểm tra trước khi Submit: mở ẩn danh, thử `?lang=en`, gửi 1 yêu cầu và xác nhận phiếu xuất hiện trong **Admin → Hỗ trợ**.

## 8. Target API, AAB, Play App Signing

| Việc | Trạng thái | Ghi chú |
|---|---|---|
| Target API theo yêu cầu Play hiện hành | **ACTION** | Flutter 3.47.x dùng target SDK mới; xác nhận trong App bundle explorer. Play thường yêu cầu API 35+ vào 2025–2026 |
| AAB 64-bit | **PASS** | `flutter build appbundle` tạo AAB có arm64-v8a |
| Play App Signing | **ACTION** | Bật trước khi upload bản đầu; giữ upload key an toàn |
| App Links (`autoVerify`) | **ASSUMED** | Manifest có host `${appLinkHost}`; cần `assetlinks.json` trên domain nếu muốn verify |
| Closed testing | **ACTION** | Tài khoản developer **cá nhân** mới cần ≥12 tester trong 14 ngày liên tục trước khi mở Production (kiểm tra trong Console) |
| Developer verification | **ACTION** | Android yêu cầu xác minh developer/đăng ký package; làm theo banner trong Console |

## 9. Nội dung store listing

- Không có “Ví DealGo” / “ví điện tử”.
- Mô tả tài xế nạp phí phải khớp màn hình thật.
- Không hứa tính năng chưa mở.
- Ảnh chụp từ build review, không chứa dữ liệu thật.

## 10. Checklist trước khi Submit

- [ ] Đã chọn `Other` ở Tính năng tài chính và dán mô tả.
- [ ] Đã điền Data safety + URL xoá tài khoản (`/account-deletion`).
- [x] Đã bỏ `READ_MEDIA_IMAGES` — không cần declaration.
- [ ] Đã đặt mật khẩu tài khoản review và seed dữ liệu.
- [ ] Đã cấu hình payOS cho môi trường review **hoặc** ẩn tính năng nạp phí.
- [ ] Đã làm Content rating và chọn 18+.
- [ ] Đã bật Play App Signing.
- [ ] Đã test cài từ Internal testing trên máy thật.
