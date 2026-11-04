# Khai báo "Tính năng tài chính" trên Google Play Console

> Trạng thái: **DRAFT — chờ Legal xác nhận** (`ASM` trong `docs/02-domain/driver-credit-topup.md`).
> Áp dụng cho app `dealgo.nguyengoctien.com` (Flutter, một app ba vai trò).
> Cập nhật: 11/2026.

## 0. Kết luận (TL;DR)

Trong **Chính sách và chương trình → Nội dung ứng dụng → Tính năng tài chính**:

1. Chọn **duy nhất** ô:
   - **`Other` (Khác)** — không chọn ô nào khác.
2. Dán mô tả ở §4 vào ô **"Describe the other financial features that the app provides"** (bắt buộc khi chọn `Other`).
3. **Không** chọn `Mobile payments and digital wallets`.
4. **Không** chọn `My app doesn't provide any financial features` khi bản nộp còn màn hình số dư / nạp phí / hoàn tiền của tài xế.
5. Lưu và kiểm tra `Policy status` báo **không có vấn đề**.

> Đây là khai báo **theo artifact được upload**, không phải theo ý định kinh doanh. Nếu bản nộp có màn hình tài chính thì phải khai; nếu không có thì khai `none`.

## 1. Vì sao phải khai

Từ **30/10/2025**, Google bắt buộc **mọi app** hoàn thành khai báo này — kể cả app không có tính năng tài chính. Chưa hoàn thành thì **không thể phát hành bản cập nhật** (app update bị chặn), không chỉ bị từ chối review.

Form nằm ở:

```
Play Console → Chính sách và chương trình (Policy and programs)
             → Nội dung ứng dụng (App content)
             → Tính năng tài chính (Financial features)
             → Bắt đầu (Start)
```

Các lựa chọn của form (nguồn: Play Console Help + Policy Declarations API):

| Nhóm | Lựa chọn |
|---|---|
| Banking and loans | Personal loan direct lender, Loan facilitator, Payday loans, Banking, Line of credit, Earned wage advances, Microfinance banking |
| Payments and transfers | **Mobile payments and digital wallets**, Money transfer and wire services |
| Purchase agreements | Rewards/points/incentives, Buy now pay later |
| Trading and funds | Crypto wallet, Crypto exchange, Tokenized digital asset (NFT), Stock trading, Crowdfunding |
| Support services | Credit monitoring, Financial advice, Insurance, **Other** |
| Không có | **My app doesn't provide any financial features** |

`Other` mở thêm một ô text bắt buộc: **"Describe the other financial features that the app provides"** (`POLICY_QUESTION_ID_FINANCIAL_PRODUCT_TYPE_OTHER_SPECIFY`).

## 2. App đang có gì (đối chiếu code)

| Thành phần | Có trong bản nộp? | Bằng chứng |
|---|---|---|
| Ví/số dư cho **khách** | **Không** — stub `DEALGO_WALLET` đã xoá khỏi catalog và admin | `backend/src/modules/payment/checkout/payment-method.catalog.ts`, `payment-method-registry.ts` |
| Khách trả tiền chuyến/đồ ăn | Tiền mặt hoặc cổng thanh toán ngoài (MoMo/VNPAY/thẻ… tuỳ cấu hình) | `payment-method.catalog.ts`; Payments policy cho phép vì là **dịch vụ vật lý** |
| **Số dư trả trước phí nền tảng của tài xế** | **Có** | `DriverTopUp`, `DriverCreditApplication`, `driver.credit_liability` |
| Tài xế nạp phí qua PSP | **Có** (payOS mặc định, VNPAY) | `driver-credit.service.ts`, `payos.adapter.ts` |
| Tài xế xem số dư/công nợ/lịch sử | **Có** | `mobile/lib/features/driver_credit/`, thẻ ở `driver_earnings_page.dart`; UI ghi rõ “Chỉ dùng để trừ phí nền tảng. Không rút và không chuyển cho người khác.” (`app_vi.arb`) |
| Hoàn phần chưa dùng | **Có**, Ops chuyển khoản thủ công, ghi `refundBankRef` | `driver-credit.service.ts` (`refund`), `ops-driver-credit.controller.ts` |
| Chuyển tiền giữa người dùng | **Không** | không có API/UI |
| Rút tiền mặt tự phục vụ | **Không** | không có API/UI; hoàn tiền do Ops |
| Dùng số dư để mua hàng/dịch vụ khác | **Không** | chỉ cấn trừ `job_earnings.feeVnd` |
| Cho vay / BNPL / hạn mức tín dụng | **Không** | công nợ phát sinh từ phí job đã hoàn thành, không lãi, không trả góp |
| Crypto/NFT/chứng khoán/bảo hiểm | **Không** | — |

