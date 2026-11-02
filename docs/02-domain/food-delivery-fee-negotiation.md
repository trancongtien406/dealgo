# Thoả thuận phí giao đồ ăn (khách ↔ tài xế)

> Trạng thái: `DRAFT` — chờ chủ sản phẩm xác nhận các mục ở "Quyết định còn mở".
> Tài liệu này mô tả logic đã triển khai; không đưa ra nhận định pháp lý.

## 1. Nguyên tắc

- Máy chủ **chỉ gợi ý** phí giao (`suggestedDeliveryFareVnd`, tính theo cự ly như cũ qua `POST /v1/food/quote`).
- Khách **đề nghị** một mức phí (`deliveryOfferVnd`) trong khoảng cho phép; mặc định = mức gợi ý.
- Tài xế **nhận** đúng mức khách đề nghị (nút "Nhận" hiện có) hoặc **đề xuất giá khác** (counter).
- Khách **chọn** một đề xuất; việc chọn gán tài xế và chốt phí **nguyên tử** trong một giao dịch. Các đề xuất còn lại → `LOST`.
- Phí đã chốt ghi vào `FoodOrder.deliveryFareVnd` (+ `deliveryFareAgreedAt`) và đi tiếp vào tổng tiền, thanh toán, sổ cái như trước. Giống mô hình báo giá của chuyến xe (`DEC-PROD-016`, ride offers).

## 2. Khoảng giá (setting, admin chỉnh được)

| Key | Mặc định | Ý nghĩa |
|---|---|---|
| `FOOD_FARE_FLOOR_PERCENT_OF_SUGGESTED` | 70 | Sàn đề nghị = max(`FOOD_MIN_DELIVERY_VND`, gợi ý × %), làm tròn lên theo bước (không vượt gợi ý) |
| `FOOD_COUNTER_MAX_PERCENT_OF_OFFER` | 150 | Trần đề xuất của tài xế = giá khách × % |
| `FOOD_FARE_STEP_VND` | 1000 | Bước giá; mọi số tiền (trừ đúng mức gợi ý) phải là bội số |
| `FOOD_MAX_OFFER_EDITS_PER_DRIVER` | 2 | Số lần một tài xế sửa đề xuất |
| `FOOD_MAX_FARE_RAISES_PER_ORDER` | 3 | Số lần khách nâng giá khi chưa có tài xế |
| `FOOD_OFFER_TTL_SECONDS` | 120 | Hạn của một đề xuất (kiểm tra lười khi đọc/chọn) |

Trần đề nghị của khách = `FOOD_MAX_DELIVERY_VND`.

## 3. Luồng

1. Checkout: app hiện "Phí giao gợi ý" + bộ tăng/giảm (bước từ máy chủ). `POST /v1/food/orders` nhận `deliveryOfferVnd`; máy chủ kiểm tra khoảng & bước (`FOOD_OFFER_AMOUNT_INVALID`); các lỗi khác: `FOOD_OFFER_EXPIRED`, `FOOD_OFFER_EDIT_LIMIT`, `FOOD_OFFER_NOT_FOUND`, `FOOD_FARE_RAISE_LIMIT`, `FOOD_FARE_LOCKED`.
2. Thương lượng mở khi tài xế thấy đơn (cửa sổ gán sớm hoặc READY).
3. Tài xế: `POST /v1/food/orders/:id/delivery-offers {amountVnd}` (tạo/sửa), `DELETE .../delivery-offers/mine` (rút).
4. Khách: `GET .../delivery-offers`, `POST .../delivery-offers/:offerId/select`, `POST .../delivery-fare {amountVnd}` (nâng giá; bắn lại yêu cầu tới tài xế đã được báo qua outbox `FoodOrder.fare.RAISED`).
5. Chọn: khoá đơn `FOR UPDATE`, kiểm tra lại điều kiện nhận việc của tài xế, gán + ghi phí; đề xuất được chọn `SELECTED`, còn lại `LOST`.
6. Tranh chấp: claim/select/raise đồng thời được chặn bằng guard `updateMany where deliveryFareVnd = <giá hiện tại> and assignedDriverId is null` → bên thua nhận 409.

## 4. Thanh toán

- Voucher vẫn khoá theo phí lúc đặt.
- Đơn trả trước: nếu phí chốt cao hơn phần đã trả, phần chênh lệch thu tiền mặt khi giao (`splitCollection`). App hiển thị ghi chú này.

## 5. Giao diện

- Mobile khách: panel đề nghị ở checkout; thẻ "Phí giao" trên màn theo dõi khi chưa có tài xế (danh sách đề xuất, Chọn, Tăng lên +1 bước, số lần còn lại), thăm dò 5s.
- Mobile tài xế: nút "Đề xuất giá" trên màn yêu cầu đơn (sheet bước giá, trong trần).
- Mobile quán: nhãn "Phí giao (đã thoả thuận)" khi đơn đã có tài xế.
- Admin web: settings 6 key; chi tiết đơn có mục "Phí giao (thoả thuận)": gợi ý / chốt / thời điểm / danh sách đề xuất.

## 6. Xung đột với tài liệu hiện có (cần cập nhật khi xác nhận)

- `02-domain/pricing-fees-and-promotions.md` dòng ~50: "khách không sửa được" phí giao.
- `00-governance/decisions-and-assumptions.md` `DEC-PROD-016`: "khách không tự sửa phí giao".
Hai chỗ này chưa được sửa — chờ chủ sản phẩm ra quyết định mới (đề xuất `DEC-PROD-xxx`).

## 7. Quyết định còn mở

1. Tài xế bấm "Nhận" = đồng ý ngay giá khách (hiện tại) hay bắt buộc qua chọn?
2. Tài xế nhả đơn (release): giữ phí đã chốt, xoá `agreedAt` (hiện tại) hay quay về giá khách ban đầu?
3. Có cho khách giảm giá sau khi đặt không (hiện tại: chỉ nâng)?
4. Mức % sàn/trần và TTL mặc định.
5. Có thông báo đẩy cho khách khi có đề xuất mới (hiện có notification audience `foodOrderFareNotifications`; app đang thăm dò).

## 8. Mã nguồn & kiểm thử

- Migration `backend/prisma/migrations/20270106090000_food_delivery_fee_negotiation/` (chưa apply).
- `food.service.ts`, `food.controller.ts`, `food.dto.ts`, `food-prisma.repository.ts`, `outbox-relay.service.ts`.
- Test: `food-delivery-fee.spec.ts`, `test/concurrency/food-delivery-fee.race.spec.ts`, web `delivery-fee.test.ts`, mobile `test/features/food/food_fare_negotiation_test.dart`.

## Chế độ phí giao (FOOD_DELIVERY_FEE_MODE)

Admin cấu hình trong Platform Settings (nhóm DISPATCH), mặc định `NEGOTIATE`.

- `NEGOTIATE` (Cho trả giá): nền tảng gợi ý phí, khách chọn; tài xế có thể trả giá (counter), khách chọn offer.
- `FIXED` (Giá cố định): tài xế chỉ được nhận đơn với phí đã chốt. `counter`/`select` trả 409 `FOOD_FEE_NEGOTIATION_DISABLED`; danh sách offers trả `[]`. Khách vẫn có thể tăng phí (raise).

`quote` và `offers` trả thêm `feeMode`; chi tiết đơn ops có `deliveryFeeMode`. Chế độ áp dụng toàn nền tảng tại thời điểm gọi (không snapshot theo đơn).
