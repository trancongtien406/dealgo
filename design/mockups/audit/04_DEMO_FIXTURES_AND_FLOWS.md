# DealGo — Golden Demo Fixtures & End-to-End Flows

**Mục tiêu:** không tự điền những con số khác nhau trong từng ảnh. Đây là dữ liệu đề xuất để update toàn bộ screenshot/test; không phải giá cước hoặc tài khoản thật.

## 1. Tách 3 scenario thay vì gộp mọi màn vào một giao dịch

### Scenario RIDE_CAR_001 — xe 4 chỗ

- `rideId`: `RIDE_CAR_001`
- pickup: `123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng`
- destination: `Sân bay Đà Nẵng`
- service: `CAR_4`, driver: `Nguyễn Văn Hùng`, vehicle: `Toyota Vios`, biển số demo: `43A-567.89`
- `acceptedQuoteAmount`: **42.000đ** (ví dụ minh họa)
- `additionalApprovedFees`: 0; `discountApplied`: 0; **payable = 42.000đ**. Nếu thêm phụ phí sân bay, phải tính trước accept hoặc xin consent sửa giá.
- Chọn một công thức giá *duy nhất* cho C004→C005→C006→C007→C008→C009→C010→C011→C012→C013→C017; tuyệt đối không lấy 63k/72k/108k từ các phiên bản demo cũ lẫn vào scenario này.

### Scenario RIDE_BIKE_001 — xe máy tài xế

- `rideId`: `RIDE_BIKE_001`
- service: `BIKE`, driver: `Trần Minh Anh`, vehicle: `Honda Vision 2023`, biển số demo `43H1-123.45`.
- `acceptedQuoteAmount`: **45.000đ**; separate from `RIDE_CAR_001`.
- D019→D020→D021→D022→D023→D024→D025 dùng đúng thông tin này; phía khách nếu muốn demo chéo thì sửa các C screen demo tương ứng sang BIKE.

### Scenario FOOD_001 — đơn giao đồ ăn COD

- `orderId`: `DG123456`; shop: `Bún Bò Huế O Cô`; customer: `Mai Anh`.
- `orderItems`: Bún bò đặc biệt **60.000đ** + Bún bò thường **40.000đ** + Trà tắc **25.000đ** = **125.000đ**.
- `deliveryFeeChargedToCustomer`: **25.000đ**; `voucher`: 0; `customerPayable`: **150.000đ**.
- Payment `COD`, `cashCollectedByDriver`: **150.000đ**; **không** đồng nhất khoản này với thu nhập tài xế.
- Ví dụ `driverNetEarnings`: **20.000đ**, `platformDeliveryFee`: 5.000đ (2 khoản này chỉ mang tính ví dụ, cần backend ledger khớp).
- C026→C036, M016→M021, D026→D031 chỉ render 1 fixture này nếu trình diễn một đơn xuyên 3 role. Nếu đổi món/giá thì đổi `orderVersion` và chỉ ghi nhận sau khách đồng ý.

## 2. Domain snapshots (không suy từ widget text)

```text
RideQuote { quoteId, rideId, version, amount, currency, expiresAt, driverId, vehicleId, feeBreakdown }
Ride { rideId, serviceType, pickup, destination, status, acceptedQuoteId, totalPayable, passengerOtpVerified }
FoodOrder { orderId, version, itemsSnapshot, subtotal, discounts, customerDeliveryFee, customerPayable, paymentStatus, merchantStatus, deliveryStatus }
DeliveryAssignment { assignmentId, orderId, driverId, pickupOtp, handoffProof, deliveredProof, codCollected, driverEarnings }
LedgerEntry { id, accountType, amount, currency, kind, status, transactionId }
```

## 3. Flow kiểm thử đa role

### Ride báo giá

```text
C004 chọn xe → C006 đề xuất → D018 nhận thấy request → D020 trả giá
→ C007/C008 chọn quote → C009 chốt và trả tiền → D021 đón khách
→ C011/C012 + D022/D023 OTP → C013/D024 di chuyển
→ C017 + D025 hoàn tất → C018 đánh giá
```

**Kiểm tra:** quote chỉ được accept 1 lần; driverId/vehicleId đúng; không tự tăng fare; OTP sai không thể bắt đầu; hủy/expire giải phóng assignment.

### Food COD

```text
C027 giỏ → C028 checkout → C032 tạo đơn → M016 nhận đơn
→ M017 làm món → M019/D028 giao nhận → D029/C033 đang giao
→ D030/C036 hoàn tất → M035/D036 đối soát
```

**Kiểm tra:** món/variant và item counts giống nhau, snapshot giá, voucher, phụ phí; shop không đánh dấu bàn giao nếu chưa có xác nhận tài xế; COD & tài xế earnings vào các ledger khác nhau; một order có một proof hợp lệ.

## 4. Chú ý test trạng thái

- Quotation timeout, driver mất mạng, trả giá cùng lúc, quote rút lại trước khi chọn.
- Shop từ chối/đề nghị thay món, khách không trả lời, driver tới sớm, quán đóng cửa.
- OTP sai/nhiều lần, khách không liên lạc được, POD ảnh thất bại, COD chưa được đối soát.
- Tài xế thiếu giấy tờ theo dịch vụ, giấy tờ hết hạn khi đang online, switch role không mất việc đang chạy.
- Khi thay `amountPayable`, server phát `price_change_requires_consent`, UI buộc xác nhận giá mới.