Bản chất: **tài khoản trả trước phí dịch vụ nội bộ, closed-loop**. Tiền vào tài khoản merchant qua PSP, chỉ ghi giảm nghĩa vụ phí của chính tài xế đó; không phải phương tiện thanh toán cho bên thứ ba.

## 3. Chọn ô nào — theo trạng thái bản nộp

| Bản nộp có… | Khai báo | Ghi chú |
|---|---|---|
| Thẻ/số dư/nạp/hoàn tiền tài xế **hiển thị được** (kể cả `DRIVER_TOP_UP_ENABLED=false`) | **`Other`** + mô tả §4 | Khuyến nghị hiện tại. Reviewer mở được màn hình tài chính thì phải khai |
| Không còn **bất kỳ** UI/route/API nào về số dư, nạp, hoàn tiền (đã ẩn hẳn khỏi bản nộp) | `My app doesn't provide any financial features` | Chỉ đúng khi đã ẩn thật, không chỉ tắt cờ server |
| Có ví cho khách, ví lưu giá trị dùng để trả cho merchant/người khác | `Mobile payments and digital wallets` + giấy phép theo NĐ 52/2024 | **Không** áp dụng hiện tại; chỉ dùng khi mở ví khách thật |
| Có cho vay/trả sau | `Personal loan …` hoặc `Buy now, pay later` + tài liệu | **Không** áp dụng |

**Khuyến nghị:** chọn `Other` ngay từ bản nộp đầu tiên. Khi nào Legal và merchant account xong, bật nạp tiền cũng **không phải khai lại** vì bản chất không đổi. Ngược lại, nếu bản nộp đầu khai `none` rồi bật nạp tiền mà không khai lại, đó là **khai sai** — rủi ro cao hơn.

### Vì sao không chọn `Mobile payments and digital wallets`

- Ô này dành cho app **cung cấp dịch vụ ví/thanh toán** cho người dùng: lưu tiền, nạp/rút, chuyển tiền, trả cho bên thứ ba, ví điện tử.
- DealGo **không** giữ tiền hộ khách, **không** mở ví khách, **không** cho tài xế chuyển/rút số dư. Số dư tài xế chỉ cấn trừ phí phải trả cho DealGo.
- Chọn ô này có thể khiến Google xếp app vào diện **dịch vụ tài chính/trung gian thanh toán** và yêu cầu giấy phép. Đó là khai **sai bản chất** và tạo rủi ro pháp lý không cần thiết.
- Việc app **chấp nhận** MoMo/VNPAY/thẻ làm phương thức thanh toán không biến app thành ví. Đó là merchant dùng PSP.

### Vì sao không chọn `none`

- Reviewer mở **Thu nhập tài xế** sẽ thấy thẻ "Phí nền tảng" / số dư / lịch sử nạp.
- Màn hình nạp tiền và hoàn tiền là **tính năng tài chính** theo nghĩa thông thường, dù closed-loop.
- Khai `none` khi vẫn còn màn hình đó dễ bị coi là **khai báo không trung thực** (Deceptive behavior / Financial Services), dẫn tới reject hoặc đình chỉ.

### Vì sao không phải `Buy now, pay later` hay `Line of credit`

- Công nợ phí phát sinh **sau** khi job đã hoàn thành; DealGo không cấp hạn mức, không giải ngân, không tính lãi/phí tài chính, không có lịch trả góp.
- Việc dispatch chặn nhận job khi vượt `DRIVER_DEBT_LIMIT_VND` là biện pháp vận hành, không phải sản phẩm tín dụng.
- Nếu sau này cho tài xế **trả chậm có lãi/phí** hoặc chia nhỏ kỳ thanh toán, phải khai lại và xem xét `Buy now, pay later`/tín dụng.

## 4. Câu trả lời dán vào ô `Other`

### 4.1. Tiếng Việt (483 ký tự — dùng nếu Console chọn ngôn ngữ Việt)

