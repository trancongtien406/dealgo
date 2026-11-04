# DealGo — Driver Prepaid Credit (Top-up & Fee Offset)

> Quyết định: `DEC-PROD-093` (OWNER_REQUESTED, 2026-11-03). Trạng thái tài liệu: `DRAFT`.
> Phạm vi: tài xế nộp trước tiền để cấn trừ **phí nền tảng**; đây **không** phải ví điện tử.

## 1. Mô hình

Tài xế giữ tiền mặt của khách (COD) và nợ DealGo phí nền tảng đã chốt ở mỗi job (`job_earnings.feeVnd`), cộng các khoản điều chỉnh (huỷ, không xuất hiện, phạt). `DEC-PROD-093` thêm một lựa chọn: tài xế **nộp trước** để số dư tạm ứng tự động trừ vào phí, thay vì để công nợ tích luỹ tới hạn mức chặn nhận việc.

| Khái niệm | Ý nghĩa |
|---|---|
| `DriverTopUp` | Một lệnh nạp tiền đã xác minh với PSP. Số tiền còn dùng được nằm ở `remainingVnd`. |
| `DriverCreditApplication` | Một lần trừ số dư vào một kỳ công nợ phí (FIFO theo lệnh nạp cũ nhất). |
| `driver.credit_liability` | Tài khoản ledger ghi nghĩa vụ của DealGo với tài xế (đã nhận tiền, chưa cấn trừ hết). |
| `driverObligationOf` | Tổng nghĩa vụ phí **trước** khi cấn trừ số dư, dùng để phân bổ credit khi settlement. |

Số dư hiển thị cho tài xế: `amountVnd = feesVnd + adjustmentsVnd − creditVnd`.

- `amountVnd > 0`: tài xế còn nợ DealGo; vượt `DRIVER_DEBT_LIMIT_VND` thì dispatch chặn việc mới.
- `amountVnd == 0`: không nợ, không dư.
- Số dư dư (`creditVnd`) không bao giờ được trả thành “ví”: chỉ giảm phí phát sinh sau đó.

## 2. Ranh giới pháp lý — bắt buộc

- Không rút tiền, không chuyển cho tài xế khác hoặc người dùng khác, không dùng để thanh toán cước chuyến, không sinh lãi.
- Không phải phương tiện thanh toán độc lập ⇒ nằm ngoài phạm vi ví điện tử của Nghị định 52/2024/NĐ-CP theo cách DealGo đang triển khai. Kết luận này vẫn là **giả định (`ASM`)**, cần Legal xác nhận trước khi mở `DRIVER_TOP_UP_ENABLED=true` trên production.
- Tiền nạp đi thẳng vào tài khoản ngân hàng merchant (A2A qua payOS) — DealGo không giữ hộ tiền của bên thứ ba.

## 3. Luồng nạp tiền

1. Tài xế mở **Thu nhập → Nạp phí** (`GET /v1/driver/credit`).
2. Chọn số tiền trong band `DRIVER_TOP_UP_MIN_VND..DRIVER_TOP_UP_MAX_VND`; server kiểm tra thêm:
   - `DRIVER_TOP_UP_ENABLED` = true, role `DRIVER` đang `ACTIVE`, KYC `APPROVED`;
   - chưa có lệnh `PENDING` còn hạn (một lệnh mỗi lúc);
   - tổng đã trả trong ngày (giờ VN) + số tiền ≤ `DRIVER_TOP_UP_DAILY_LIMIT_VND`;
   - `creditVnd + số tiền ≤ DRIVER_CREDIT_MAX_VND`.
3. `POST /v1/driver/credit/top-ups` (idempotency qua header `Idempotency-Key`) tạo `DriverTopUp` rồi gọi PSP (`payOS` mặc định, hoặc VNPAY khi `DRIVER_TOP_UP_PROVIDER=vnpay`). Response trả `checkoutUrl` + `qrCode`.
4. App mở trang thanh toán/QR. **IPN có chữ ký là nguồn sự thật duy nhất**; trang return trên trình duyệt chỉ hiển thị trạng thái.
5. IPN hợp lệ + đúng `providerRef` + đúng `amountVnd` ⇒ `PENDING → PAID`, `remainingVnd = amountVnd`, ghi journal `DRIVER_CREDIT_TOP_UP_CAPTURED`.
6. IPN lỗi/huỷ ⇒ `FAILED` (không ghi ledger). Hết hạn `DRIVER_TOP_UP_EXPIRE_MINUTES` ⇒ `EXPIRED` khi reconcile.
7. IPN bị lỡ: worker `driver-top-up-reconcile` (và `POST /v1/ops/driver-credit/reconcile`) query PSP; chỉ capture khi PSP báo `PAID` và số tiền khớp.

