# Prompt thực thi trong Cursor / Engineer Intelligence

Đọc tài liệu Phase 19.1 và các file `docs/golden_fixtures.json`, `docs/flow_state_contracts.json`, `docs/PHASE19_REPORT.md`, `screens/*.html`, `screens/*.png`. Trang chủ gốc C001 trong `assets/C001_home_original.png` là nhận diện tham chiếu và không được sửa trực tiếp.

**Mục tiêu:** triển khai Design System DealGo đúng ảnh đã duyệt, không dùng WebView/HTML screenshot trong ứng dụng, không hardcode data mẫu trong production. Tạo các widget tái dùng (`RoleAppBar`, `RideFareBreakdown`, `RideOfferCard`, `OrderPriceSummary`, `CODLedgerSummary`, `PaymentStatusBadge`, `RoleModeSwitcher`, `DealGoBottomCTA`).

Thực hiện theo thứ tự:
1. Inventory project hiện có, tận dụng theme/rules/skills/agent có sẵn, không tự tạo bản sao component.
2. Chuẩn hóa semantic colors, spacing, radius, type scale; dark theme hỗ trợ bằng semantic tokens nếu dự án yêu cầu.
3. Khai báo typed DTO cho RideQuote, FoodOrder, PaymentState, SettlementSnapshot, KycStatus; các giá trị lấy từ backend hoặc fixture test.
4. Bắt đầu golden/widget tests ở C004, C005, C006, C007, C008, C009, C010, C011, C028, M016, D030, D036, M035, S007, M013, D016. Dùng cùng một `RIDE_CAR_001` và `FOOD_001` cross-role.
5. Add UI state loading/empty/error/offline/expired, consent giá mới, COD pending, KYC denied/retry.
6. Responsive 360/390/430 logical dp, text scaler 1/1.3/1.6, semantics và safe-area; chạy test trên dự án thật; nếu không chạy được, báo blocker và không tự ghi pass.
7. Chỉ sau khi review và QA đủ mới áp dụng cho 149 màn cũ còn lại.

**Definition of Done:** report file changed, kết quả test thực tế, screenshot golden ở device sizes, không overflow, không mix CAR/BIKE, không COD-as-income, số tiền chỉ từ `fareVersion/orderVersion` đã chốt, không success giả khi backend chưa xác nhận.