```
Tài khoản trả trước phí nền tảng dạng đóng cho tài xế trong ứng dụng đặt xe và giao đồ ăn. Tài xế nạp khoản phí còn nợ qua đối tác cổng thanh toán Việt Nam (payOS/VNPAY), xem số dư; DealGo có thể hoàn phần chưa dùng qua chuyển khoản. Đây không phải tiền gửi ngân hàng, tiền điện tử hay ví đa năng: không chuyển cho người khác, không rút tiền mặt, không mua hàng. Khách trả tiền mặt hoặc qua cổng thanh toán. Không cho vay, không cấp hạn mức tín dụng, không chuyển tiền, không crypto.
```

### 4.2. English (473 ký tự — dùng nếu Console chọn English hoặc reviewer cần bản tiếng Anh)

```
Closed-loop prepaid platform-fee account for drivers on a ride-hailing and food-delivery app. Drivers top up platform fees they owe through a Vietnamese payment gateway partner (payOS/VNPAY), see the balance, and DealGo operations may refund unused credit. It is not a bank deposit, e-money, or general-purpose wallet: no transfers to other users, no cash-out, no purchases. Customers pay in cash or via a payment gateway. No loans, credit lines, money transfer, or crypto.
```

> Nếu ô text giới hạn ngắn hơn 500 ký tự, cắt phần cuối "No loans…" trước; **không** bỏ câu "not a bank deposit, e-money, or general-purpose wallet".

> **Nếu Google chủ động phân loại đây là “closed wallet”:** không tự đổi sang `Mobile payments and digital wallets` ngay. Trả lời theo template §5, nhấn mạnh không có chức năng nạp/rút tự do, không chuyển tiền, không thanh toán cho bên thứ ba. Chỉ đổi khai báo khi Google yêu cầu rõ ràng hoặc khi Legal xác nhận cần xử lý như ví điện tử.


### 4.3. Bản rút gọn (nếu ô text rất ngắn)

VI (242 ký tự):

```
Tài khoản trả trước phí nền tảng dạng đóng cho tài xế: nạp qua cổng thanh toán Việt Nam, số dư chỉ cấn trừ phí của chính tài xế, Ops có thể hoàn phần chưa dùng. Không phải ví, tiền điện tử, tiền gửi, cho vay, tín dụng, chuyển tiền hay crypto.
```

EN (248 ký tự):

```
Closed-loop prepaid platform-fee account for drivers: top-ups via a Vietnamese payment gateway, balance applied only to that driver's platform fees, refundable by Operations. Not a wallet, e-money, deposit, loan, credit, transfer or crypto service.
```


## 5. Nếu Google hỏi lại (template trả lời)

Chuẩn bị sẵn trong `Policy status` hoặc email:

```
Dear Google Play Review Team,

DealGo is a ride-hailing and food-delivery platform in Vietnam (one app: customer,
driver, merchant). The only stored balance is a closed-loop prepaid platform-fee
account for drivers:

- Drivers owe DealGo a platform fee on completed cash jobs (job_earnings.feeVnd).
- A driver may prepay that fee through our payment gateway partner (payOS or VNPAY).
  Funds settle directly to DealGo's merchant bank account.
- The prepaid amount is applied only against that driver's own future platform fees.
- Unused credit may be refunded by DealGo Operations via bank transfer to the
  verified source account, with a recorded bank reference.
- The balance cannot be transferred to another user, withdrawn by the driver,
  used to buy goods/services, or used to pay for rides. It pays no interest.
- There is no customer wallet, no stored value for customers, no P2P transfer,
  no lending, no credit line, no BNPL, and no crypto.

The app accepts customer payments for transportation and food delivery in cash or
through third-party payment methods; those are physical services and are not
Google Play Billing digital goods.

We have declared this as "Other" because it is an operator-managed, closed-loop
service-fee settlement account, not a mobile wallet or e-money product.

Supporting material available on request:
- Terms of Service (driver fee section): <URL>
- Driver fee/top-up policy with refund rules: <URL>
- Privacy Policy: <URL>
- Screenshots/video of the driver flow: <URL>
- Payment partner agreement / merchant account: <redacted, on request>

Regards,
DealGo
```

Điền URL thật trước khi gửi; không gửi thông tin merchant/khóa bí mật.

## 6. Hồ sơ nên có sẵn

