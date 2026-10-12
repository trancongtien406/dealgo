# Hợp đồng trạng thái giao diện DealGo

## 1. Phân biệt các lớp trạng thái

**Network/UI**: `initial`, `loading`, `content`, `empty`, `error`, `offline`, `pending`, `conflict`, `expired` chỉ mô tả tình trạng màn hình/interaction; không được giả định tương đương status entity.

**Domain**: ride quote `OPEN / EXPIRED / ACCEPTED`; order `DRAFT / SUBMITTED / ... / DELIVERED`; shop fulfillment và delivery assignment, KYC eligibility, COD/settlement giữ state machine riêng từ Phase 19.1–19.3.

**Authorization**: API quyết định quyền thực hiện, client chỉ phản ánh quyền. Một role đã đăng ký không đồng nghĩa mỗi dịch vụ đều đủ điều kiện.

## 2. Event mapping (P0)

| Trigger | UI | Mutation hợp lệ |
|---|---|---|
| `quote.expired` | C007 `quote_expired` | Refetch, không commit quote cũ |
| `acceptQuote 409` | C007 `quote_taken` | Refetch offers, không assign duplicate |
| `quote.reprice` | C009 `fare_changed` | Hiện snapshot cũ/mới + hỏi consent |
| `checkout.PENDING` | C028 `submitting` | Disable CTA, retry cùng idempotency key |
| `checkout.OFFLINE` | C028 `checkout_offline` | Không hiện orderId hay paid |
| `merchant.accept 409` | M016 `accept_conflict` | Refetch order, đảm bảo version |
| `handoff.INVALID` | M019 `handoff_code_wrong` | Không chuyển PICKED_UP |
| `driver.INELIGIBLE` | D016 `ineligible_expired` | Disable service bị ảnh hưởng |
| `delivery.finish.UNKNOWN` | D030 `cod_unconfirmed` | Query by idempotency + proof trước khi ghi ledger |

## 3. Quy tắc quy đổi sang Flutter

- Dùng `DealGoUiState`/`DealGoUiSnapshot` từ lớp presentation; sự thật về trạng thái đơn/chuyến nằm ở backend.
- Mỗi mutation có `requestId/idempotencyKey`, `expectedVersion`, `actorRole`, server time; timeout không đồng nghĩa thất bại.
- Retry phải kiểm tra lại kết quả cũ trước khi ghi tạo mới, đặc biệt `POST /orders` và `completeDelivery`.
- In-flight request: hiển thị `pending`; không cho double-submit; chặn gesture điều hướng nguy hiểm nếu mất trạng thái.
- Conflict 409: refetch + cho lựa chọn hợp lệ, không giả định retry ngay vẫn sẽ thành công.
- Stream reconnect: lấy snapshot theo sequence mới nhất, không giảm state `DELIVERED` về `SHIPPING`.
- Price difference: nêu thay đổi, yêu cầu xác nhận chủ động, không auto-agree.
- Offline: không giả vờ giao dịch/thu tiền thành công; chỉ cho action có thể thực hiện offline.

## 4. Accessibility và độ ổn định

- Text mang ngữ nghĩa của status: “Đã giao”, “Đang xử lý”, “Lỗi kết nối”; không chỉ dùng màu.
- Có `Semantics` cho icon và screen announcement khi state chuyển.
- Button mục tiêu 48dp Android và >=44pt iOS; dùng SafeArea ở CTA.
- Test text scale 1.0, 1.3, 1.6; các form dài scroll tới cuối, bàn phím không che nút.
- Icon/loading có reduced motion fallback; skeleton không gây nhấp nháy khó chịu.
- Màu green brand `#16A34A` dùng accent/icon lớn; chữ xanh trên nền trắng dùng `#13743A` để đảm bảo contrast tốt hơn.
- Screenshots 1000×2036 không đồng nghĩa layout chắc chắn đạt mọi viewport; phải golden test trên thiết bị mục tiêu.

## 5. Definition of Done cho state

1. Trigger UI có code trạng thái chuẩn, mapping domain event rõ ràng.
2. Có primary/secondary action hợp lệ; không có CTA giả thành công.
3. Không có mutate khi invalid, không gửi request cùng nghiệp vụ hai lần ngoài idempotency.
4. Loading/empty/error/offline khác nhau, có recover path.
5. Render và semantics kiểm thử 360×800, 390×844, 430×932, dark mode nếu hỗ trợ; test font scale.
6. Golden test và backend contract test được thực thi trong CI trước khi đánh dấu production ready.
