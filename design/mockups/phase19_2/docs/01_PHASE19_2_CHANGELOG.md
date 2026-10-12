# DealGo · Phase 19.2 — KYC/KYB Remediation

**Phạm vi:** Thay thế 16 mockup route cũ; bổ sung 4 mockup trạng thái ngoại lệ, **không** tạo thêm route trong inventory 165 màn. **Trang chủ C001 được giữ nguyên byte-for-byte.** Bản này là prototype trực quan và hợp đồng dữ liệu mẫu, không phải sản phẩm đã tích hợp KYC thật.

## Các thay đổi đã thực hiện

| Role | Screen ID | Điều đã sửa |
|---|---|---|
| Shop | M004 | Tách tài liệu hai mặt và trạng thái tải ảnh/chờ duyệt; không hiển thị giấy tờ thật |
| Shop | M005 | Giấy tờ bắt buộc xác định theo loại hình/ngành hàng thay vì cố định một bộ cho mọi Shop |
| Shop | M010 | Rà soát hồ sơ, điều khoản đồng ý, snapshot khi submit |
| Shop | M011 | PENDING_REVIEW: cho soạn menu nhưng không cho nhận đơn khi chưa duyệt |
| Shop | M012 | Lý do yêu cầu bổ sung có reason code, chỉ sửa những mục chưa đạt |
| Shop | M044 | Giấy tờ hết hạn, đánh giá lại quyền kinh doanh liên quan |
| Driver | D004 | Chụp giấy tờ hai mặt, placeholder được che, chưa đánh dấu xác minh |
| Driver | D005 | OCR phải được kiểm tra lại, cho sửa/chụp lại, không tự duyệt |
| Driver | D006 | Phân biệt quyền camera / liveness / face match với kết quả backend |
| Driver | D009 | Tình trạng đăng ký xe, bảo hiểm và GPLX theo dịch vụ |
| Driver | D012 | Rà soát, đồng ý submit, chờ backend phân quyền |
| Driver | D013 | PENDING_REVIEW, quyền Chở khách và Giao đồ ăn tách riêng |
| Driver | D014 | Nộp bổ sung có reason code, giữ lại bằng chứng cũ đủ điều kiện |
| Driver | D015 | Giấy tờ hết hạn và khóa capability liên quan thay vì mặc định khóa mọi hoạt động |
| Driver | D040 | Hiển thị quyền dịch vụ dựa vào trạng thái được backend cấp |
| Driver | D041 | Đổi phương tiện kích hoạt kiểm tra lại, không thay xe giữa chuyến đang thực hiện |

### 4 state variants (không tính là route)

- `M011_REJECTED`: Shop bị từ chối kèm lý do và đường dẫn nộp lại.
- `M012_RESUBMITTED`: Đã nộp bổ sung, vẫn chưa được duyệt.
- `D015_BLOCKED`: Quyền Ride tạm ngưng do GPLX hết hạn; các dịch vụ còn lại tùy điều kiện backend.
- `D015_RESTORED`: Quyền Ride khôi phục sau khi duyệt giấy tờ mới; tài xế vẫn tự chọn Online.

## Điều kiện nghiệm thu P0

1. **Upload != approval:** client không bao giờ suy ra `APPROVED` từ thao tác upload thành công hay OCR/liveness UI.
2. **Backend is authoritative:** route shell, foreground CTA và dispatcher đều kiểm tra capability từ server; không chỉ ẩn nút ở client.
3. **Theo dịch vụ:** giấy tờ không hợp lệ chỉ giới hạn các dịch vụ mà điều kiện tham gia phụ thuộc tài liệu đó; nếu chính sách yêu cầu GPLX cho Food thì Food cũng phải tắt.
4. **Không sửa trạng thái hoạt động đang chạy:** thay phương tiện không cập nhật assignment có hiệu lực; server xử lý chuyển giao/hủy an toàn riêng.
5. **Lý do minh bạch:** rejected/needs_changes phải có reason code ổn định, danh sách field, retry policy và hướng dẫn hỗ trợ.
6. **Tài liệu nhạy cảm:** giữ an toàn truy cập, không ghi thông tin định danh thô vào analytics/crash logs; mockup sử dụng placeholder che số và hình, không dùng ảnh thật.
7. **Truy vết:** `caseId`, `submissionVersion`, `reviewedAt`, `reasonCodes` và `decisionAt` được ghi ở backend; sự kiện idempotent.
8. **UI states:** DRAFT/SUBMITTED/PENDING_REVIEW/REQUIRES_CHANGES/RESUBMITTED/APPROVED/REJECTED/EXPIRED/SUSPENDED/REVERIFYING.

## Giới hạn quan trọng

- Các screen PNG chỉ test tại khung 500×1018 nhân 2; Flutter responsive, accessibility và API thực vẫn chưa được kiểm thử.
- Không xác nhận điều kiện pháp lý tại Việt Nam, yêu cầu KYC cụ thể hoặc SLA duyệt hồ sơ. Chính sách đủ điều kiện phải do pháp chế và bộ phận vận hành xác nhận trước khi triển khai.
- Không tự suy luận sinh trắc học, bằng lái hợp lệ hoặc giấy tờ thật từ hình minh họa.
- Đợt này sửa 16/165 màn có liên quan, **không khẳng định toàn bộ 165 đã được sửa hết P0**.
