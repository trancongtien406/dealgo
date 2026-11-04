# Data safety — câu trả lời cho Play Console

> Đường dẫn: **Nội dung ứng dụng → An toàn dữ liệu**.
> Mọi mục phải khớp: (a) code thực tế, (b) Chính sách quyền riêng tư, (c) màn hình trong bản nộp.
> Nhãn: **VERIFIED** / **ASSUMED** / **ACTION**.

## 1. Nguyên tắc khai

- **Collected** = dữ liệu được truyền ra khỏi thiết bị (kể cả tới server của DealGo hoặc processor).
- **Shared** = chuyển cho bên thứ ba; processor cũng tính.
- **Linked** = gắn được với tài khoản/thiết bị/identifier. App có tài khoản → phần lớn **Yes**.
- **Optional** = người dùng có thể từ chối mà vẫn dùng được chức năng chính.
- Không khai dữ liệu chỉ tồn tại trên máy (debug log bị tắt breadcrumbs, cache).
- `sendDefaultPii = false` và `scrubEvent` trong `mobile/lib/core/observability/crash_reporting.dart` loại request/URL query, chỉ giữ user id.

## 2. Bảng khai báo

| Nhóm | Loại dữ liệu | Thu thập | Chia sẻ | Mục đích | Bắt buộc? | Liên kết người dùng | Bằng chứng |
|---|---|---|---|---|---|---|---|
| Personal info | Name | Có | Không | App functionality, Account management | Có | Có | hồ sơ, KYC, đơn hàng |
| Personal info | Email address | Có | Có (SMS/email provider) | App functionality, Account management, Fraud prevention | Có (nếu đăng ký email) | Có | đăng ký/OTP email |
| Personal info | Phone number | Có | Có (SMS provider) | App functionality, Account management, Fraud prevention | Có | Có | OTP, liên hệ tài xế/khách |
| Personal info | Address | Có | Không | App functionality | Có (khi đặt) | Có | điểm đón/điểm giao |
| Personal info | User IDs | Có | Có (Sentry) | App functionality, Analytics, Fraud prevention | Có | Có | `setCrashReportingUser` |
| Personal info | Other info (DOB, giấy tờ, GPLX, biển số) | Có | Không | App functionality, Fraud prevention/Compliance | Có với tài xế/merchant | Có | `PartnerApplication.metadata` |
| Financial info | Purchase history | Có | Có (PSP) | App functionality | Có | Có | chuyến, đơn, top-up |
| Financial info | Other financial info (số dư/công nợ phí, lịch sử nạp/hoàn) | Có | Có (PSP) | App functionality | Có với tài xế | Có | `driver_top_ups`, `driver_balance_adjustments` |
| Financial info | User payment info | **Không** | — | — | — | — | không lưu số thẻ/tài khoản; PSP xử lý |
| Location | Approximate location | Có | Có (map tile provider — ASSUMED) | App functionality | Có | Có | tìm quán/tài xế gần |
| Location | Precise location | Có | Có (map tile provider — ASSUMED) | App functionality | Có khi đặt xe/giao | Có | GPS foreground |
| Messages | In-app messages | Có | Không | App functionality | Không (khi chat) | Có | `ChatMessage`, support |
| Photos and videos | Photos | Có | Không | App functionality | Không (avatar/chat); Có (KYC) | Có | avatar, KYC, chat |
| Audio | Voice or sound recordings | **Có điều kiện** | Có (LiveKit) | App functionality | Không (chỉ khi gọi) | Có | cuộc gọi trong app; **không ghi âm** |
| Files and docs | Files and docs | Có | Không | App functionality | Có với KYC/KYB | Có | giấy tờ, tệp hỗ trợ |
| App activity | App interactions | Có | Không | App functionality, Analytics | Có | Có | log sự kiện, đơn |
| App activity | In-app search history | Có | Không | App functionality | Không | Có | tìm quán/địa chỉ |
| App activity | Other user-generated content | Có | Không | App functionality | Không | Có | đánh giá, ghi chú |
| App info & performance | Crash logs | Có | Có (Sentry) | App functionality, Analytics | Có | Có (user id) | `sentry_flutter` |
| App info & performance | Diagnostics | Có | Có (Sentry) | App functionality, Analytics | Có | Có | phiên bản app/OS/thiết bị |
| Device or other IDs | Device or other IDs | Có | Có (Firebase, Sentry) | App functionality, Analytics, Fraud prevention | Có | Có | FCM token |

Không khai (không thu thập): Health, Contacts, Calendar, SMS/MMS, Call logs, Web browsing, Files ngoài phạm vi, Race/ethnicity, Political/religious, Sexual orientation, Credit score.

### 2.1. Điều kiện của Audio

- Nếu bản nộp có `VOICE_PROVIDER=livekit` → khai **Audio → Voice or sound recordings**, mục đích App functionality, **không lưu bản ghi**.
- Nếu `VOICE_PROVIDER=none` (hoặc mock) trong bản nộp → **không khai Audio**.
- Kiểm tra trước khi nộp; đừng khai theo môi trường dev.

