# DealGo Phase 19.4 – UI state coverage & consistency

**Ngày:** 2026-10-12. **Trạng thái:** mockup + hợp đồng UI, chưa test trên app Flutter thật.

## Phạm vi đã làm

- 25 biến thể trạng thái tĩnh có PNG riêng (1000 × 2036), HTML tham khảo, 1 ảnh tổng quan, 7 ảnh nhóm.
- Phân bổ 7 nhóm: auth 2; maps 2; payments 1; ride 7; food 4; shop 4; driver 5.
- 25 biến thể thuộc 18 route gốc, mã `C007__quote_expired` có nghĩa **variant của C007**, không phải route mới.
- Giữ 165/165 mã màn hình chính và **không chỉnh sửa C001**.
- Kiểm tra tự động: 25/25 render đủ kích thước; không có clipping qua footer tại viewport mục tiêu; không có ảnh `<img>` tải lỗi. Đây không phải golden test đa thiết bị.

## Phát hiện và khuyến nghị ưu tiên

| Priority | Vấn đề | Quy tắc sửa |
|---|---|---|
| P0 | Trùng đơn do retry/nhấn nhiều lần | idempotency key, trạng thái `pending`, không mở nút submit lần hai |
| P0 | Báo giá hết hạn / hai yêu cầu cùng chọn tài xế | kiểm tra quote ID, version, expiry ở backend; lỗi 409 hiển thị conflict |
| P0 | Giá thay đổi lúc checkout | snapshot so sánh cũ-mới, chỉ commit sau chấp thuận của khách |
| P0 | Thông tin tracking quá cũ | hiển thị “vị trí cập nhật lần cuối”, không đưa ETA giả |
| P0 | Shop và Driver xử lý đồng thời | optimistic locking, currentVersion, refresh snapshot sau conflict |
| P0 | COD chưa xác nhận | không ghi COD_COLLECTED / DELIVERED / ledger trước server ACK |
| P0 | KYC hết hạn | kiểm tra eligibility theo dịch vụ, không khóa vô điều kiện mọi role |
| P1 | Không có kết quả / permission denied | cho đường đi thủ công, không spam prompt quyền |
| P1 | Loading/empty/error dễ lẫn nhau | placeholder & CTA phù hợp từng state, không hiển thị “0 đơn” khi fetch thất bại |

## Điểm cần chỉnh trước khi vào production

1. Đảm bảo `DealGoUiSnapshot` nhận state từ BLoC/Cubit hoặc ViewModel, thay string hardcode bằng code trạng thái backend.
2. Đánh giá contrast/font scale trên iOS và Android, keyboard/safe area, TalkBack/VoiceOver.
3. Viết contract test cho 409, mạng chập chờn, retry, expiry, offline queue, at-least-once delivery events.
4. Không sử dụng ảnh vẽ màn hình như assets production; Flutter dùng component thật và bản đồ SDK được cấp phép.
5. `C001` ảnh gốc phải được giữ làm visual anchor; để có nhận diện thật cần logo source/vector hợp pháp.

## Kiểm tra đã chạy

- `python build_phase19_4.py`: xây HTML và bảng state.
- `python render_check.py`: Chromium screenshot và soát clipping/footer.
- `python package_and_verify.py`: xác minh 165 route và 25 variants, hash của C001, ZIP integrity.

Các phép test ở đây xác nhận **tính toàn vẹn và bố cục tĩnh**, không chứng minh tính đúng đắn của toàn bộ backend hoặc chức năng app.
