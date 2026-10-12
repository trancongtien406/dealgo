# DealGo — Phase 19.1: Remediation P0 và Golden Screens

Ngày thực hiện: 12/10/2026. **Phạm vi đã sửa trong pass này là 16 màn**, KHÔNG phải toàn bộ 165 màn. Trang chủ C001 được giữ nguyên làm brand anchor.

## Mục tiêu và kết quả

- Tạo **16 ảnh PNG mới 1000×2036** từ 16 file HTML nguồn với bộ token màu, spacing, card, CTA và header thống nhất; không ghi đè ảnh gốc.
- Ride CAR: **C004, C005, C006, C007, C008, C009, C010, C011** dùng chung mã chuyến `RIDE_CAR_001`, báo giá `Q-CAR-0007`, tổng tiền **42.000đ**, tài xế Nguyễn Văn Hùng, Toyota Vios, biển `43A-567.89`.
- Flow thương lượng không còn nghịch lý: `C004 → C005 → C006 → C010 (thu thập báo giá) → C007 → C008 → C009 → C011`.
- Food COD: **C028, M016, D030, D036, M035** cùng `DG123456` với tiền món 125.000đ + phí giao 25.000đ = COD 150.000đ; tiền công tài xế 20.000đ và COD cần đối soát 130.000đ tách biệt.
- Role shells **S007, M013, D016** dùng chung thành phần trực quan; đổi vai trò không tự dừng đơn/ca làm; D016 dùng Honda Vision `43H1-123.45` ở scenario RIDE_BIKE_001 riêng, không gộp với ô tô.
- `validate_phase19.py` kiểm tra giá, mã và thông tin xuyên màn, đối soát đơn và kích cỡ 16 mockup. `render_and_validate.py` dựng lại ảnh và đo tràn nội dung ở kích thước khung 500×1018 (2× = 1000×2036).

## Trạng thái issue

| Mã | Mức | Trạng thái sau pass 1 | Giới hạn / bước tiếp |
|---|---|---|---|
| UI-001 | P0 | **Đã sửa trong 8 màn Ride pass 1** | Các màn Ride khác C012–C021 chưa cập nhật theo fixture |
| UI-002 | P0 | **Đã tách scenario Car và Bike trong fixture + màn mới** | Kiểm tra/đồng bộ tiếp D019–D025 (ảnh cũ) |
| UI-003 | P0 | **Đã sửa 5 màn food/cross-role đại diện** | C027–C036, M017–M021, D026–D031 còn màn ảnh cũ |
| UI-004 | P0 | **Đã làm rõ COD, trạng thái và nguyên tắc backend-authoritative** | Chưa thay backend, chưa kiểm thử giao dịch thật |
| UI-005 | P0 | **Chưa sửa UI KYC/KYB**, mới đưa vào state contract | Ưu tiên pass 2: D004–D015, M004–M012 |
| UI-006/009 | P1 | **Đã có 3 role shell + token dùng chung tại 16 màn** | Áp dụng cho các màn còn lại sau khi phê duyệt |
| UI-011/012 | P1 | **Có hợp đồng states/role switch** | Chưa có hình đầy đủ cho loading/error/empty của 165 màn |

## Phân biệt kiểm chứng

**Đã kiểm chứng:** ảnh PNG và HTML nguồn tồn tại; phép cộng giá/ledger mẫu nhất quán; bố cục mockup pass được phép đo không tràn ở kích thước tham chiếu.

**Chưa kiểm chứng:** Flutter implementation, UI responsive trên thiết bị thật, pixel-perfect với C001, logic API/KYC/payment thực tế, các trạng thái lỗi trên 165 route và kiểm thử Accessibility.

## Hướng dẫn tích hợp Flutter

1. Duyệt trực quan 16 ảnh mới và quyết định Design Tokens.
2. Tạo `DealGoTheme`, `PriceSummary`, `DriverOfferCard`, `OrderSummary`, `CODReconciliationCard`, `RoleSwitcher`, `RoleAppBar` từ một nguồn token đã duyệt.
3. Nạp các fixture ở `golden_fixtures.json` vào golden/widget tests, KHÔNG copy số tiền trực tiếp từ screenshot sang production.
4. Đảm bảo `acceptedQuoteId`, `orderVersion`, payment/settlement states do backend trả về; không đánh dấu success trên tín hiệu UI cục bộ.
5. Kiểm tra ở 360/390/430 logical dp, text scale 1.0/1.3/1.6, SafeArea và keyboard; thay phone mockup bằng Scaffold thật.
6. Sau khi pass P0, vá hình và code phần còn lại theo manifest/ID, không nhân rộng lỗi từ ảnh cũ.

## An toàn dữ liệu và tài nguyên

Tất cả tên, địa chỉ, số điện thoại và biển số trong fixture là dữ liệu **minh họa**; không được dùng trong logic production hay lưu bất kỳ dữ liệu KYC thật nào vào asset.