Số đơn gửi PSP là số nguyên tăng dần, bắt đầu từ `1_000_000_000` (`driver_top_ups_orderCode_seq`), để tránh trùng với namespace của checkout job.

## 4. Cấn trừ khi settlement phí

Khi Ops chốt kỳ công nợ (hoặc account closure):

1. Tính `obligation = feesVnd + adjustmentsVnd` (chưa trừ credit).
2. Lấy các `DriverTopUp` còn `remainingVnd > 0`, cũ nhất trước; trừ dần tới khi hết obligation hoặc hết credit.
3. Mỗi lần trừ: tạo `DriverCreditApplication(topUpId, settlementId, amountVnd)`, `remainingVnd -= amount`, `consumedVnd += amount`, `DriverFeeSettlement.creditAppliedVnd += amount`, ghi `DRIVER_CREDIT_APPLIED_TO_FEE`.
4. Phần còn lại (`amountVnd = obligation − creditApplied`) là tiền tài xế nộp trực tiếp cho DealGo như hiện tại (Ops ghi nhận, audit `DRIVER_BALANCE_PAYMENT`).

Server chỉ cấn trừ **khi chốt kỳ** — không trừ lẻ theo từng job — để một bút toán kỳ khớp đúng số liệu Finance đã duyệt. Điểm vào hiện tại: `POST /v1/ops/users/:id/fee-settlements` (quyền `settlements.write`), trả về `amountVnd` (tiền mặt còn phải thu) và `creditAppliedVnd` (phần đã trừ từ số dư).

## 5. Ledger

| Event | Debit | Credit |
|---|---|---|
| `DRIVER_CREDIT_TOP_UP_CAPTURED` | `psp.clearing_receivable` | `driver.credit_liability` |
| `DRIVER_CREDIT_APPLIED_TO_FEE` | `driver.credit_liability` | `sandbox.fee.driver_receivable` |
| `DRIVER_CREDIT_REFUNDED` | `driver.credit_liability` | `psp.clearing_receivable` |

Bất biến:

- Tổng `remainingVnd` của một tài xế = số dư tài khoản `driver.credit_liability` của họ.
- `remainingVnd + consumedVnd + refundedVnd = amountVnd` cho mọi lệnh nạp ở trạng thái `PAID/REFUNDED`.
- Không có journal nào ghi có `driver.credit_liability` ngoài capture/hoàn tiền từ PSP.

## 6. Hoàn tiền (Ops, thủ công)

- Chỉ Ops thực hiện, khi chấm dứt hợp đồng hoặc đóng tài khoản; tài xế không tự yêu cầu trong app.
- `POST /v1/ops/driver-credit/top-ups/:id/refund` với `reason` + `bankRef` (mã giao dịch chuyển khoản), quyền `refunds.write`.
- Chỉ hoàn phần `remainingVnd` (phần đã cấn trừ phí là doanh thu, không hoàn). Audit `DRIVER_CREDIT_REFUND`.
- payOS không có API payout ⇒ chuyển khoản ngân hàng 2 bước: Ops chuyển tiền, sau đó ghi nhận trong Admin. Không có “refund tự động”.

## 7. API

| Route | Quyền | Mô tả |
|---|---|---|
| `GET /v1/driver/credit` | driver session | Số dư, công nợ, hạn mức, lệnh đang chờ, 10 lệnh gần nhất |
| `GET /v1/driver/credit/top-ups` | driver session | Danh sách lệnh nạp |
| `GET /v1/driver/credit/top-ups/:id` | driver session | Một lệnh nạp (poll sau khi quay lại từ PSP) |
| `POST /v1/driver/credit/top-ups` | driver session (5/phút) | Tạo lệnh nạp; `Idempotency-Key` tuỳ chọn |
| `POST /v1/driver/credit/top-ups/:id/cancel` | driver session | Huỷ lệnh còn `PENDING` |
| `GET /v1/payments/driver-credit/return/:provider` | public | Trang return hiển thị trạng thái (không cộng tiền) |
| `POST/GET /v1/payments/ipn/:provider` | public, chữ ký | IPN dùng chung; `payos` và VNPAY `DGCT*` được định tuyến vào module này |
| `GET /v1/ops/driver-credit/top-ups` | `drivers.read` | Danh sách toàn hệ thống (kèm tên/SĐT tài xế, tối đa 100) |
| `GET /v1/ops/driver-credit/top-ups/:id` | `drivers.read` | Một lệnh nạp kèm `providerRef`, `providerTransId`, lý do lỗi, hoàn tiền |
| `GET /v1/ops/driver-credit/summary` | `settlements.read` | Tổng `PENDING`, đã trả trong ngày, đã hoàn, tạm ứng còn lại |
| `POST /v1/ops/driver-credit/top-ups/:id/reconcile` | `settlements.write` | Đối soát một lệnh |
| `POST /v1/ops/driver-credit/reconcile` | `settlements.write` | Quét batch lệnh `PENDING` |
| `POST /v1/ops/driver-credit/top-ups/:id/refund` | `refunds.write` | Ghi nhận hoàn tiền thủ công |
| `POST /v1/ops/users/:id/fee-settlements` | `settlements.write` | Chốt công nợ phí; áp số dư tạm ứng FIFO và trả `creditAppliedVnd` |

