# DealGo — Flutter UI Handoff & Acceptance Checklist

## Thực hiện theo thứ tự

1. Chốt `02_DESIGN_SYSTEM.md`, `design_tokens.json` và 3 role navigation shells.
2. Tạo `GoldenDemoFixtures` từ `04_DEMO_FIXTURES_AND_FLOWS.md`; không copy cứng các số tiền từ PNG vào widget.
3. Implement shared components; tạo golden references C001, C004, C028, S007, M013, D016 trước khi dựng toàn bộ màn.
4. Implement ride/food/merchant/driver bằng route và state model; đối chiếu `screen_manifest.csv`.
5. Test state matrices, responsive, accessibility và E2E cross-role; chỉ sau đó khóa UI/UX.

## Cấu trúc Flutter tham khảo

```text
mobile/
  lib/
    app/
      app.dart
      router/ (role-aware navigation, deep links)
      theme/ (dealgo_theme.dart, tokens, typography)
    design_system/
      atoms/ (button, text_field, icon, badge, price)
      molecules/ (cards, list_row, offer, address, status)
      organisms/ (route_map, order_timeline, bottom_cta, checkout_summary)
      feedback/ (empty, error, offline, loading, dialog)
    shared/
      models/ (money, address, payment, quote, order)
      services/ (maps, auth, navigation, deep links)
    features/
      auth/
      customer/ (ride, food, checkout, activity)
      merchant/ (onboarding, orders, catalog, finance)
      driver/ (onboarding, dispatch, ride, delivery, finance)
      support/
    test_support/
      golden_fixtures/
  test/
    golden/
    widgets/
    flows/
```

Provider/BLoC/Cubit/Riverpod là lựa chọn tổ chức state — chỉ chọn một quy tắc trong repo; tránh duplicate state do nhiều màn tự gọi API cho một object đã chốt. Không tạo `MultiBlocProvider` global cho tất cả các trang nếu không cần app lifetime.

## Component checklist

- [ ] `AppBar` có back, title và action đúng role; không tự sửa logo bằng Text ad-hoc.
- [ ] `BottomNav` riêng cho 3 role, cùng convention về selected icon/label.
- [ ] `Scaffold`/`SafeArea` không render tai thỏ/home indicator giả vào production.
- [ ] `BottomCTA` nằm ngoài scroll body; keyboard không che submit ở OTP/chat/form.
- [ ] Currency `VND` qua một formatter thống nhất, negative/refund có label.
- [ ] StatusBadge dựa trên enum/state machine, không so sánh chuỗi hiển thị.
- [ ] Timeouts quote/assignment dùng timestamp server, không trông vào animation/mock countdown.
- [ ] Semantics cho icon-only, bản đồ, rating, status, OTP, cảnh báo.
- [ ] Network loading/empty/error/offline/denied permission hoạt động và có Retry.
- [ ] Dark mode: xác định phạm vi (có thể P1); nhưng text/icon cần dùng semantic colors từ đầu.

## Screen QA matrix (không thêm route mới)

| Màn / nhóm | Default | Loading | Empty | Error/Offline | Disabled/Expired | Accessibility |
|---|---|---|---|---|---|---|
| C002–C011 Ride offer | ✓ | ✓ | no drivers | ✓ | quote expired | ✓ |
| C012–C018 Ride active | ✓ | ✓ | n/a | reconnect | cancelled/completed | ✓ |
| C022–C031 Food browse/checkout | ✓ | ✓ | no results/cart | ✓ | out of stock | ✓ |
| C032–C041 Food tracking | ✓ | ✓ | n/a | ✓ | refund/failed | ✓ |
| S003–S007 Auth/role | ✓ | ✓ | n/a | ✓ | OTP expired/denied | ✓ |
| M001–M012 KYC Shop | ✓ | ✓ | incomplete | upload fail | rejected/expired | ✓ |
| M013–M044 Ops & finance | ✓ | ✓ | no orders | ✓ | locked/pending | ✓ |
| D001–D015 Driver KYC | ✓ | ✓ | incomplete | upload fail | eligibility blocked | ✓ |
| D016–D031 Matching/trips | ✓ | ✓ | no jobs | offline | quote expired | ✓ |
| D032–D045 Driver earnings/settings | ✓ | ✓ | no history | ✓ | payout pending | ✓ |

## Golden + widget tests

- Golden ở 360×800, 390×844, 430×932 logical dp và `textScaleFactor` tương đương 1.0, 1.3, 1.6. (Trong Flutter mới nên sử dụng `TextScaler` API phù hợp version project.)
- `PaymentSummary` test: sum line items = subtotal; payable = subtotal + fees - discounts; thanh toán COD không tự trở thành driver earning.
- `OfferCard` test: nhận quote sau expiresAt → disabled; accept quote trong thời hạn → state locked.
- `OrderTimeline` test: mỗi role nhìn cùng status IDs nhưng label/nút khác quyền.
- `RoleSwitch` test: đổi góc nhìn không tự huỷ công việc đang chạy; deep link thông báo chuyển đúng role.
- `KYC` test: document expired/ocr mismatch/duplicate submission/denied camera, retry có feedback.

## Definition of Done cho từng screen ID

- [ ] Ảnh nguồn ID xác thực từ manifest, fixture có cùng màn liên quan.
- [ ] Responsive không overflow với keyboard, font scale, notch và gesture inset.
- [ ] Đầy đủ loading, empty/error/offline, quyền truy cập, server-state handling.
- [ ] Không hardcode status text/money/driver/address riêng cho UI ngoài fixture.
- [ ] Widget/golden tests pass; semantics & focus order cơ bản pass.
- [ ] Logging/analytics đúng sự kiện thiết kế, không ghi PAN/CVV/OTP/CCCD vào log.
- [ ] Reviewed visually against **C001 brand anchor** và cùng role shell.

## Ranh giới

HTML đi kèm screenshot chỉ là **bản tham khảo layout**, không phải source để dán trực tiếp vào Flutter WebView. Một screen hiện có PNG không được tự động đánh dấu "đã code" hoặc "đã test".