### 2.2. Financial info — vì sao có “Other financial info”

- Tài xế có **số dư trả trước phí nền tảng** và **công nợ phí**; app hiển thị số dư, lịch sử nạp, hoàn tiền.
- Play mô tả `Other financial info` gồm “salary or debts” → khớp với công nợ phí.
- **Không** khai `User payment info` vì app không lưu số thẻ/số tài khoản; payOS/VNPAY xử lý và chỉ trả về mã giao dịch/trạng thái.
- Khai `Purchase history` vì có chuyến/đơn/top-up.

## 3. Chia sẻ với bên thứ ba (processors)

| Bên nhận | Dữ liệu | Mục đích | Ghi chú |
|---|---|---|---|
| payOS / VNPAY / MoMo / ZaloPay / ShopeePay / Apple Pay | Purchase history, Other financial info, Phone/Email | Xử lý thanh toán | Chỉ bên được bật trong bản nộp |
| LiveKit | Audio | Truyền cuộc gọi trong app | Chỉ khi bật gọi thoại |
| Sentry | Crash logs, Diagnostics, User ID | Giám sát lỗi | `sendDefaultPii=false`; scrub request/query |
| Firebase Cloud Messaging (Google) | Device IDs | Push notification | Token thiết bị |
| eSMS / SpeedSMS / SMTP/SES | Phone, Email | OTP, thông báo giao dịch | Theo cấu hình |
| Mapbox (tile) | Vị trí khung nhìn (viewport) | Hiển thị bản đồ | **ASSUMED** — xác nhận với privacy counsel; tile request có IP |

> Nếu Play hỏi “shared” cho từng loại, chọn **Yes** khi có processor tương ứng trong bản nộp; chọn **No** khi tính năng đó tắt và không có dữ liệu gửi đi.

## 4. Bảo mật khi truyền và lưu

| Câu hỏi | Trả lời | Bằng chứng |
|---|---|---|
| Dữ liệu được mã hoá khi truyền? | **Có** (HTTPS/WSS) | API production dùng TLS; Socket.IO WSS |
| Người dùng có thể yêu cầu xoá dữ liệu? | **Có** | xoá tài khoản trong app + URL web `/account-deletion` |
| Cam kết tuân thủ Play Families? | **Không áp dụng** | 18+ |
| Dữ liệu có được bán? | **Không** | không có SDK quảng cáo/bán dữ liệu |

## 5. Data deletion (mục riêng trong form)

| Câu hỏi | Trả lời |
|---|---|
| App cho phép tạo tài khoản? | **Có** |
| Có đường dẫn xoá trong app? | **Có** — Tài khoản/Bảo mật → Xoá tài khoản |
| URL yêu cầu xoá ngoài app | **Có** — `https://dealgo.laptrinhapp.com/account-deletion` (public, không login, có `?lang=en`) |
| Dữ liệu bị xoá | Hồ sơ (tên/email/SĐT/ngày sinh/giới tính/ảnh), mật khẩu/passkey/session/push token, địa chỉ đã lưu, thông báo, hồ sơ KYC/KYB, liên hệ trên phiếu hỗ trợ cũ |
| Dữ liệu phải giữ | Hoá đơn/ledger, chuyến/đơn, thu nhập, đánh giá — ẩn danh hoá sau khi xoá, phục vụ đối soát/tranh chấp/nghĩa vụ kế toán |
| Thời gian xử lý | Mặc định 7 ngày sau khi xác nhận (`ACCOUNT_DELETION_GRACE_DAYS`, cấu hình 0–90); sau đó ẩn danh hoá, không khôi phục |

## 6. Đối chiếu Chính sách quyền riêng tư

Trang `/privacy` phải nêu đủ:

- [ ] Các nhóm dữ liệu ở §2, kể cả `Other financial info` của tài xế.
- [ ] Mục đích và cơ sở pháp lý.
- [ ] Danh sách processor ở §3 (tên loại hình, có thể không cần tên thương mại).
- [ ] Thời gian lưu, cách xoá, URL xoá tài khoản.
- [ ] Quyền của người dùng (truy cập, chỉnh sửa, xoá, khiếu nại).
- [ ] Liên hệ bảo vệ dữ liệu.
- [ ] Ngày hiệu lực + phiên bản.

**ACTION:** cập nhật `/privacy` nếu thiếu `Other financial info` hoặc processor mới (payOS/LiveKit/Sentry).

## 7. Sai lệch thường gặp

| Sai lệch | Rủi ro |
|---|---|
| Khai “không thu thập vị trí” nhưng app xin quyền | Reject vì Data safety không trung thực |
| Khai “không chia sẻ” nhưng có Sentry/FCM/PSP | Reject |
| Khai có Audio khi calls tắt | Không khớp bản nộp |
| Không khai Financial info của tài xế | Không khớp màn hình số dư |
| URL xoá tài khoản 404 hoặc yêu cầu đăng nhập | Reject mục Data deletion |
| Chính sách riêng tư không nhắc quyền xoá | Reject |
