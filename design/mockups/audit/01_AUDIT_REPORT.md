# DealGo — Báo cáo UI/UX Consistency Audit v1.0

**Baseline:** trang chủ C001 đã chốt; Screen Inventory v2.0; 165 ảnh mobile tìm được trong thư mục làm việc. 12 contact sheets đi kèm để kiểm tra trực quan. Ngày đánh giá: 12/10/2026.

## A. Kết luận điều hành

- **Coverage ảnh:** 165/165 màn theo ID (100%). **Coverage nguồn HTML theo ID:** 96/165 (58,2%). **Flutter implementation/tested:** chưa được xác minh.
- **Rủi ro lớn nhất không nằm ở số lượng ảnh** mà là tính chính xác giá/báo giá, dữ liệu liên vai trò, sai khác style giữa nhóm ảnh đầu tiên và các nhóm dựng HTML, kích cỡ chữ và UI state còn thiếu.
- 3 họ kích thước ảnh khác nhau: 154 (1000×2036), 3 (1000×2000), 8 (941×1672). Sự khác kích thước ảnh là dấu hiệu nguồn mockup khác nhau, **không tự động chứng minh lỗi responsive**.
- C001 có hình ảnh hero, minh họa, chất liệu và phân cấp trực quan rõ; nhiều màn về sau đơn giản, density và header khác. Cần quyết định chuẩn **"app interior"** cho màn tính năng, không bê nguyên hero quảng cáo vào tác nghiệp.

## B. Danh sách lỗi ưu tiên

