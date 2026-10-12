# Flutter Handoff · Phase 19.2

Đích tích hợp trong cấu trúc code Flutter (đề xuất):

```
mobile/lib/
  core/design_system/theme/dealgo_theme.dart
  core/design_system/widgets/{dg_app_bar,dg_status_badge,dg_document_card,dg_bottom_cta}.dart
  features/verification/{domain,data,presentation}/
  features/merchant/onboarding/
  features/driver/onboarding/
  features/driver/capabilities/
```

Thành phần nên dùng chung, không xây hai bộ riêng cho Shop và Tài xế: `DocumentCaptureCard`, `UploadStatusPill`, `ReasonCodeCard`, `ReviewProgress`, `CapabilityGuard`, `ConsentSection`, `StatusTimeline`.

## Các bước thực hiện

1. Tạo token Flutter theo Phase19.1 (không lấy lại giá trị màu bằng cách đo ngẫu nhiên từ PNG).
2. Đưa 16 màn trong `screens/` vào danh sách golden test và test widget states với 4 mockup ngoại lệ.
3. Xây state mapper từ contract `caseState`/`documentState`/`capabilities`, không map tùy tiện từ tên màn.
4. Các CTA yêu cầu xác minh cuối cùng phải gọi API và chờ response backend; disable retry vô hạn, có cooldown & idempotency.
5. Chạy thiết bị kích thước 360/390/430 dp, scale 1.0/1.3/1.6, dark mode nếu sản phẩm hỗ trợ; kiểm thử keyboard, notch, nút cố định, voice accessibility.
6. Chạy kiểm thử liên kết từ M001→M013 và D001→D016 gồm trường hợp pending/rejected/expired/resubmitted.
7. Dùng `preview/gallery.html` để review ảnh ở kích thước đầy đủ; các HTML dựng hình không phải code Flutter production.

## Definition of Done

- Duyệt thiết kế 16 màn với nhóm sản phẩm.
- Thực thi state machine và 10 test P0 trong `02_KYC_KYB_STATE_MACHINE.md`.
- Redact mọi dữ liệu giấy tờ trong analytics, screenshots test, log; không dùng ảnh giấy tờ thật làm fixture.
- Có cảnh báo trạng thái quyền hoạt động ngay cả khi app đang chạy/background/restore.
- Đồng bộ feature eligibility khi khách đặt và tài xế nhận việc, tránh giao dịch đã nhận nhưng quyền bị thay đổi âm thầm.
- Phê duyệt pháp lý và điều kiện riêng từng dịch vụ trước khi go-live.
