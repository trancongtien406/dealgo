# DealGo — Google Play kit

> Dùng cho bản nộp **Google Play Console** của app Flutter `mobile/` (một app, ba vai trò Customer / Driver / Merchant).
> Ngôn ngữ chính: **Tiếng Việt (vi-VN)**; ngôn ngữ phụ: **English (en-US)**.
> Nhãn: **VERIFIED** = đối chiếu code/policy; **ASSUMED** = cần chủ dự án xác nhận; **ACTION** = phải làm trước khi bấm Submit.

## 1. Bộ tài liệu

| File | Nội dung |
|---|---|
| `financial-features.md` | **Khai báo Tính năng tài chính** (trọng tâm): chọn ô nào, câu trả lời dán sẵn, lý do, cách trả lời nếu Google hỏi lại |
| `metadata.vi.md` / `metadata.en.md` | Tên app, mô tả ngắn/dài, danh mục, tag, thông tin liên hệ, "Có gì mới" |
| `app-content.md` | Toàn bộ mục **Nội dung ứng dụng**: App access, Ads, Content rating, Target audience, Data deletion, Permissions, Payments… |
| `data-safety.md` | Bảng **An toàn dữ liệu** suy ra từ code, gồm cả `Financial info` của tài xế |
| `review-notes.md` | Ghi chú cho reviewer + tài khoản demo + kịch bản kiểm tra tài xế |
| `compliance-checks.md` | Checklist PASS / ACTION trước khi nộp |

Nguồn policy đã đọc khi soạn (11/2026):

- [Financial features declaration](https://support.google.com/googleplay/android-developer/answer/13849271)
- [Policy announcement 30/10/2025](https://support.google.com/googleplay/android-developer/answer/16550159)
- [Payments policy](https://support.google.com/googleplay/android-developer/answer/10281818)
- [Understanding restricted permissions](https://support.google.com/googleplay/android-developer/answer/14115180)
- [Account deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Data safety data types](https://support.google.com/googleplay/android-developer/answer/10787469)
- [Policy declarations API — Finance](https://developers.google.com/android-publisher/app-store-review/policy-declarations)

## 2. Thứ tự nộp

1. **Chốt trạng thái tính năng tài chính** trong bản nộp: `DRIVER_TOP_UP_ENABLED` bật hay tắt (xem `financial-features.md` §3).
2. Điền **Tính năng tài chính** (`Chính sách và chương trình → Nội dung ứng dụng → Tính năng tài chính`). Không hoàn thành mục này thì từ 30/10/2025 **không thể cập nhật app** (kể cả app không có tính năng tài chính).
3. Điền **An toàn dữ liệu** + **Xoá dữ liệu**: URL công khai đã có — `https://dealgo.laptrinhapp.com/account-deletion` (xem §3 B1).
4. Điền **App access** bằng tài khoản review (`appreview@dealgo.laptrinhapp.com`), kèm mật khẩu trong hộp bảo mật của Play Console.
5. Điền **Content rating**, **Target audience** (18+), **Ads = No**, **Payments** (dịch vụ vật lý, không dùng Play Billing).
6. Dán **Review notes** (`review-notes.md`) vào ô "Notes for review team".
7. Kiểm tra checklist `compliance-checks.md`; xử lý hết ACTION.
8. Build **AAB** đã ký, upload lên track **Internal testing** trước, cài từ Play và chạy lại kịch bản review.
9. Chỉ khi Internal testing PASS mới promote lên Closed/Production.

## 3. Chặn nộp hiện tại (phải xử lý)

| # | Vấn đề | Trạng thái | Xử lý |
|---|---|---|---|
| B1 | Chưa có **URL công khai để yêu cầu xoá tài khoản** (Play bắt buộc nếu app cho tạo tài khoản) | **DONE** (04/11/2026) | Trang `website/app/account-deletion/` (vi + ?lang=en, không cần đăng nhập) mô tả dữ liệu xoá/giữ, thời hạn, điều kiện chặn; form gửi phiếu hỗ trợ qua `POST /api/public/support`. URL: `https://dealgo.laptrinhapp.com/account-deletion` — dùng domain đã khai cho `/privacy`; đối chiếu trước khi Submit |
| B2 | Manifest Android khai `READ_MEDIA_IMAGES` nhưng app chỉ chọn ảnh qua picker | **DONE** (04/11/2026) | Đã bỏ `READ_MEDIA_IMAGES` + `READ_EXTERNAL_STORAGE` khỏi `mobile/android/app/src/main/AndroidManifest.xml`; bỏ `Permission.photos.request()` khỏi luồng chọn avatar (SAF/PHPicker không cần quyền). Merged release manifest không còn quyền ảnh; `READ_EXTERNAL_STORAGE` còn lại do `camera_android_camerax` khai kèm `WRITE_EXTERNAL_STORAGE` (`maxSdkVersion 28`), không thuộc khai báo quyền ảnh của Play |
| B3 | `DRIVER_TOP_UP_ENABLED=false` nhưng thẻ "Nạp phí" vẫn hiện ở màn Thu nhập tài xế | **DONE** (04/11/2026) | `driver_earnings_page.dart` chỉ hiện thẻ khi `DriverCredit.enabled` (server trả từ `DRIVER_TOP_UP_ENABLED`); trang credit đã có nhánh thông báo khi tắt |
| B4 | Reviewer mở trang nạp phí sẽ nhận `DRIVER_TOP_UP_PROVIDER_NOT_CONFIGURED` nếu chưa có `PAYOS_*` | **ACTION** | Cấu hình payOS production + webhook, **hoặc** để `DRIVER_TOP_UP_ENABLED=false` (nay thẻ đã ẩn) và ghi rõ trong review notes |
| B5 | Chưa xác nhận **target API level** theo yêu cầu Play hiện hành | **ACTION** | Kiểm tra Play Console cảnh báo; build bằng Flutter hiện tại (3.47.x) rồi xem "Target SDK" trong App bundle explorer |

## 4. Trang xoá tài khoản công khai (B1)

- URL: `https://dealgo.laptrinhapp.com/account-deletion` — cùng domain đã khai cho `/privacy`.
- Nội dung: cách xoá trong app, form yêu cầu khi đã gỡ app, dữ liệu bị xoá, dữ liệu giữ lại, thời hạn (mặc định 7 ngày, cấu hình 0–90), điều kiện chặn, huỷ/khôi phục, kênh liên hệ.
- Form tạo phiếu hỗ trợ (`category=ACCOUNT`) → hiện ở **Admin → Hỗ trợ**; không cần đăng nhập, không cần tải app.
- Test trước khi Submit: mở ẩn danh, thử `?lang=en`, gửi 1 yêu cầu và kiểm tra phiếu trong Admin.
- Nguồn sự thật cho nội dung xoá/giữ: `backend/src/modules/account-deletion/account-deletion-prisma.repository.ts` (purge) và `platform-settings.seed.ts` (`ACCOUNT_DELETION_GRACE_DAYS=7`).

## 5. Nguyên tắc nội dung

- Không quảng cáo "Ví DealGo", "ví điện tử", "nạp/rút ví" cho khách. Code stub `DEALGO_WALLET` đã được xoá; store listing phải khớp.
- Tài xế có **khoản trả trước phí nền tảng** (closed-loop), không phải ví: không chuyển cho người khác, không rút tiền mặt, không mua hàng, không sinh lãi.
- Mọi câu trong mô tả app phải mở được trong bản nộp. Đừng mô tả tính năng đang tắt.
- Không nhắc "Google Play Billing" trong app; chuyến xe/đồ ăn là **dịch vụ vật lý**, được dùng cổng thanh toán ngoài.
