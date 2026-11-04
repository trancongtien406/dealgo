# Review notes — Google Play

> Dán phần **English** vào `App content → App access → Instructions` hoặc ô "Notes for review team" khi Submit.
> Phần **Vận hành** chỉ dùng nội bộ, không dán vào Play.

## 1. English — paste into Play Console

```
Thank you for reviewing DealGo.

WHAT THE APP DOES
DealGo is a ride-hailing and food-delivery platform in Vietnam. One app serves three roles:
Customer, Driver and Merchant. The server is the source of truth for fares, assignments,
order status and balances.

TEST ACCOUNT (all three roles)
Email: appreview@dealgo.laptrinhapp.com
Password: <the password stored in the App access credentials section>

Sign in with email + password. The account is pre-verified; no OTP is required.
If you sign in with a phone number instead, use the OTP shown in the App access notes.

CUSTOMER — RIDE
1. Open "Đặt xe" (Book a ride).
2. Pick a pickup and a drop-off on the map; choose motorbike or car.
3. The app shows an upfront fare estimate. Tap to book.
4. Choose "Tiền mặt" (cash) to avoid a real charge. The seeded driver may be offline;
   go to the Driver role and switch online if you want the full assignment flow.

CUSTOMER — FOOD
1. Open "Đồ ăn" (Food), choose the seeded store near you.
2. Add an item, open the cart and check out.
3. Choose cash. You can follow the order status; the seeded store accepts it.

DRIVER
1. Use the role switcher and open the Driver workspace.
2. Go online, then open "Thu nhập" (Earnings).
3. The "Phí nền tảng" card opens the prepaid platform-fee account:
   balance, fee debt, top-up history and status.
4. Top-up (if enabled in this build): choose an amount and open the payment link.
   The payment is processed by a Vietnamese payment gateway partner (payOS/VNPAY).
   You do NOT need to complete a real bank transfer to review the screens; a video of
   the full flow is available at <VIDEO_URL>.

ABOUT THE DRIVER BALANCE (important)
This is a closed-loop prepaid platform-fee account, not a wallet:
- Drivers owe DealGo a platform fee on completed cash jobs.
- A driver may prepay that fee; the credit is applied only to that driver's future fees.
- Unused credit may be refunded by DealGo Operations via bank transfer to the source account.
- The balance cannot be transferred to another user, withdrawn by the driver, used to buy
  goods or services, or used to pay for a ride. It pays no interest.
- There is no customer wallet, no stored value for customers, no P2P transfer, no lending,
  no credit line, no BNPL and no crypto.
This is declared as "Other" in the Financial features declaration.

MERCHANT
1. Use the role switcher and open the Merchant workspace.
2. The seeded store has menu items, orders and reviews.

ACCOUNT DELETION
Account → Delete account (also under Security). The request is confirmed in-app.
If the app is already uninstalled, the public web resource
`https://dealgo.laptrinhapp.com/account-deletion` (no sign-in required) explains what is deleted and
what is retained, and opens a support request so the team can verify and delete the account.
The same page is linked from the Data safety → Data deletion URL.

PERMISSIONS
- Location: pickup/drop-off, nearby stores, live trip/order tracking. Foreground only;
  the app does not request background location.
- Camera: KYC documents and chat images. Photos come from the system picker, which grants
  access to the chosen file only; the app holds no photo-library permission.
- Microphone: in-app voice calls between the customer and the assigned driver. Audio is
  relayed in real time and is never recorded.
- Notifications: new job/order and trip updates.
- Bluetooth: audio routing for headsets during a call.

PAYMENTS
Rides and food are physical services, so the app does not use Google Play Billing.
Customers pay cash or through a third-party payment method. No digital goods are sold.

ADS AND DATA
No ads. No data is sold. Crash reporting is Sentry with sendDefaultPii=false and request
data scrubbed; push uses Firebase Cloud Messaging.

SERVICE AREA
Vietnam. Test data is seeded for the review account; no real customer data is used.

Contact: support@dealgo.laptrinhapp.com
```

## 2. Vận hành — chuẩn bị môi trường review

| Việc | Cách làm |
|---|---|
| Tạo tài khoản review | `APP_REVIEW_PASSWORD='<12+ ký tự>' npm run seed:app-review` (backend) |
| Bật đăng nhập review | Platform setting `APP_REVIEW_LOGIN_ENABLED=true`, `APP_REVIEW_EMAIL=appreview@dealgo.laptrinhapp.com` |
| OTP cố định (nếu dùng) | `APP_REVIEW_OTP_CODE` 6 chữ số; ghi vào App access notes |
| Tài xế online | Đăng nhập tài khoản review → Driver → Online; seed để offline mặc định |
| KYC tài xế | Seed đặt `PartnerApplication` APPROVED; kiểm tra lại màn hình tài xế |
| Nạp phí | `DRIVER_TOP_UP_ENABLED=true` + `PAYOS_CLIENT_ID/API_KEY/CHECKSUM_KEY` + `PAYMENT_PUBLIC_BASE_URL` + webhook production |
| Nếu chưa có payOS | Đặt `DRIVER_TOP_UP_ENABLED=false`: thẻ "Phí nền tảng" ở màn Thu nhập tự ẩn, trang credit hiện thông báo thay vì nút nạp; ghi rõ trong review notes |
| Trang xoá tài khoản | Mở `https://dealgo.laptrinhapp.com/account-deletion` ẩn danh, thử `?lang=en`, gửi 1 yêu cầu và kiểm tra phiếu ở Admin → Hỗ trợ |
| Video luồng nạp | Quay trên build review: số dư → tạo lệnh → QR/redirect → IPN → lịch sử → hoàn tiền |
| Tài khoản không bị xoá | Không xoá/đổi mật khẩu trong thời gian review; nếu reviewer xoá, chạy lại seed |

## 3. Kịch bản kiểm tra trước khi nộp (chạy trên bản cài từ Play)

- [ ] Đăng nhập email + mật khẩu, không cần OTP.
- [ ] Đặt xe máy: thấy giá trước khi đặt, chọn tiền mặt, theo dõi trạng thái.
- [ ] Đặt xe ô tô: giá và loại xe hiển thị đúng.
- [ ] Gọi đồ ăn: thêm món, áp ưu đãi, đặt, theo dõi.
- [ ] Driver: online, nhận job, xem thu nhập, mở thẻ phí.
- [ ] Top-up: tạo lệnh, mở link, kiểm tra trạng thái; nếu không có PSP, màn hình phải giải thích rõ chứ không crash.
- [ ] Merchant: xem đơn, đổi trạng thái, sửa menu.
- [ ] Xoá tài khoản: mở được màn hình, đọc được hậu quả, không lỗi.
- [ ] Trang web `/account-deletion`: mở ẩn danh, không login, gửi được yêu cầu.
- [ ] Từ chối quyền vị trí/camera/micro: app vẫn dùng được phần còn lại, có giải thích.
- [ ] Không có màn hình debug, giá test, dữ liệu cá nhân thật.

## 4. Sau khi được duyệt

- Giữ tài khoản review thêm ít nhất 30 ngày (Google có thể kiểm tra lại).
- Xoay mật khẩu review sau khi hết thời gian; không tái sử dụng.
- Chạy `npm run seed:app-review:cleanup` khi không cần nữa.
- Nếu bật/tắt tính năng tài chính: cập nhật khai báo **trước** khi release.