| ID | Ưu tiên | Màn tiêu biểu | Phát hiện / rủi ro | Tiêu chí nghiệm thu |
|---|---|---|---|---|
| UI-001 | **P0** | C004–C011 | Cùng chuỗi lựa chọn xe → báo giá → xác nhận → tìm xe đang có các số minh họa **42.000đ / 108.000đ / 63.000đ / 72.000đ / 42.000đ** giữa các màn; thiếu giải thích snapshot hoặc quote reprice. | `acceptedQuoteId`, `fareVersion`, các thành phần phí và `amountPayable` từ cùng một fixture; mọi thay đổi sau chốt cần màn consent và ghi phiên bản. |
| UI-002 | **P0** | C007–C011, D019–D025 | Các tên tài xế, loại xe/biển số và mức giá mẫu không tạo thành **một hành trình xuyên vai trò** dễ đối chiếu; tài xế Honda Vision và đơn xe 4 chỗ không được gộp thành cùng ride. | Phân biệt kịch bản xe máy và ô tô; mỗi demo ride dùng một `rideId` xuyên tất cả màn, customer/driver trùng driver, xe, biển số, loại dịch vụ, giá đã chốt. |
| UI-003 | **P0** | C027–C036, M016–M019, D026–D030 | Thông tin đơn và tiền trong mỗi vai trò đang được trình bày thành nhiều bộ ví dụ; chưa có test chứng minh cùng một `orderId`, items, replacement, phí giao, COD, payout nhất quán. | Một fixture đồ ăn E2E có snapshot giá được đọc chung; các công thức kiểm tra bằng test; amount shop, shipper, customer liên kết ledger. |
| UI-004 | **P0** | S018, C028/C009, D036–D039, M034–M038 | Mockup tài chính phải làm rõ ai là người **thực nhận** tiền và thời điểm xác nhận; tránh đánh đồng tiền thu hộ với thu nhập hoặc coi thanh toán hoàn tất khi chưa có xác nhận backend. | State machine payment/COD/payout rõ ràng; UI chỉ hiển thị `success` từ trạng thái backend xác thực; phí/hoàn tiền dùng cùng transaction ID. |
| UI-005 | **P0** | D004–D015, M004–M012 | KYC/KYB có đủ màn hình cơ bản nhưng chưa có bộ trạng thái hoàn chỉnh cho ảnh mờ, giấy tờ hết hạn, từ chối, yêu cầu sửa, sai khuôn mặt/điều kiện loại dịch vụ. | Mỗi bước có `not_started/in_progress/needs_action/pending/approved/rejected/expired`; loại dịch vụ không đủ điều kiện bị khóa và có lý do rõ. |
| UI-006 | **P1** | C001–C011 vs C012+, các màn S/M/D | Nhiều nguồn thiết kế khác hệ tỷ lệ/tiêu đề/chi tiết; đặc biệt nhóm ảnh C005–C011 được dựng theo phong cách khác các màn dựng HTML sau này. | Dùng token/nhóm component trong tài liệu 02; so golden screen cho header, typography, card, CTA và bottom nav. |
| UI-007 | **P1** | Toàn bộ | Kích thước ảnh 3 nhóm; 8 ảnh chưa đặt tên chuẩn ngay tại thư mục bộ màn. | Manifest 165/165; tất cả file output normalized `ID_name.png`; thiết kế theo logical dp và kiểm tra 360/390/430dp. |
| UI-008 | **P1** | Các màn có HTML | Nhiều class HTML dùng font-size **10–12px** cho label/meta; nguy cơ khó đọc khi thu về máy 360–390dp. | Không chuyển CSS px thành dp 1:1; secondary text khuyến nghị >=12sp, body 14–16sp, textScale 1.0/1.3/1.6 không che CTA. |
| UI-009 | **P1** | C001, C022, S011, M013, D016 | Logo/headline, sự xuất hiện bottom navigation và cách dùng nav phụ khác nhau giữa mode; nguy cơ các role trông như app tách rời. | Logo asset chuẩn; shell role-specific có tên/điều hướng rõ; thiết kế thống nhất thanh chính, back, sheet và hành động cố định. |
| UI-010 | **P1** | C001, C004, C042 | Banner trang chủ nói **Giao hàng** nhưng Screen Inventory v2 chưa tính **gửi kiện độc lập**; cần tránh khiến khách hiểu có tính năng chưa triển khai. | Chốt copy "Giao món"/"Mua hàng giao tận nơi" hoặc thêm nhánh sản phẩm X01–X06 trước khi quảng bá gửi đồ riêng. |
| UI-011 | **P1** | Toàn bộ 165 | 165 ảnh là happy path và một số nhánh xử lý, chưa thành ma trận loading/empty/error/offline/permission/expired/dispute hoàn chỉnh. | State matrix theo tài liệu 03, golden tests cho mỗi nhóm; không tăng route chỉ vì state/sheet. |
| UI-012 | **P1** | S007, M013, D016 | Ba role trong một app nhưng các thông báo/việc đang chạy khi đổi mode chưa được định nghĩa đầy đủ trong giao diện. | Chuyển mode không hủy chuyến/đơn/ca ngầm; notification deep link mở đúng role và đúng quyền ở server. |
| UI-013 | **P1** | C009, C035, D031, M021, D044 | Các thao tác hủy, tranh chấp, báo cáo sự cố và trợ giúp khẩn phải có UX xác nhận/hậu quả rõ, không chỉ có nút màu. | Mẫu confirm + reason code + phí hủy, hỗ trợ và timeline + an toàn ưu tiên số liên hệ hợp lệ. |
| UI-014 | **P2** | Toàn bộ | Minh họa/avatar/thương hiệu thay đổi giữa ảnh, một số screenshot có placeholder và dữ liệu cá nhân giống thật. | Asset registry; chỉ dữ liệu mẫu vô danh hoặc synthetic; không dùng hồ sơ KYC thật trong bản demo; kiểm soát license. |
| UI-015 | **P2** | Toàn bộ | `html` mô phỏng phone frame cố định, border/notch/status bar nằm trong nội dung HTML; không thể sử dụng như layout production. | Triển khai Flutter không render mockup dưới dạng ảnh/HTML; SafeArea thực, keyboard inset, scroll, semantics, adaptive. |

**P0**: ảnh hưởng sự đúng đắn của hành trình, tiền, an toàn hoặc quyền truy cập — cần sửa trước pilot. **P1**: lệch hệ thống, accessibility, state, dễ gây nhầm — cần sửa trước UI freeze. **P2**: tối ưu chất lượng và bàn giao.