### 7.1 Realtime + deep link (app tài xế)

- Lệnh nạp chuyển trạng thái (`PAID`, `FAILED`, `EXPIRED`, `CANCELLED`, `REFUNDED`) được phát qua `DriverCreditStatusBus`; bridge đẩy sự kiện `driverCreditStatus` vào room riêng `user:{driverId}`.
- App đang mở **Số dư tạm ứng** cập nhật ngay khi nhận hint; sheet QR dùng hint làm tín hiệu đóng/đổi trạng thái, polling chỉ là fallback khi socket rớt.
- Deep link `dealgo://payment-return?kind=driver-credit&topUpId=<id>` được router chuyển thành `/driver/credit?topUpId=<id>` và mở lại đúng lệnh nạp.
- Cảnh báo ở tab **Thu nhập** khi công nợ đạt ≥80% hạn mức hoặc đã bị chặn nhận việc.

### 7.2 Admin Web

- Trang `/driver-credit` (nhóm **Tài chính**) hiển thị KPI, danh sách lệnh nạp, chi tiết lệnh và hai thao tác: đối soát với cổng, hoàn phần tạm ứng còn lại.
- BFF: `GET/POST /api/ops/driver-credit/*` (same-origin cho mutation), validate `reason` 5–500 và `bankRef` 3–120 trước khi gọi Nest.
- Thẻ **Phí nền tảng chưa đối soát** của hồ sơ tài xế hiển thị thêm dòng `creditVnd` để Ops thấy số dư đang cấn trừ.

## 8. Cài đặt Admin

| Setting | Mặc định | Ý nghĩa |
|---|---|---|
| `DRIVER_TOP_UP_ENABLED` | `false` | Bật nạp tiền; giữ tắt tới khi tài khoản merchant + webhook production sẵn sàng |
| `DRIVER_TOP_UP_MIN_VND` | `10.000` | Số tiền nạp nhỏ nhất |
| `DRIVER_TOP_UP_MAX_VND` | `2.000.000` | Số tiền nạp lớn nhất mỗi lệnh |
| `DRIVER_TOP_UP_DAILY_LIMIT_VND` | `5.000.000` | Tổng nạp đã trả trong ngày (giờ VN) |
| `DRIVER_CREDIT_MAX_VND` | `5.000.000` | Trần số dư tạm ứng còn lại |
| `DRIVER_TOP_UP_EXPIRE_MINUTES` | `15` | Hạn thanh toán của link |

Env: `DRIVER_TOP_UP_PROVIDER` (`payos` mặc định, `vnpay`), `PAYOS_CLIENT_ID`, `PAYOS_API_KEY`, `PAYOS_CHECKSUM_KEY`, `PAYOS_ENDPOINT`, `PAYMENT_PUBLIC_BASE_URL`, `PAYMENT_APP_RETURN_URL`.

## 9. Không nằm trong phạm vi

- Tự động hoàn tiền qua PSP (`payOS` không hỗ trợ payout).
- Chuyển số dư giữa tài xế, nạp hộ, nạp bằng tiền mặt tại quầy.
- Trả lãi hoặc dùng số dư để thanh toán chuyến của khách.
- Hoá đơn VAT cho khoản nạp (cần Finance/Legal quyết định riêng).

## 10. Test bắt buộc

- Chỉ chữ ký hợp lệ + đúng số tiền mới credit; replay IPN không cộng hai lần.
- Sai số tiền, callback lỗi, huỷ và hết hạn đều không tạo `driver.credit_liability`.
- Settlement phân bổ FIFO, `creditAppliedVnd` khớp tổng `DriverCreditApplication`, số dư ledger khớp `remainingVnd`.
- Hạn mức ngày, trần số dư, một lệnh `PENDING` mỗi lúc, KYC bắt buộc.
- Hoàn tiền chỉ khi `remainingVnd > 0`; audit + ledger đúng chiều.
- Realtime: mỗi transition phát đúng một hint `driverCreditStatus`; hint không cấp quyền/không cộng tiền, chỉ nhắc client refetch.
- Admin Web: `bankRef`/`reason` sai biên bị chặn ở BFF; nút hoàn tiền không xuất hiện khi `remainingVnd = 0`; nút đối soát chỉ với `PENDING`.