| Tài liệu | Mục đích | Trạng thái |
|---|---|---|
| Điều khoản dịch vụ có mục phí nền tảng, nạp trước, hoàn tiền | Chứng minh closed-loop, có điều kiện hoàn | **ACTION** — kiểm tra `website/app/terms` đã có mục này chưa |
| Chính sách hoàn tiền tài xế | Google có thể hỏi | **ACTION** — thêm vào Terms/Support |
| Ảnh/video luồng tài xế: số dư → nạp → lịch sử → hoàn | Reviewer hiểu flow | **ACTION** — quay trên build review |
| Hợp đồng/merchant account payOS | Chứng minh tiền đi thẳng merchant, không phải ví | Lưu nội bộ, chỉ gửi khi được yêu cầu |
| Xác nhận của Legal về NĐ 52/2024 | Chặn rủi ro “ví điện tử không phép” | **ACTION** — đang là `ASM` |

## 7. Ranh giới pháp lý (Việt Nam)

- **Nghị định 52/2024/NĐ-CP** (15/5/2024, hiệu lực 1/7/2024) về thanh toán không dùng tiền mặt: ví điện tử là phương tiện lưu trữ tiền điện tử, phải do ngân hàng/tổ chức trung gian thanh toán được NHNN cấp phép cung ứng; dịch vụ ví gồm nạp, rút và thực hiện giao dịch thanh toán.
- **Thông tư 40/2024/TT-NHNN** (17/7/2024) hướng dẫn hoạt động cung ứng dịch vụ trung gian thanh toán.
- Lập luận của DealGo: số dư tài xế **không** phải phương tiện thanh toán độc lập; không nạp/rút tự do, không chuyển tiền, không thanh toán cho bên thứ ba; chỉ cấn trừ nghĩa vụ phí nội bộ. Vì vậy không thuộc dịch vụ ví điện tử.
- Đây là **kết luận kỹ thuật/pháp lý dự kiến**, **chưa phải ý kiến pháp lý**. Phải có Legal xác nhận trước khi bật `DRIVER_TOP_UP_ENABLED=true` trên production. Xem `docs/02-domain/driver-credit-topup.md` §2.
- Nếu Legal kết luận cần giấy phép trung gian thanh toán: **không** bật tính năng, khai `none`, ẩn UI, và chỉ mở sau khi có giấy phép/đối tác được phép.

## 8. Khi nào phải khai lại

Khai lại ngay khi có một trong các thay đổi sau (không chờ release định kỳ):

- Thêm **ví cho khách** hoặc bất kỳ số dư lưu giá trị nào dùng để thanh toán.
- Cho phép **chuyển số dư** giữa người dùng, rút tiền mặt, hoặc dùng số dư mua hàng/dịch vụ.
- Thêm **trả sau/trả góp/phí tài chính/lãi**.
- Thêm crypto, NFT, chứng khoán, bảo hiểm, cho vay, chuyển tiền.
- Đổi bản chất từ “phí nền tảng” sang “dịch vụ thanh toán” cho bên thứ ba.
- Tách app tài xế thành app riêng: **mỗi app khai riêng** theo artifact của app đó.

## 9. Sai lầm thường gặp

| Sai lầm | Hậu quả |
|---|---|
| Chọn `none` vì “chỉ là phí nội bộ” nhưng UI vẫn hiện | Reviewer thấy mâu thuẫn → reject/đình chỉ |
| Chọn `Mobile payments and digital wallets` cho “an toàn” | Bị xếp vào diện dịch vụ tài chính, có thể bị hỏi giấy phép; mô tả sai |
| Dùng chữ “ví”, “wallet”, “nạp/rút” trong store listing | Store listing không khớp chức năng → Deceptive behavior |
| Khai theo môi trường dev/test nhưng upload build khác | Khai báo không đúng artifact |
| Bật nạp tiền sau khi đã khai `none` mà không cập nhật | Khai sai; rủi ro enforcement |
| Để reviewer gặp màn hình 503 vì thiếu `PAYOS_*` | Reviewer không kiểm tra được → reject vì App access/không đầy đủ |

## 10. Liên quan trong repo

- `docs/02-domain/driver-credit-topup.md` — mô hình, phạm vi, ranh giới pháp lý.
- `docs/09-operations/secrets-and-env-catalog.md` — biến môi trường payOS/VNPAY.
- `docs/release/play-store/data-safety.md` — khai `Financial info` tương ứng.
- `docs/release/play-store/review-notes.md` — kịch bản review tài xế.
