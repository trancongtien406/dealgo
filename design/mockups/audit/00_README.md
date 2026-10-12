# DealGo — UI Consistency Audit & Flutter Handoff

**Phạm vi:** 165 mockup mobile theo Screen Inventory v2.0 (28 S, 48 C, 44 M, 45 D). 37 màn Admin Web chưa nằm trong audit này. Ảnh là mockup tĩnh; việc có ảnh **không đồng nghĩa** màn hình đã được test hoặc implement.

## Kết quả đã đối soát

- 165/165 màn **có ảnh tham chiếu** sau khi đối chiếu tên gốc.
- 157 ảnh đặt tên chuẩn mã màn trong `dealgo_mockups/`; 8 ảnh nằm ở thư mục cấp trên hoặc chưa theo quy ước: **C001, C005–C011**.
- Kích thước ảnh: **154 ảnh 1000×2036**, **3 ảnh 1000×2000** (C002–C004), **8 ảnh 941×1672** (C001, C005–C011).
- Có **96 tệp HTML tham khảo** tìm được theo mã; **69 màn chưa có HTML theo mã**. HTML không phải source Flutter.
- Phát hiện ảnh hưởng trực tiếp nghiệp vụ: giá luồng Ride thay đổi qua các bước mà chưa có ranh giới báo giá lại/đồng ý giá.

## Tài liệu trong bộ này

1. `01_AUDIT_REPORT.md` — lỗi theo P0/P1/P2, màn hình liên quan, tiêu chí nghiệm thu.
2. `02_DESIGN_SYSTEM.md` — Design Tokens và quy tắc component, UX, trạng thái.
3. `03_FLUTTER_HANDOFF.md` — chiến lược chuyển từ mockup sang Flutter, kiến trúc widgets, kiểm thử.
4. `04_DEMO_FIXTURES_AND_FLOWS.md` — dữ liệu mẫu xuyên 3 vai trò và kiểm tra luồng.
5. `screen_manifest.csv` — đường dẫn nguồn thực, kích thước, hash, nhận diện HTML cho 165 ảnh.
6. `design_tokens.json` + `dealgo_theme.dart` — token đề xuất và Flutter ThemeData ban đầu.
7. `*_01.jpg`, `*_02.jpg`, ... — contact sheets giúp rà soát nhanh theo nhóm màn.

## Quy tắc áp dụng

**Ảnh trang chủ C001 là chuẩn nhận diện thương hiệu**, không dùng tỷ lệ pixel hay bố cục thiết bị trong ảnh như thông số production. `design_tokens.json` là **đề xuất chuẩn hóa**, cần duyệt trực quan trước khi code hàng loạt.

**Chưa làm:** tự động nhận dạng chữ bằng OCR trên tất cả ảnh; kiểm thử tương tác Flutter thực tế; đối chiếu pháp lý từng yêu cầu dịch vụ; audit 37 màn Admin Web; nhận dạng pixel-perfect 165 màn có trạng thái responsive.