## C. Nhận xét theo nhóm màn

### C: Khách hàng (48)

- Hero trang chủ C001 là **brand anchor**, song các màn thao tác nhanh nên gọn, không sao chép banner hero sang route sâu.
- Ride C002–C011: ưu tiên thiết kế lại một **chuỗi đầy đủ** từ chọn xe, chốt giá đến chuyến đang chạy; không tạo mỗi ảnh như một câu chuyện độc lập.
- Food C022–C042: các lựa chọn món/size/topping phải được giữ thành **snapshot** trong giỏ, checkout, hóa đơn, bồi hoàn; thay món chỉ có hiệu lực khi khách đồng ý.
- C043–C048: phân định rõ `Đơn hàng/chuyến`, `Giao dịch thanh toán`, `Voucher` — một mục lịch sử không nên đại diện cho tất cả nghiệp vụ.

### S: Dùng chung (28)

- Các bước S003–S006 cần ưu tiên OTP hết hạn, nhập sai, đổi số điện thoại, từ chối permission, khởi chạy lại app.
- S007: mode chuyển đổi là **chuyển góc nhìn và quyền thao tác**, không phải thay user và không gián đoạn dịch vụ ngầm.
- S009–S010: chat chỉ mở từ ngữ cảnh giao dịch hợp lệ; nếu transaction đã hết hạn phải có thông báo/giới hạn phù hợp.
- S017–S018: liên kết thanh toán qua nhà cung cấp token hóa; không lấy ảnh nhập thẻ thô làm yêu cầu backend tự giữ PAN/CVV.

### M: Shop (44)

- M015–M024 là lõi vận hành: trạng thái món/bếp, hủy, tài xế nhận và thời gian chuẩn bị phải đồng nhất theo `order status`.
- M026–M029: option groups, availability, stock, ẩn/hiện món cần phân định; không để menu hiển thị món không thể đặt.
- M033–M039: giải thích riêng `gross sales`, refunds, fees, pending, available, cash collected, payout.

### D: Tài xế (45)

- D002–D015: eligibility theo service (chở khách và giao món), phương tiện/giấy tờ ảnh hưởng quyền online.
- D016–D025: báo giá có thời hạn, chỉ một job active theo chính sách, bắt đầu chuyến yêu cầu xác minh OTP thực.
- D026–D031: bàn giao shop-driver, xác nhận giao/ảnh/OTP và tình huống giao thất bại cần giữ bằng chứng có kiểm soát.
- D032–D045: không coi COD là tiền lương; phân biệt số dư khả dụng/cần đối soát/đang xử lý, và kiểm tra khu vực trước bật nhận việc.

## D. Quy trình nghiệm thu trước khi giao cho Flutter Agent

1. **Freeze dữ liệu mẫu:** Ride ô tô, Ride xe máy, Food COD, Food online, Food thay món/hủy; test số tiền từng giao dịch.
2. **Freeze token/Navigation:** duyệt trang C001 + shell Khách/Shop/Tài xế + 1 màn form + 1 màn bản đồ + 1 màn bảng dữ liệu.
3. **Chuẩn hóa 165 ID, assets, states** và kiểm tra `screen_manifest.csv`.
4. **Implement 6 golden references** trên Flutter thay vì code 165 màn một lần: C001, C004, C028, M013, D016, S007.
5. Golden trên nhiều kích thước/text scales; test route/state và permission trước khi nhân rộng.

## E. Giới hạn audit

Phần lớn kết luận được rút từ kiểm tra 165 ảnh và mẫu HTML theo mã; đây là **audit tĩnh**, không phải kiểm thử app, không chứng nhận accessibility WCAG hay xác minh backend. Những màu/token đề xuất không phải mã màu gốc được xác nhận bởi designer. Các screenshot ngoại lệ nằm ngoài `dealgo_mockups/` được xác định bằng manifest, không tự coi ảnh tìm trên web là tài sản DealGo.
