# DealGo — Danh sách file Markdown cho 213 màn hình cốt lõi (+10 Merchant Portal)

> Đây là danh sách **file dự kiến tạo**, không khẳng định các file màn hình đã tồn tại. Quy ước: 1 màn hình = 1 file `.md`.
> Đồng thời, tài liệu này đối soát và **liên kết 1:1 với bộ tài nguyên thiết kế tại `design/`** (165 mockup PNG, 96 HTML prototypes, 25 UI state variants, 2 batch assets và bộ Audit Report).

## 1. Bảng thống kê phạm vi & Hiện trạng thiết kế

| Phạm vi | Nền tảng | Số màn hình | Mockup PNG (`design/`) | HTML Prototype | Biến thể UI States (Ph 19.4) | Thư mục Mockup tương ứng |
|---|---|---:|:---:|:---:|:---:|---|
| **Dùng chung** | Mobile | 28 | 28/28 (100%) | 23/28 | 5 variants (4 routes) | [`../design/mockups/screens/shared/`](../design/mockups/screens/shared/) |
| **Khách hàng** | Mobile | 48 | 48/48 (100%) | 27/48 | 12 variants (7 routes) | [`../design/mockups/screens/customer/`](../design/mockups/screens/customer/) |
| **Shop / Quán ăn** | Mobile | 44 | 44/44 (100%) | 26/44 | 4 variants (3 routes) | [`../design/mockups/screens/merchant/`](../design/mockups/screens/merchant/) |
| **Shipper / Tài xế** | Mobile | 45 | 45/45 (100%) | 20/45 | 4 variants (4 routes) | [`../design/mockups/screens/driver/`](../design/mockups/screens/driver/) |
| **Landing Page** | Web công khai | 13 | Kế hoạch UI Web | N/A | N/A | Kênh Web công khai |
| **Admin Dashboard** | Web quản trị | 35 | 35/35 (100%) | N/A | N/A | [`../design/mockups/screens/admin/`](../design/mockups/screens/admin/) |
| **Tổng cốt lõi** | **165 Mobile + 48 Web** | **213** | **200 PNG (165 Mobile + 35 Admin)** | **96 HTML (Mobile)** | **25 variants** | **6 Golden Screens Mobile** |
| **Merchant Portal** | Web đối tác — giai đoạn sau | 10 | Kế hoạch sau MVP | N/A | N/A | Kênh Web đối tác |
| **Tổng khi bổ sung Merchant Portal** | **213 + 10** | **223** | | | | |

### Định hướng triển khai

- **Mobile (165 màn hình):** **165/165 màn hình ĐÃ CÓ MOCKUP THAM CHIẾU (100%)** tại `../design/mockups/screens/` (gồm các vai trò Khách hàng, Shop/Quán ăn và Shipper/Tài xế trong cùng một app Flutter).
- **Web cốt lõi (48 trang):** 13 trang Landing Page giới thiệu DealGo và 35 trang Admin Dashboard vận hành hệ thống (Next.js 16 tại `../website/`, trong đó toàn bộ 35/35 trang Admin đã có mockup PNG độ phân giải 1600×1180 tại [`../design/mockups/screens/admin/`](../design/mockups/screens/admin/)).
- **Merchant Portal (10 trang):** Dành cho cửa hàng/quán ăn trên Web ở giai đoạn sau; không gộp vào 213 màn hình cốt lõi ban đầu.
- **Nguyên tắc phân định:** Landing Page giới thiệu dịch vụ, cách hoạt động, đối tác và ứng dụng; không triển khai luồng đặt xe/đồ ăn của app trên website.
- **Responsive & UI States:** Responsive layouts, tab, modal, dialog, bottom sheet và các trạng thái loading/empty/error không cộng thành màn hình riêng. Biến thể lỗi/chờ được quản lý qua `DealGoScreenState`.
- **6 Màn hình Golden Reference:** Ưu tiên code mẫu theo `../design/mockups/audit/03_FLUTTER_HANDOFF.md` gồm: `C001`, `C004`, `C028`, `S007`, `M013`, `D016`.

---

## 2. Tài liệu Design System & Handoff bắt buộc đọc

| Tài liệu | Đường dẫn | Nội dung chính |
|---|---|---|
| **Screen Manifest CSV** | [`../design/mockups/audit/screen_manifest.csv`](../design/mockups/audit/screen_manifest.csv) | Bảng tra cứu 165 dòng chi tiết mã, kích thước, dung lượng, sha256 và cờ HTML |
| **Audit Report v1.0** | [`../design/mockups/audit/01_AUDIT_REPORT.md`](../design/mockups/audit/01_AUDIT_REPORT.md) | Báo cáo 15 lỗi thiết kế P0/P1/P2 (lệch giá Ride C004–C011, dữ liệu liên vai trò...) |
| **Design System v0.1** | [`../design/mockups/audit/02_DESIGN_SYSTEM.md`](../design/mockups/audit/02_DESIGN_SYSTEM.md) | Design Tokens (Tím `#6D28D9`, Xanh `#16A34A`), typography, 14 shared components |
| **Flutter Handoff** | [`../design/mockups/audit/03_FLUTTER_HANDOFF.md`](../design/mockups/audit/03_FLUTTER_HANDOFF.md) | 5 bước triển khai, 6 màn Golden Reference và QA checklist |
| **Demo Fixtures & Flows** | [`../design/mockups/audit/04_DEMO_FIXTURES_AND_FLOWS.md`](../design/mockups/audit/04_DEMO_FIXTURES_AND_FLOWS.md) | 3 kịch bản dữ liệu mẫu xuyên 3 vai trò (`RIDE_CAR_001`, `RIDE_BIKE_001`, `FOOD_001`) |
| **UI States Matrix (Ph 19.4)** | [`../design/mockups/phase19_4/docs/screen_state_matrix.csv`](../design/mockups/phase19_4/docs/screen_state_matrix.csv) | 25 biến thể trạng thái UI (trigger, action, guardrail) cho 18 routes |
| **Screen Asset Map** | [`../design/assets/batch01/docs/SCREEN_ASSET_MAP.md`](../design/assets/batch01/docs/SCREEN_ASSET_MAP.md) | Ánh xạ màn hình với asset hình ảnh, xe, thẻ dịch vụ, trạng thái |
| **Flutter Asset Guide** | [`../design/assets/batch01/docs/FLUTTER_INTEGRATION.md`](../design/assets/batch01/docs/FLUTTER_INTEGRATION.md) | Hướng dẫn tích hợp thư mục asset vào Flutter `pubspec.yaml` |

---

## 3. Danh mục Chi tiết & Ma trận Liên kết Màn hình

### Dùng chung — 28 file (Mobile)

| Mã | Tên màn hình / Chức năng | Mockup PNG (`design/`) | HTML Prototype | Kích thước | UI State Variants (Ph 19.4) | Assets Ánh xạ | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|:---:|:---:|---|---|---|
| **S001** | Khởi động, kiểm tra phiên và điều hướng | [`S001.png`](../design/mockups/screens/shared/S001.png) | ✅ Có HTML | 1000×2036 | — | — | `S001-khoi-dong-kiem-tra-phien-va-dieu-huong.md` |
| **S002** | Giới thiệu DealGo (Onboarding) | [`S002.png`](../design/mockups/screens/shared/S002.png) | ✅ Có HTML | 1000×2036 | — | `role_customer`, `role_shop`, `role_driver` | `S002-gioi-thieu-dealgo-onboarding.md` |
| **S003** | Nhập số điện thoại đăng nhập / đăng ký | [`S003.png`](../design/mockups/screens/shared/S003.png) | ✅ Có HTML | 1000×2036 | — | — | `S003-nhap-so-dien-thoai-dang-nhap-dang-ky.md` |
| **S004** | Xác minh mã OTP | [`S004.png`](../design/mockups/screens/shared/S004.png) | ✅ Có HTML | 1000×2036 | [`otp_invalid`](../design/mockups/phase19_4/screens/S004__otp_invalid.png)<br>[`resend_cooldown`](../design/mockups/phase19_4/screens/S004__resend_cooldown.png) | — | `S004-xac-minh-ma-otp.md` |
| **S005** | Hoàn thiện hồ sơ cơ bản lần đầu | [`S005.png`](../design/mockups/screens/shared/S005.png) | ✅ Có HTML | 1000×2036 | — | — | `S005-hoan-thien-ho-so-co-ban-lan-dau.md` |
| **S006** | Giải thích và quản lý cấp quyền ban đầu | [`S006.png`](../design/mockups/screens/shared/S006.png) | ✅ Có HTML | 1000×2036 | — | — | `S006-giai-thich-va-quan-ly-cap-quyen-ban-dau.md` |
| ⭐ **S007** | **Trung tâm vai trò và đăng ký quyền mới** *(Golden Ref)* | [`S007.png`](../design/mockups/screens/shared/S007.png) | ✅ Có HTML | 1000×2036 | — | `role_customer`, `role_shop`, `role_driver` | `S007-trung-tam-vai-tro-va-dang-ky-quyen-moi.md` |
| **S008** | Hộp thư thông báo | [`S008.png`](../design/mockups/screens/shared/S008.png) | ✅ Có HTML | 1000×2036 | — | — | `S008-hop-thu-thong-bao.md` |
| **S009** | Danh sách cuộc trò chuyện | [`S009.png`](../design/mockups/screens/shared/S009.png) | ✅ Có HTML | 1000×2036 | — | — | `S009-danh-sach-cuoc-tro-chuyen.md` |
| **S010** | Chi tiết cuộc trò chuyện | [`S010.png`](../design/mockups/screens/shared/S010.png) | ✅ Có HTML | 1000×2036 | — | — | `S010-chi-tiet-cuoc-tro-chuyen.md` |
| **S011** | Tài khoản cá nhân | [`S011.png`](../design/mockups/screens/shared/S011.png) | ✅ Có HTML | 1000×2036 | — | — | `S011-tai-khoan-ca-nhan.md` |
| **S012** | Chỉnh sửa hồ sơ cá nhân | [`S012.png`](../design/mockups/screens/shared/S012.png) | ✅ Có HTML | 1000×2036 | — | — | `S012-chinh-sua-ho-so-ca-nhan.md` |
| **S013** | Sổ địa chỉ đã lưu | [`S013.png`](../design/mockups/screens/shared/S013.png) | ✅ Có HTML | 1000×2036 | — | — | `S013-so-dia-chi-da-luu.md` |
| **S014** | Thêm / chỉnh sửa địa chỉ đã lưu | [`S014.png`](../design/mockups/screens/shared/S014.png) | ✅ Có HTML | 1000×2036 | — | — | `S014-them-chinh-sua-dia-chi-da-luu.md` |
| **S015** | Tìm kiếm địa điểm, địa chỉ | [`S015.png`](../design/mockups/screens/shared/S015.png) | ✅ Có HTML | 1000×2036 | [`search_empty`](../design/mockups/phase19_4/screens/S015__search_empty.png) | `state_no_search`, `state_offline` | `S015-tim-kiem-dia-diem-dia-chi.md` |
| **S016** | Chọn ghim trên bản đồ | [`S016.png`](../design/mockups/screens/shared/S016.png) | ✅ Có HTML | 1000×2036 | [`location_denied`](../design/mockups/phase19_4/screens/S016__location_denied.png) | `state_no_search`, `state_offline` | `S016-chon-ghim-tren-ban-do.md` |
| **S017** | Danh sách phương thức thanh toán | [`S017.png`](../design/mockups/screens/shared/S017.png) | ✅ Có HTML | 1000×2036 | [`payment_unavailable`](../design/mockups/phase19_4/screens/S017__payment_unavailable.png) | `state_payment_error`, `state_offline` | `S017-danh-sach-phuong-thuc-thanh-toan.md` |
| **S018** | Thêm / liên kết phương thức thanh toán | [`S018.png`](../design/mockups/screens/shared/S018.png) | ✅ Có HTML | 1000×2036 | — | `state_payment_error`, `state_offline` | `S018-them-lien-ket-phuong-thuc-thanh-toan.md` |
| **S019** | Trung tâm hỗ trợ và câu hỏi thường gặp | [`S019.png`](../design/mockups/screens/shared/S019.png) | ✅ Có HTML | 1000×2036 | — | — | `S019-trung-tam-ho-tro-va-cau-hoi-thuong-gap.md` |
| **S020** | Chi tiết bài hướng dẫn trợ giúp | [`S020.png`](../design/mockups/screens/shared/S020.png) | ✅ Có HTML | 1000×2036 | — | — | `S020-chi-tiet-bai-huong-dan-tro-giup.md` |
| **S021** | Tạo yêu cầu hỗ trợ / khiếu nại | [`S021.png`](../design/mockups/screens/shared/S021.png) | ✅ Có HTML | 1000×2036 | — | — | `S021-tao-yeu-cau-ho-tro-khieu-nai.md` |
| **S022** | Danh sách yêu cầu hỗ trợ | [`S022.png`](../design/mockups/screens/shared/S022.png) | ✅ Có HTML | 1000×2036 | — | — | `S022-danh-sach-yeu-cau-ho-tro.md` |
| **S023** | Chi tiết yêu cầu và phản hồi hỗ trợ | [`S023.png`](../design/mockups/screens/shared/S023.png) | ✅ Có HTML | 1000×2036 | — | — | `S023-chi-tiet-yeu-cau-va-phan-hoi-ho-tro.md` |
| **S024** | Tùy chọn thông báo | [`S024.png`](../design/mockups/screens/shared/S024.png) | ❌ PNG only | 1000×2036 | — | — | `S024-tuy-chon-thong-bao.md` |
| **S025** | Cài đặt bảo mật và quyền riêng tư | [`S025.png`](../design/mockups/screens/shared/S025.png) | ❌ PNG only | 1000×2036 | — | — | `S025-cai-dat-bao-mat-va-quyen-rieng-tu.md` |
| **S026** | Điều khoản, chính sách & đồng ý xử lý dữ liệu | [`S026.png`](../design/mockups/screens/shared/S026.png) | ❌ PNG only | 1000×2036 | — | — | `S026-dieu-khoan-chinh-sach-dong-y-xu-ly-du-lieu.md` |
| **S027** | Yêu cầu xóa tài khoản | [`S027.png`](../design/mockups/screens/shared/S027.png) | ❌ PNG only | 1000×2036 | — | — | `S027-yeu-cau-xoa-tai-khoan.md` |
| **S028** | Thiết bị đăng nhập & phiên truy cập | [`S028.png`](../design/mockups/screens/shared/S028.png) | ❌ PNG only | 1000×2036 | — | — | `S028-thiet-bi-dang-nhap-phien-truy-cap.md` |

### Khách hàng — 48 file (Mobile)

| Mã | Tên màn hình / Chức năng | Mockup PNG (`design/`) | HTML Prototype | Kích thước | UI State Variants (Ph 19.4) | Assets Ánh xạ | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|:---:|:---:|---|---|---|
| ⭐ **C001** | **Trang chủ DealGo (Customer Home / Brand Anchor)** *(Golden Ref)* | [`C001.png`](../design/mockups/screens/customer/C001.png) | ❌ PNG only | 941×1672 | — | `banner_danang_hero`, `card_ride`, `card_food`, `banner_promo_gift` | `C001-trang-chu-dealgo.md` |
| **C002** | Bản đồ đặt xe và bắt đầu chọn hành trình | [`C002.png`](../design/mockups/screens/customer/C002.png) | ❌ PNG only | 1000×2000 | [`map_loading`](../design/mockups/phase19_4/screens/C002__map_loading.png) | `vehicle_sedan`, `vehicle_7seat`, `vehicle_motorbike`, `accent_pickup_route` | `C002-ban-do-dat-xe-va-bat-dau-chon-hanh-trinh.md` |
| **C003** | Tổng quan điểm đón, điểm đến và tuyến | [`C003.png`](../design/mockups/screens/customer/C003.png) | ❌ PNG only | 1000×2000 | — | `vehicle_sedan`, `vehicle_7seat`, `vehicle_motorbike`, `accent_pickup_route` | `C003-tong-quan-diem-don-diem-den-va-tuyen.md` |
| ⭐ **C004** | **Chọn loại phương tiện và dịch vụ** *(Golden Ref)* | [`C004.png`](../design/mockups/screens/customer/C004.png) | ❌ PNG only | 1000×2000 | — | `vehicle_sedan`, `vehicle_7seat`, `vehicle_motorbike`, `accent_pickup_route` | `C004-chon-loai-phuong-tien-va-dich-vu.md` |
| **C005** | Chi tiết giá cước, phụ phí và điều kiện | [`C005.png`](../design/mockups/screens/customer/C005.png) | ❌ PNG only | 941×1672 | — | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C005-chi-tiet-gia-cuoc-phu-phi-va-dieu-kien.md` |
| **C006** | Tự đề xuất giá chuyến (Fare Bidding) | [`C006.png`](../design/mockups/screens/customer/C006.png) | ❌ PNG only | 941×1672 | — | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C006-tu-de-xuat-gia-chuyen.md` |
| **C007** | Danh sách tài xế chào giá (Driver Offers) | [`C007.png`](../design/mockups/screens/customer/C007.png) | ❌ PNG only | 941×1672 | [`offers_empty`](../design/mockups/phase19_4/screens/C007__offers_empty.png)<br>[`quote_expired`](../design/mockups/phase19_4/screens/C007__quote_expired.png)<br>[`quote_taken`](../design/mockups/phase19_4/screens/C007__quote_taken.png) | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C007-danh-sach-tai-xe-chao-gia.md` |
| **C008** | Chi tiết báo giá và tài xế | [`C008.png`](../design/mockups/screens/customer/C008.png) | ❌ PNG only | 941×1672 | — | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C008-chi-tiet-bao-gia-va-tai-xe.md` |
| **C009** | Xác nhận chuyến và phương thức thanh toán | [`C009.png`](../design/mockups/screens/customer/C009.png) | ❌ PNG only | 941×1672 | [`fare_changed`](../design/mockups/phase19_4/screens/C009__fare_changed.png) | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C009-xac-nhan-chuyen-va-phuong-thuc-thanh-toan.md` |
| **C010** | Đang tìm tài xế (Matching) | [`C010.png`](../design/mockups/screens/customer/C010.png) | ❌ PNG only | 941×1672 | [`matching_timeout`](../design/mockups/phase19_4/screens/C010__matching_timeout.png) | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C010-dang-tim-tai-xe-matching.md` |
| **C011** | Tài xế đã nhận, đang đến đón | [`C011.png`](../design/mockups/screens/customer/C011.png) | ❌ PNG only | 941×1672 | [`tracking_offline`](../design/mockups/phase19_4/screens/C011__tracking_offline.png) | `vehicle_sedan`, `state_no_driver`, `state_quote_expired` | `C011-tai-xe-da-nhan-dang-den-don.md` |
| **C012** | Xác thực mã đón khách (Pickup OTP) | [`C012.png`](../design/mockups/screens/customer/C012.png) | ✅ Có HTML | 1000×2036 | — | — | `C012-xac-thuc-ma-don-khach.md` |
| **C013** | Bản đồ chuyến xe đang chạy | [`C013.png`](../design/mockups/screens/customer/C013.png) | ✅ Có HTML | 1000×2036 | — | `accent_pickup_route` | `C013-ban-do-chuyen-xe-dang-chay.md` |
| **C014** | Trung tâm an toàn chuyến đi | [`C014.png`](../design/mockups/screens/customer/C014.png) | ✅ Có HTML | 1000×2036 | — | — | `C014-trung-tam-an-toan-chuyen-di.md` |
| **C015** | Đổi điểm đến trong chuyến | [`C015.png`](../design/mockups/screens/customer/C015.png) | ✅ Có HTML | 1000×2036 | — | — | `C015-doi-diem-den-trong-chuyen.md` |
| **C016** | Hủy chuyến và chọn lý do | [`C016.png`](../design/mockups/screens/customer/C016.png) | ✅ Có HTML | 1000×2036 | — | — | `C016-huy-chuyen-va-chon-ly-do.md` |
| **C017** | Biên nhận sau khi kết thúc chuyến | [`C017.png`](../design/mockups/screens/customer/C017.png) | ✅ Có HTML | 1000×2036 | — | — | `C017-bien-nhan-sau-khi-ket-thuc-chuyen.md` |
| **C018** | Đánh giá & tip tài xế sau chuyến | [`C018.png`](../design/mockups/screens/customer/C018.png) | ✅ Có HTML | 1000×2036 | — | — | `C018-danh-gia-tip-tai-xe-sau-chuyen.md` |
| **C019** | Đặt xe vào thời gian khác (Scheduled Ride) | [`C019.png`](../design/mockups/screens/customer/C019.png) | ✅ Có HTML | 1000×2036 | — | — | `C019-dat-xe-vao-thoi-gian-khac.md` |
| **C020** | Thêm / đổi thứ tự điểm dừng | [`C020.png`](../design/mockups/screens/customer/C020.png) | ✅ Có HTML | 1000×2036 | — | — | `C020-them-doi-thu-tu-diem-dung.md` |
| **C021** | Chi tiết chuyến đã đặt trước | [`C021.png`](../design/mockups/screens/customer/C021.png) | ✅ Có HTML | 1000×2036 | — | — | `C021-chi-tiet-chuyen-da-dat-truoc.md` |
| **C022** | Trang khám phá đồ ăn (Food Discovery) | [`C022.png`](../design/mockups/screens/customer/C022.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C022-trang-kham-pha-do-an.md` |
| **C023** | Tìm kiếm quán, món, sản phẩm | [`C023.png`](../design/mockups/screens/customer/C023.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C023-tim-kiem-quan-mon-san-pham.md` |
| **C024** | Kết quả danh mục quán và sản phẩm | [`C024.png`](../design/mockups/screens/customer/C024.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C024-ket-qua-danh-muc-quan-va-san-pham.md` |
| **C025** | Chi tiết quán, cửa hàng và menu | [`C025.png`](../design/mockups/screens/customer/C025.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C025-chi-tiet-quan-cua-hang-va-menu.md` |
| **C026** | Chi tiết món, sản phẩm và tùy chọn | [`C026.png`](../design/mockups/screens/customer/C026.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C026-chi-tiet-mon-san-pham-va-tuy-chon.md` |
| **C027** | Giỏ hàng hiện tại | [`C027.png`](../design/mockups/screens/customer/C027.png) | ✅ Có HTML | 1000×2036 | — | `card_food`, `role_food`, `state_no_search`, photos | `C027-gio-hang-hien-tai.md` |
| ⭐ **C028** | **Checkout đơn đồ ăn / mua hàng** *(Golden Ref)* | [`C028.png`](../design/mockups/screens/customer/C028.png) | ✅ Có HTML | 1000×2036 | [`checkout_offline`](../design/mockups/phase19_4/screens/C028__checkout_offline.png)<br>[`checkout_repriced`](../design/mockups/phase19_4/screens/C028__checkout_repriced.png)<br>[`submitting`](../design/mockups/phase19_4/screens/C028__submitting.png) | `card_food`, `role_food`, `state_no_search`, photos | `C028-checkout-don-do-an-mua-hang.md` |
| **C029** | Chọn voucher áp dụng đơn | [`C029.png`](../design/mockups/screens/customer/C029.png) | ✅ Có HTML | 1000×2036 | — | — | `C029-chon-voucher-ap-dung-don.md` |
| **C030** | Đề xuất phí giao hàng (Delivery Fee Bidding) | [`C030.png`](../design/mockups/screens/customer/C030.png) | ✅ Có HTML | 1000×2036 | — | — | `C030-de-xuat-phi-giao-hang.md` |
| **C031** | Danh sách báo giá giao của tài xế | [`C031.png`](../design/mockups/screens/customer/C031.png) | ✅ Có HTML | 1000×2036 | — | — | `C031-danh-sach-bao-gia-giao-cua-tai-xe.md` |
| **C032** | Xác nhận đơn và đặt hàng thành công | [`C032.png`](../design/mockups/screens/customer/C032.png) | ❌ PNG only | 1000×2036 | — | `state_success`, `accent_promo_gift`, `state_no_orders`, photos | `C032-xac-nhan-don-va-dat-hang-thanh-cong.md` |
| **C033** | Theo dõi đơn: chuẩn bị món & đang giao | [`C033.png`](../design/mockups/screens/customer/C033.png) | ❌ PNG only | 1000×2036 | [`tracking_reconnect`](../design/mockups/phase19_4/screens/C033__tracking_reconnect.png) | `state_success`, `accent_promo_gift`, `state_no_orders`, photos | `C033-theo-doi-thuc-don-chuan-bi-dang-giao.md` |
| **C034** | Xác nhận đề nghị thay món hoặc giá | [`C034.png`](../design/mockups/screens/customer/C034.png) | ❌ PNG only | 1000×2036 | — | — | `C034-xac-nhan-de-nghi-thay-mon-hoac-gia.md` |
| **C035** | Hủy đơn và chọn lý do | [`C035.png`](../design/mockups/screens/customer/C035.png) | ❌ PNG only | 1000×2036 | — | — | `C035-huy-don-va-chon-ly-do.md` |
| **C036** | Chi tiết đơn đồ ăn / hóa đơn | [`C036.png`](../design/mockups/screens/customer/C036.png) | ❌ PNG only | 1000×2036 | — | `state_success`, `accent_promo_gift`, `state_no_orders`, photos | `C036-chi-tiet-don-do-an-hoa-don.md` |
| **C037** | Đánh giá món, quán và giao hàng | [`C037.png`](../design/mockups/screens/customer/C037.png) | ❌ PNG only | 1000×2036 | — | `state_success`, `accent_promo_gift`, `state_no_orders`, photos | `C037-danh-gia-mon-quan-va-giao-hang.md` |
| **C038** | Xem đánh giá cửa hàng và phản hồi | [`C038.png`](../design/mockups/screens/customer/C038.png) | ❌ PNG only | 1000×2036 | — | — | `C038-xem-danh-gia-cua-hang-va-phan-hoi.md` |
| **C039** | Danh sách quán / món yêu thích | [`C039.png`](../design/mockups/screens/customer/C039.png) | ❌ PNG only | 1000×2036 | — | — | `C039-danh-sach-quan-mon-yeu-thich.md` |
| **C040** | Chọn hình thức giao (tiết kiệm, nhanh, hẹn giờ) | [`C040.png`](../design/mockups/screens/customer/C040.png) | ❌ PNG only | 1000×2036 | — | — | `C040-chon-hinh-thuc-giao-tiet-kiem-nhanh-dat-truoc.md` |
| **C041** | Đơn đặt trước: xem, thay đổi, hủy lịch | [`C041.png`](../design/mockups/screens/customer/C041.png) | ❌ PNG only | 1000×2036 | — | — | `C041-don-dat-truoc-xem-thay-doi-huy-lich.md` |
| **C042** | Khám phá siêu thị / cửa hàng tiện lợi | [`C042.png`](../design/mockups/screens/customer/C042.png) | ✅ Có HTML | 1000×2036 | — | — | `C042-trang-kham-pha-sieu-thi-cua-hang-tien-loi.md` |
| **C043** | Trung tâm hoạt động: đơn và chuyến đi | [`C043.png`](../design/mockups/screens/customer/C043.png) | ✅ Có HTML | 1000×2036 | — | — | `C043-trung-tam-hoat-dong-don-va-chuyen-di.md` |
| **C044** | Ví khuyến mãi / mã giảm giá của tôi | [`C044.png`](../design/mockups/screens/customer/C044.png) | ✅ Có HTML | 1000×2036 | — | `banner_promo_gift`, `accent_promo_gift` | `C044-vi-khuyen-mai-ma-giam-gia-cua-toi.md` |
| **C045** | Chi tiết chương trình mã giảm giá | [`C045.png`](../design/mockups/screens/customer/C045.png) | ✅ Có HTML | 1000×2036 | — | — | `C045-chi-tiet-chuong-trinh-ma-giam-gia.md` |
| **C046** | Lịch sử thanh toán của khách | [`C046.png`](../design/mockups/screens/customer/C046.png) | ✅ Có HTML | 1000×2036 | — | — | `C046-lich-su-thanh-toan-cua-khach.md` |
| **C047** | Chi tiết giao dịch hoàn tiền | [`C047.png`](../design/mockups/screens/customer/C047.png) | ✅ Có HTML | 1000×2036 | — | — | `C047-chi-tiet-giao-dich-hoan-tien.md` |
| **C048** | Danh sách đơn / chuyến được đặt trước | [`C048.png`](../design/mockups/screens/customer/C048.png) | ✅ Có HTML | 1000×2036 | — | — | `C048-danh-sach-don-chuyen-duoc-dat-truoc.md` |

### Shop / Quán ăn — 44 file (Mobile)

| Mã | Tên màn hình / Chức năng | Mockup PNG (`design/`) | HTML Prototype | Kích thước | UI State Variants (Ph 19.4) | Assets Ánh xạ | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|:---:|:---:|---|---|---|
| **M001** | Giới thiệu đăng ký bán hàng | [`M001.png`](../design/mockups/screens/merchant/M001.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M001-gioi-thieu-dang-ky-ban-hang.md` |
| **M002** | Lựa chọn loại hình kinh doanh & ngành hàng | [`M002.png`](../design/mockups/screens/merchant/M002.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M002-lua-chon-loai-hinh-kinh-doanh-va-nganh-hang.md` |
| **M003** | Thông tin quán / cửa hàng & người đại diện | [`M003.png`](../design/mockups/screens/merchant/M003.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M003-thong-tin-quan-cua-hang-va-nguoi-dai-dien.md` |
| **M004** | CCCD / Hộ chiếu người đại diện | [`M004.png`](../design/mockups/screens/merchant/M004.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M004-cccd-ho-chieu-nguoi-dai-dien.md` |
| **M005** | Tài liệu kinh doanh & Mã số thuế | [`M005.png`](../design/mockups/screens/merchant/M005.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M005-tai-lieu-kinh-doanh-ma-so-thue.md` |
| **M006** | Địa chỉ kinh doanh & Điểm ghim quán | [`M006.png`](../design/mockups/screens/merchant/M006.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M006-dia-chi-kinh-doanh-va-diem-ghim-quan.md` |
| **M007** | Ảnh mặt tiền, logo và ảnh bìa | [`M007.png`](../design/mockups/screens/merchant/M007.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M007-anh-mat-tien-logo-va-anh-bia.md` |
| **M008** | Thiết lập ngân hàng nhận tiền | [`M008.png`](../design/mockups/screens/merchant/M008.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M008-thiet-lap-ngan-hang-nhan-tien.md` |
| **M009** | Ký xác nhận điều khoản hợp tác | [`M009.png`](../design/mockups/screens/merchant/M009.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M009-ky-xac-nhan-dieu-khoan-hop-tac.md` |
| **M010** | Kiểm tra hồ sơ và gửi xét duyệt | [`M010.png`](../design/mockups/screens/merchant/M010.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M010-kiem-tra-ho-so-va-gui-xet-duyet.md` |
| **M011** | Trạng thái duyệt & kích hoạt cửa hàng | [`M011.png`](../design/mockups/screens/merchant/M011.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M011-trang-thai-duyet-va-kich-hoat-cua-hang.md` |
| **M012** | Bổ sung, sửa và nộp lại hồ sơ | [`M012.png`](../design/mockups/screens/merchant/M012.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M012-bo-sung-sua-va-nop-lai-ho-so.md` |
| ⭐ **M013** | **Dashboard Shop tổng quan (Merchant Shell)** *(Golden Ref)* | [`M013.png`](../design/mockups/screens/merchant/M013.png) | ❌ PNG only | 1000×2036 | — | `role_shop`, `state_kyc_pending`, `state_kyc_rejected` | `M013-dashboard-shop-tong-quan.md` |
| **M014** | Chọn cửa hàng / chi nhánh đang quản lý | [`M014.png`](../design/mockups/screens/merchant/M014.png) | ❌ PNG only | 1000×2036 | — | — | `M014-chon-cua-hang-chi-nhanh-dang-quan-ly.md` |
| **M015** | Hàng đợi đơn mới, đang làm, đã xong | [`M015.png`](../design/mockups/screens/merchant/M015.png) | ❌ PNG only | 1000×2036 | [`queue_empty`](../design/mockups/phase19_4/screens/M015__queue_empty.png)<br>[`queue_error`](../design/mockups/phase19_4/screens/M015__queue_error.png) | `state_no_orders`, photos | `M015-hang-doi-don-moi-dang-lam-da-xong.md` |
| **M016** | Chi tiết đơn mới và quyết định xác nhận | [`M016.png`](../design/mockups/screens/merchant/M016.png) | ❌ PNG only | 1000×2036 | [`accept_conflict`](../design/mockups/phase19_4/screens/M016__accept_conflict.png) | — | `M016-chi-tiet-don-moi-va-quyet-dinh-xac-nhan.md` |
| **M017** | Danh sách bếp đang chế biến | [`M017.png`](../design/mockups/screens/merchant/M017.png) | ❌ PNG only | 1000×2036 | — | — | `M017-danh-sach-bep-dang-che-bien.md` |
| **M018** | Điều chỉnh món / giá và chờ khách duyệt | [`M018.png`](../design/mockups/screens/merchant/M018.png) | ❌ PNG only | 1000×2036 | — | — | `M018-dieu-chinh-mon-gia-va-cho-khach-duyet.md` |
| **M019** | Bàn giao đơn & đối chiếu mã tài xế | [`M019.png`](../design/mockups/screens/merchant/M019.png) | ❌ PNG only | 1000×2036 | [`handoff_code_wrong`](../design/mockups/phase19_4/screens/M019__handoff_code_wrong.png) | — | `M019-ban-giao-don-va-doi-chieu-ma-tai-xe.md` |
| **M020** | Lịch sử đơn của Shop | [`M020.png`](../design/mockups/screens/merchant/M020.png) | ❌ PNG only | 1000×2036 | — | — | `M020-lich-su-don-cua-shop.md` |
| **M021** | Chi tiết đơn hủy, bồi hoàn & xử lý tranh chấp | [`M021.png`](../design/mockups/screens/merchant/M021.png) | ❌ PNG only | 1000×2036 | — | — | `M021-chi-tiet-don-huy-boi-hoan-va-xu-ly-tranh-chap.md` |
| **M022** | Cấu hình nhận đơn tự động / thủ công | [`M022.png`](../design/mockups/screens/merchant/M022.png) | ❌ PNG only | 1000×2036 | — | — | `M022-cau-hinh-nhan-don-tu-dong-thu-cong.md` |
| **M023** | Giờ hoạt động và lịch nghỉ | [`M023.png`](../design/mockups/screens/merchant/M023.png) | ❌ PNG only | 1000×2036 | — | — | `M023-gio-hoat-dong-va-lich-nghi.md` |
| **M024** | Chế độ bận và tạm ngưng nhận đơn | [`M024.png`](../design/mockups/screens/merchant/M024.png) | ❌ PNG only | 1000×2036 | — | — | `M024-che-do-ban-va-tam-ngung-nhan-don.md` |
| **M025** | Danh sách danh mục menu & hàng hóa | [`M025.png`](../design/mockups/screens/merchant/M025.png) | ❌ PNG only | 1000×2036 | — | — | `M025-danh-sach-danh-muc-menu-va-hang-hoa.md` |
| **M026** | Danh sách sản phẩm / menu | [`M026.png`](../design/mockups/screens/merchant/M026.png) | ✅ Có HTML | 1000×2036 | — | `state_no_orders`, photos | `M026-danh-sach-san-pham-menu.md` |
| **M027** | Tạo / chỉnh sửa sản phẩm, món | [`M027.png`](../design/mockups/screens/merchant/M027.png) | ✅ Có HTML | 1000×2036 | — | — | `M027-tao-chinh-sua-san-pham-mon.md` |
| **M028** | Cấu hình biến thể, size, topping | [`M028.png`](../design/mockups/screens/merchant/M028.png) | ✅ Có HTML | 1000×2036 | — | — | `M028-cau-hinh-bien-the-size-topping.md` |
| **M029** | Tồn kho: còn / hết món & tạm ngưng bán | [`M029.png`](../design/mockups/screens/merchant/M029.png) | ✅ Có HTML | 1000×2036 | — | — | `M029-ton-kho-con-het-mon-va-tam-ngung-ban.md` |
| **M030** | Trang thông tin hồ sơ Shop | [`M030.png`](../design/mockups/screens/merchant/M030.png) | ✅ Có HTML | 1000×2036 | — | — | `M030-trang-thong-tin-ho-so-shop.md` |
| **M031** | Đánh giá và phản hồi khách hàng | [`M031.png`](../design/mockups/screens/merchant/M031.png) | ✅ Có HTML | 1000×2036 | — | — | `M031-danh-gia-va-phan-hoi-khach-hang.md` |
| **M032** | Thiết lập khu vực phục vụ & pickup | [`M032.png`](../design/mockups/screens/merchant/M032.png) | ✅ Có HTML | 1000×2036 | — | — | `M032-thiet-lap-khu-vuc-phuc-vu-pickup.md` |
| **M033** | Tổng quan doanh thu và đơn hoàn tất | [`M033.png`](../design/mockups/screens/merchant/M033.png) | ✅ Có HTML | 1000×2036 | — | — | `M033-tong-quan-doanh-thu-va-don-hoan-tat.md` |
| **M034** | Số dư tiền và công nợ Shop | [`M034.png`](../design/mockups/screens/merchant/M034.png) | ✅ Có HTML | 1000×2036 | — | — | `M034-so-du-tien-va-cong-no-shop.md` |
| **M035** | Danh sách quyết toán đối soát | [`M035.png`](../design/mockups/screens/merchant/M035.png) | ✅ Có HTML | 1000×2036 | — | — | `M035-danh-sach-quyet-toan-doi-soat.md` |
| **M036** | Chi tiết đợt quyết toán | [`M036.png`](../design/mockups/screens/merchant/M036.png) | ✅ Có HTML | 1000×2036 | — | — | `M036-chi-tiet-dot-quyet-toan.md` |
| **M037** | Ngân hàng nhận tiền & cài đặt rút | [`M037.png`](../design/mockups/screens/merchant/M037.png) | ❌ PNG only | 1000×2036 | — | — | `M037-ngan-hang-nhan-tien-va-cai-dat-rut.md` |
| **M038** | Rút tiền và lịch sử yêu cầu rút | [`M038.png`](../design/mockups/screens/merchant/M038.png) | ❌ PNG only | 1000×2036 | — | — | `M038-rut-tien-va-lich-su-yeu-cau-rut.md` |
| **M039** | Báo cáo bán hàng và vận hành | [`M039.png`](../design/mockups/screens/merchant/M039.png) | ❌ PNG only | 1000×2036 | — | — | `M039-bao-cao-ban-hang-va-van-hanh.md` |
| **M040** | Danh sách chiến dịch khuyến mãi | [`M040.png`](../design/mockups/screens/merchant/M040.png) | ❌ PNG only | 1000×2036 | — | `banner_promo_gift`, `accent_promo_gift` | `M040-danh-sach-chien-dich-khuyen-mai.md` |
| **M041** | Tạo / sửa khuyến mãi của Shop | [`M041.png`](../design/mockups/screens/merchant/M041.png) | ❌ PNG only | 1000×2036 | — | `banner_promo_gift`, `accent_promo_gift` | `M041-tao-sua-khuyen-mai-cua-shop.md` |
| **M042** | Danh sách nhân viên và cấp quyền | [`M042.png`](../design/mockups/screens/merchant/M042.png) | ❌ PNG only | 1000×2036 | — | — | `M042-danh-sach-nhan-vien-va-cap-quyen.md` |
| **M043** | Mời / sửa quyền nhân viên | [`M043.png`](../design/mockups/screens/merchant/M043.png) | ❌ PNG only | 1000×2036 | — | — | `M043-moi-sua-quyen-nhan-vien.md` |
| **M044** | Cập nhật giấy tờ hết hạn & chủ sở hữu | [`M044.png`](../design/mockups/screens/merchant/M044.png) | ❌ PNG only | 1000×2036 | — | — | `M044-cap-nhat-giay-to-het-han-chu-so-huu.md` |

### Shipper / Tài xế — 45 file (Mobile)

| Mã | Tên màn hình / Chức năng | Mockup PNG (`design/`) | HTML Prototype | Kích thước | UI State Variants (Ph 19.4) | Assets Ánh xạ | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|:---:|:---:|---|---|---|
| **D001** | Giới thiệu đăng ký đối tác tài xế | [`D001.png`](../design/mockups/screens/driver/D001.png) | ❌ PNG only | 1000×2036 | — | `role_driver`, `vehicle_delivery`, `accent_pickup_route` | `D001-gioi-thieu-dang-ky-doi-tac-tai-xe.md` |
| **D002** | Chọn dịch vụ & kiểm tra điều kiện tham gia | [`D002.png`](../design/mockups/screens/driver/D002.png) | ✅ Có HTML | 1000×2036 | — | — | `D002-chon-dich-vu-va-kiem-tra-dieu-kien-tham-gia.md` |
| **D003** | Nhập thông tin cá nhân theo giấy tờ | [`D003.png`](../design/mockups/screens/driver/D003.png) | ✅ Có HTML | 1000×2036 | — | — | `D003-nhap-thong-tin-ca-nhan-theo-giay-to.md` |
| **D004** | Chụp giấy tờ định danh mặt trước / sau | [`D004.png`](../design/mockups/screens/driver/D004.png) | ✅ Có HTML | 1000×2036 | — | — | `D004-chup-giay-to-dinh-danh-mat-truoc-sau.md` |
| **D005** | Đọc OCR và xác nhận dữ liệu cá nhân | [`D005.png`](../design/mockups/screens/driver/D005.png) | ✅ Có HTML | 1000×2036 | — | — | `D005-doc-ocr-va-xac-nhan-du-lieu-ca-nhan.md` |
| **D006** | Selfie liveness & face match | [`D006.png`](../design/mockups/screens/driver/D006.png) | ✅ Có HTML | 1000×2036 | — | — | `D006-selfie-liveness-face-match.md` |
| **D007** | Tải & xác thực Giấy phép lái xe (GPLX) | [`D007.png`](../design/mockups/screens/driver/D007.png) | ✅ Có HTML | 1000×2036 | — | — | `D007-tai-xac-thuc-giay-phep-lai-xe.md` |
| **D008** | Đăng ký loại xe & biển số phương tiện | [`D008.png`](../design/mockups/screens/driver/D008.png) | ✅ Có HTML | 1000×2036 | — | — | `D008-dang-ky-loai-xe-bien-so-phuong-tien.md` |
| **D009** | Tải giấy đăng ký xe và bảo hiểm | [`D009.png`](../design/mockups/screens/driver/D009.png) | ✅ Có HTML | 1000×2036 | — | — | `D009-tai-giay-dang-ky-xe-va-bao-hiem.md` |
| **D010** | Bổ sung hồ sơ / chứng chỉ theo loại dịch vụ | [`D010.png`](../design/mockups/screens/driver/D010.png) | ✅ Có HTML | 1000×2036 | — | — | `D010-bo-sung-ho-so-chung-chi-theo-loai-dich-vu.md` |
| **D011** | Liên kết tài khoản ngân hàng nhận thu nhập | [`D011.png`](../design/mockups/screens/driver/D011.png) | ✅ Có HTML | 1000×2036 | — | — | `D011-lien-ket-tai-khoan-ngan-hang-nhan-thu-nhap.md` |
| **D012** | Xem lại hồ sơ và gửi xét duyệt | [`D012.png`](../design/mockups/screens/driver/D012.png) | ✅ Có HTML | 1000×2036 | — | — | `D012-xem-lai-ho-so-va-gui-xet-duyet.md` |
| **D013** | Kết quả xét duyệt & tình trạng tài khoản | [`D013.png`](../design/mockups/screens/driver/D013.png) | ❌ PNG only | 1000×2036 | — | — | `D013-ket-qua-xet-duyet-tinh-trang-tai-khoan.md` |
| **D014** | Nộp lại hồ sơ sau khi bị từ chối | [`D014.png`](../design/mockups/screens/driver/D014.png) | ❌ PNG only | 1000×2036 | — | — | `D014-nop-lai-ho-so-sau-khi-bi-tu-choi.md` |
| **D015** | Giấy tờ sắp hết hạn và tái xác minh | [`D015.png`](../design/mockups/screens/driver/D015.png) | ❌ PNG only | 1000×2036 | — | — | `D015-giay-to-sap-het-han-va-tai-xac-minh.md` |
| ⭐ **D016** | **Dashboard Tài xế: Bản đồ & Online/Offline** *(Golden Ref)* | [`D016.png`](../design/mockups/screens/driver/D016.png) | ❌ PNG only | 1000×2036 | [`driver_offline`](../design/mockups/phase19_4/screens/D016__driver_offline.png)<br>[`ineligible_expired`](../design/mockups/phase19_4/screens/D016__ineligible_expired.png) | `role_driver`, `vehicle_delivery`, `accent_pickup_route` | `D016-dashboard-tai-xe-ban-do-va-online-offline.md` |
| **D017** | Chọn / bật loại dịch vụ được phép nhận | [`D017.png`](../design/mockups/screens/driver/D017.png) | ❌ PNG only | 1000×2036 | — | — | `D017-chon-bat-loai-dich-vu-duoc-phep-nhan.md` |
| **D018** | Danh sách yêu cầu đang mở (Job Feed) | [`D018.png`](../design/mockups/screens/driver/D018.png) | ❌ PNG only | 1000×2036 | [`job_taken`](../design/mockups/phase19_4/screens/D018__job_taken.png) | `state_no_driver`, `state_no_orders` | `D018-danh-sach-yeu-cau-dang-mo.md` |
| **D019** | Chi tiết yêu cầu công việc & thu nhập | [`D019.png`](../design/mockups/screens/driver/D019.png) | ❌ PNG only | 1000×2036 | — | — | `D019-chi-tiet-yeu-cau-cong-viec-va-thu-nhap.md` |
| **D020** | Báo giá / trả giá với khách (Fare Offer) | [`D020.png`](../design/mockups/screens/driver/D020.png) | ❌ PNG only | 1000×2036 | — | — | `D020-bao-gia-tra-gia-voi-khach.md` |
| **D021** | Chuyến xe đã nhận: tóm tắt & điều hướng đón | [`D021.png`](../design/mockups/screens/driver/D021.png) | ❌ PNG only | 1000×2036 | — | `role_driver`, `vehicle_delivery`, `accent_pickup_route` | `D021-chuyen-xe-da-nhan-tom-tat-va-dieu-huong-don.md` |
| **D022** | Đã đến điểm đón & quản lý thời gian chờ | [`D022.png`](../design/mockups/screens/driver/D022.png) | ✅ Có HTML | 1000×2036 | — | — | `D022-da-den-diem-don-va-quan-ly-thoi-gian-cho.md` |
| **D023** | Nhập xác minh OTP hành khách | [`D023.png`](../design/mockups/screens/driver/D023.png) | ✅ Có HTML | 1000×2036 | [`passenger_otp_wrong`](../design/mockups/phase19_4/screens/D023__passenger_otp_wrong.png) | — | `D023-nhap-xac-minh-otp-hanh-khach.md` |
| **D024** | Bản đồ điều hướng chuyến xe đang chạy | [`D024.png`](../design/mockups/screens/driver/D024.png) | ✅ Có HTML | 1000×2036 | — | — | `D024-ban-do-dieu-huong-chuyen-xe-dang-chay.md` |
| **D025** | Kết thúc chuyến & xác nhận thu tiền | [`D025.png`](../design/mockups/screens/driver/D025.png) | ✅ Có HTML | 1000×2036 | — | — | `D025-ket-thuc-chuyen-va-xac-nhan-thu-tien.md` |
| **D026** | Điều hướng tới cửa hàng lấy đơn | [`D026.png`](../design/mockups/screens/driver/D026.png) | ✅ Có HTML | 1000×2036 | — | — | `D026-dieu-huong-toi-cua-hang-lay-don.md` |
| **D027** | Đến quán chờ món và báo chậm | [`D027.png`](../design/mockups/screens/driver/D027.png) | ✅ Có HTML | 1000×2036 | — | — | `D027-den-quan-cho-mon-va-bao-cham.md` |
| **D028** | Xác nhận lấy món và số lượng gói | [`D028.png`](../design/mockups/screens/driver/D028.png) | ✅ Có HTML | 1000×2036 | — | — | `D028-xac-nhan-lay-mon-va-so-luong-goi.md` |
| **D029** | Bản đồ giao tới khách | [`D029.png`](../design/mockups/screens/driver/D029.png) | ✅ Có HTML | 1000×2036 | — | `accent_pickup_route` | `D029-ban-do-giao-toi-khach.md` |
| **D030** | Hoàn tất giao: OTP / ảnh chứng nhận | [`D030.png`](../design/mockups/screens/driver/D030.png) | ✅ Có HTML | 1000×2036 | [`cod_unconfirmed`](../design/mockups/phase19_4/screens/D030__cod_unconfirmed.png) | `state_success` | `D030-hoan-tat-giao-otp-anh-chung-nhan.md` |
| **D031** | Giao thất bại & xử lý hàng chưa giao | [`D031.png`](../design/mockups/screens/driver/D031.png) | ✅ Có HTML | 1000×2036 | — | — | `D031-giao-that-bai-va-xu-ly-hang-chua-giao.md` |
| **D032** | Công việc đang chạy & nhiệm vụ giữ chỗ | [`D032.png`](../design/mockups/screens/driver/D032.png) | ✅ Có HTML | 1000×2036 | — | — | `D032-cong-viec-dang-chay-va-cac-nhiem-vu-duoc-giu-cho.md` |
| **D033** | Lịch sử công việc tài xế | [`D033.png`](../design/mockups/screens/driver/D033.png) | ✅ Có HTML | 1000×2036 | — | `state_no_driver`, `state_no_orders` | `D033-lich-su-cong-viec-tai-xe.md` |
| **D034** | Chi tiết công việc đã hoàn tất | [`D034.png`](../design/mockups/screens/driver/D034.png) | ✅ Có HTML | 1000×2036 | — | — | `D034-chi-tiet-cong-viec-da-hoan-tat.md` |
| **D035** | Tổng quan thu nhập tài xế | [`D035.png`](../design/mockups/screens/driver/D035.png) | ✅ Có HTML | 1000×2036 | — | — | `D035-tong-quan-thu-nhap.md` |
| **D036** | Số tiền mặt COD phải đối soát | [`D036.png`](../design/mockups/screens/driver/D036.png) | ✅ Có HTML | 1000×2036 | — | — | `D036-so-tien-mat-cod-phai-doi-soat.md` |
| **D037** | Ví số dư và khoản đang xử lý | [`D037.png`](../design/mockups/screens/driver/D037.png) | ✅ Có HTML | 1000×2036 | — | — | `D037-vi-so-du-va-khoan-dang-xu-ly.md` |
| **D038** | Rút tiền và chọn khoản nhận | [`D038.png`](../design/mockups/screens/driver/D038.png) | ✅ Có HTML | 1000×2036 | — | — | `D038-rut-tien-va-chon-khoan-nhan.md` |
| **D039** | Lịch sử rút tiền & chi tiết thanh toán | [`D039.png`](../design/mockups/screens/driver/D039.png) | ✅ Có HTML | 1000×2036 | — | — | `D039-lich-su-rut-tien-chi-tiet-thanh-toan.md` |
| **D040** | Hồ sơ tài xế & phương tiện đang hoạt động | [`D040.png`](../design/mockups/screens/driver/D040.png) | ✅ Có HTML | 1000×2036 | — | — | `D040-ho-so-tai-xe-va-phuong-tien-dang-hoat-dong.md` |
| **D041** | Thêm / đổi phương tiện và nộp giấy tờ | [`D041.png`](../design/mockups/screens/driver/D041.png) | ✅ Có HTML | 1000×2036 | — | — | `D041-them-doi-phuong-tien-va-nop-giay-to.md` |
| **D042** | Khu vực nhận đơn và tùy chọn ca làm | [`D042.png`](../design/mockups/screens/driver/D042.png) | ✅ Có HTML | 1000×2036 | — | — | `D042-khu-vuc-nhan-don-va-tuy-chon-ca-lam.md` |
| **D043** | Điểm đánh giá và hiệu quả hoạt động | [`D043.png`](../design/mockups/screens/driver/D043.png) | ✅ Có HTML | 1000×2036 | — | — | `D043-diem-danh-gia-va-hieu-qua-hoat-dong.md` |
| **D044** | Trung tâm an toàn tài xế (SOS) | [`D044.png`](../design/mockups/screens/driver/D044.png) | ✅ Có HTML | 1000×2036 | — | `state_security` | `D044-trung-tam-an-toan-tai-xe.md` |
| **D045** | Hướng dẫn hoạt động và khóa đào tạo | [`D045.png`](../design/mockups/screens/driver/D045.png) | ✅ Có HTML | 1000×2036 | — | — | `D045-huong-dan-hoat-dong-va-khoa-dao-tao.md` |

### Landing Page — 13 file (Web công khai)

> **Ghi chú Landing Page:** Giới thiệu dịch vụ di chuyển, ẩm thực, cách hoạt động và thu hút đối tác. Không bao gồm các luồng thực hiện giao dịch của ứng dụng.

| Mã | Tên trang / Chức năng | Kênh triển khai | Trạng thái thiết kế (`design/`) | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|---|---|
| **L001** | Trang chủ DealGo (Landing Page) | Web công khai | Kế hoạch UI Web công khai | `L001-trang-chu-dealgo.md` |
| **L002** | Giới thiệu dịch vụ đặt xe | Web công khai | Kế hoạch UI Web công khai | `L002-gioi-thieu-dich-vu-dat-xe.md` |
| **L003** | Giới thiệu dịch vụ đồ ăn | Web công khai | Kế hoạch UI Web công khai | `L003-gioi-thieu-dich-vu-do-an.md` |
| **L004** | Giới thiệu dịch vụ giao hàng | Web công khai | Kế hoạch UI Web công khai | `L004-gioi-thieu-dich-vu-giao-hang.md` |
| **L005** | DealGo hoạt động như thế nào | Web công khai | Kế hoạch UI Web công khai | `L005-dealgo-hoat-dong-nhu-the-nao.md` |
| **L006** | Trở thành tài xế DealGo | Web công khai | Kế hoạch UI Web công khai | `L006-tro-thanh-tai-xe-dealgo.md` |
| **L007** | Trở thành đối tác nhà hàng / cửa hàng | Web công khai | Kế hoạch UI Web công khai | `L007-tro-thanh-doi-tac-nha-hang-cua-hang.md` |
| **L008** | Về DealGo | Web công khai | Kế hoạch UI Web công khai | `L008-ve-dealgo.md` |
| **L009** | Trung tâm trợ giúp & FAQ | Web công khai | Kế hoạch UI Web công khai | `L009-trung-tam-tro-giup-faq.md` |
| **L010** | Liên hệ | Web công khai | Kế hoạch UI Web công khai | `L010-lien-he.md` |
| **L011** | Tải ứng dụng DealGo | Web công khai | Kế hoạch UI Web công khai | `L011-tai-ung-dung-dealgo.md` |
| **L012** | Điều khoản sử dụng | Web công khai | Kế hoạch UI Web công khai | `L012-dieu-khoan-su-dung.md` |
| **L013** | Chính sách quyền riêng tư | Web công khai | Kế hoạch UI Web công khai | `L013-chinh-sach-quyen-rieng-tu.md` |

### Admin Dashboard — 35 file (Web quản trị)

> **Ghi chú Admin Dashboard:** Kênh vận hành nội bộ trên Next.js 16 (`../website/`), phục vụ nhân sự vận hành giám sát, duyệt hồ sơ KYC/KYB và xử lý sự cố.

| Mã | Tên trang / Chức năng | Mockup PNG (`design/`) | Kích thước | Kênh triển khai | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|:---:|:---:|---|
| **A001** | Đăng nhập quản trị | [`A001_dang_nhap_quan_tri.png`](../design/mockups/screens/admin/A001_dang_nhap_quan_tri.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A001-dang-nhap-quan-tri.md` |
| **A002** | Quên và đặt lại mật khẩu | [`A002_quen_va_dat_lai_mat_khau.png`](../design/mockups/screens/admin/A002_quen_va_dat_lai_mat_khau.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A002-quen-va-dat-lai-mat-khau.md` |
| **A003** | Dashboard tổng quan | [`A003_dashboard_tong_quan.png`](../design/mockups/screens/admin/A003_dashboard_tong_quan.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A003-dashboard-tong-quan.md` |
| **A004** | Giám sát vận hành trực tiếp | [`A004_giam_sat_van_hanh_truc_tiep.png`](../design/mockups/screens/admin/A004_giam_sat_van_hanh_truc_tiep.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A004-giam-sat-van-hanh-truc-tiep.md` |
| **A005** | Danh sách chuyến xe | [`A005_danh_sach_chuyen_xe.png`](../design/mockups/screens/admin/A005_danh_sach_chuyen_xe.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A005-danh-sach-chuyen-xe.md` |
| **A006** | Chi tiết chuyến xe | [`A006_chi_tiet_chuyen_xe.png`](../design/mockups/screens/admin/A006_chi_tiet_chuyen_xe.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A006-chi-tiet-chuyen-xe.md` |
| **A007** | Danh sách phiên trả giá | [`A007_danh_sach_phien_tra_gia.png`](../design/mockups/screens/admin/A007_danh_sach_phien_tra_gia.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A007-danh-sach-phien-tra-gia.md` |
| **A008** | Chi tiết phiên trả giá | [`A008_chi_tiet_phien_tra_gia.png`](../design/mockups/screens/admin/A008_chi_tiet_phien_tra_gia.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A008-chi-tiet-phien-tra-gia.md` |
| **A009** | Danh sách đơn đồ ăn | [`A009_danh_sach_don_do_an.png`](../design/mockups/screens/admin/A009_danh_sach_don_do_an.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A009-danh-sach-don-do-an.md` |
| **A010** | Chi tiết đơn đồ ăn | [`A010_chi_tiet_don_do_an.png`](../design/mockups/screens/admin/A010_chi_tiet_don_do_an.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A010-chi-tiet-don-do-an.md` |
| **A011** | Danh sách đơn giao hàng | [`A011_danh_sach_don_giao_hang.png`](../design/mockups/screens/admin/A011_danh_sach_don_giao_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A011-danh-sach-don-giao-hang.md` |
| **A012** | Chi tiết đơn giao hàng | [`A012_chi_tiet_don_giao_hang.png`](../design/mockups/screens/admin/A012_chi_tiet_don_giao_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A012-chi-tiet-don-giao-hang.md` |
| **A013** | Danh sách yêu cầu dịch vụ A/C | [`A013_danh_sach_yeu_cau_dich_vu_a_c.png`](../design/mockups/screens/admin/A013_danh_sach_yeu_cau_dich_vu_a_c.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A013-danh-sach-yeu-cau-dich-vu-a-c.md` |
| **A014** | Chi tiết yêu cầu dịch vụ A/C | [`A014_chi_tiet_yeu_cau_dich_vu_a_c.png`](../design/mockups/screens/admin/A014_chi_tiet_yeu_cau_dich_vu_a_c.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A014-chi-tiet-yeu-cau-dich-vu-a-c.md` |
| **A015** | Danh sách khách hàng | [`A015_danh_sach_khach_hang.png`](../design/mockups/screens/admin/A015_danh_sach_khach_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A015-danh-sach-khach-hang.md` |
| **A016** | Chi tiết khách hàng | [`A016_chi_tiet_khach_hang.png`](../design/mockups/screens/admin/A016_chi_tiet_khach_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A016-chi-tiet-khach-hang.md` |
| **A017** | Danh sách tài xế | [`A017_danh_sach_tai_xe.png`](../design/mockups/screens/admin/A017_danh_sach_tai_xe.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A017-danh-sach-tai-xe.md` |
| **A018** | Chi tiết tài xế | [`A018_chi_tiet_tai_xe.png`](../design/mockups/screens/admin/A018_chi_tiet_tai_xe.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A018-chi-tiet-tai-xe.md` |
| **A019** | Duyệt hồ sơ KYC tài xế | [`A019_duyet_ho_so_kyc_tai_xe.png`](../design/mockups/screens/admin/A019_duyet_ho_so_kyc_tai_xe.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A019-duyet-ho-so-kyc-tai-xe.md` |
| **A020** | Danh sách cửa hàng | [`A020_danh_sach_cua_hang.png`](../design/mockups/screens/admin/A020_danh_sach_cua_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A020-danh-sach-cua-hang.md` |
| **A021** | Chi tiết cửa hàng | [`A021_chi_tiet_cua_hang.png`](../design/mockups/screens/admin/A021_chi_tiet_cua_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A021-chi-tiet-cua-hang.md` |
| **A022** | Duyệt hồ sơ cửa hàng | [`A022_duyet_ho_so_cua_hang.png`](../design/mockups/screens/admin/A022_duyet_ho_so_cua_hang.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A022-duyet-ho-so-cua-hang.md` |
| **A023** | Kiểm duyệt sản phẩm và thực đơn | [`A023_kiem_duyet_san_pham_va_thuc_don.png`](../design/mockups/screens/admin/A023_kiem_duyet_san_pham_va_thuc_don.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A023-kiem-duyet-san-pham-va-thuc-don.md` |
| **A024** | Danh sách giao dịch | [`A024_danh_sach_giao_dich.png`](../design/mockups/screens/admin/A024_danh_sach_giao_dich.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A024-danh-sach-giao-dich.md` |
| **A025** | Đối soát và thanh toán đối tác | [`A025_doi_soat_va_thanh_toan_doi_tac.png`](../design/mockups/screens/admin/A025_doi_soat_va_thanh_toan_doi_tac.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A025-doi-soat-va-thanh-toan-doi-tac.md` |
| **A026** | Xử lý hoàn tiền | [`A026_xu_ly_hoan_tien.png`](../design/mockups/screens/admin/A026_xu_ly_hoan_tien.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A026-xu-ly-hoan-tien.md` |
| **A027** | Danh sách khiếu nại và tranh chấp | [`A027_danh_sach_khieu_nai_va_tranh_chap.png`](../design/mockups/screens/admin/A027_danh_sach_khieu_nai_va_tranh_chap.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A027-danh-sach-khieu-nai-va-tranh-chap.md` |
| **A028** | Chi tiết xử lý khiếu nại & tranh chấp | [`A028_chi_tiet_xu_ly_khieu_nai_tranh_chap.png`](../design/mockups/screens/admin/A028_chi_tiet_xu_ly_khieu_nai_tranh_chap.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A028-chi-tiet-xu-ly-khieu-nai-tranh-chap.md` |
| **A029** | Quản lý khuyến mãi | [`A029_quan_ly_khuyen_mai.png`](../design/mockups/screens/admin/A029_quan_ly_khuyen_mai.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A029-quan-ly-khuyen-mai.md` |
| **A030** | Quản lý danh mục | [`A030_quan_ly_danh_muc.png`](../design/mockups/screens/admin/A030_quan_ly_danh_muc.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A030-quan-ly-danh-muc.md` |
| **A031** | Thông báo và CMS | [`A031_thong_bao_va_cms.png`](../design/mockups/screens/admin/A031_thong_bao_va_cms.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A031-thong-bao-va-cms.md` |
| **A032** | Thống kê và phân tích | [`A032_thong_ke_va_phan_tich.png`](../design/mockups/screens/admin/A032_thong_ke_va_phan_tich.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A032-thong-ke-va-phan-tich.md` |
| **A033** | Khu vực hoạt động và quy tắc giá | [`A033_khu_vuc_hoat_dong_va_quy_tac_gia.png`](../design/mockups/screens/admin/A033_khu_vuc_hoat_dong_va_quy_tac_gia.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A033-khu-vuc-hoat-dong-va-quy-tac-gia.md` |
| **A034** | Nhân sự và phân quyền | [`A034_nhan_su_va_phan_quyen.png`](../design/mockups/screens/admin/A034_nhan_su_va_phan_quyen.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A034-nhan-su-va-phan-quyen.md` |
| **A035** | Cấu hình và nhật ký hệ thống | [`A035_cau_hinh_va_nhat_ky_he_thong.png`](../design/mockups/screens/admin/A035_cau_hinh_va_nhat_ky_he_thong.png) | 1600×1180 | Web quản trị (Scaffold tại [`website/app/`](../website/app/)) | `A035-cau-hinh-va-nhat-ky-he-thong.md` |

### Merchant Portal — 10 file (Web đối tác — giai đoạn sau)

> **Ghi chú Merchant Portal:** Kênh web bổ trợ cho cửa hàng quản lý thực đơn và đối soát trên màn hình lớn; nằm ở giai đoạn sau (không gộp vào 213 màn cốt lõi).

| Mã | Tên trang / Chức năng | Kênh triển khai | Trạng thái thiết kế (`design/`) | File MD dự kiến (`docs/screens/`) |
|:---:|---|:---:|---|---|
| **P001** | Đăng nhập cửa hàng | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P001-dang-nhap-cua-hang.md` |
| **P002** | Tổng quan cửa hàng | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P002-tong-quan-cua-hang.md` |
| **P003** | Danh sách đơn hàng | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P003-danh-sach-don-hang.md` |
| **P004** | Chi tiết và xử lý đơn hàng | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P004-chi-tiet-va-xu-ly-don-hang.md` |
| **P005** | Quản lý thực đơn và sản phẩm | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P005-quan-ly-thuc-don-va-san-pham.md` |
| **P006** | Thêm và chỉnh sửa món / sản phẩm | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P006-them-va-chinh-sua-mon-san-pham.md` |
| **P007** | Quản lý khuyến mãi | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P007-quan-ly-khuyen-mai.md` |
| **P008** | Doanh thu và đối soát | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P008-doanh-thu-va-doi-soat.md` |
| **P009** | Nhân viên và phân quyền | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P009-nhan-vien-va-phan-quyen.md` |
| **P010** | Hồ sơ và cài đặt cửa hàng | Web đối tác | Kế hoạch sau MVP (Web đối tác) | `P010-ho-so-va-cai-dat-cua-hang.md` |

---

## 4. Hướng dẫn sử dụng ma trận này cho AI Agents & Developers

1. **Tra cứu Mockup gốc:** Khi xây dựng giao diện cho màn hình Mobile bất kỳ, bấm trực tiếp vào cột **Mockup PNG** để xem file ảnh thiết kế độ phân giải cao.
2. **Kiểm tra trạng thái lỗi/rỗng (Edge Cases):** Trước khi code, kiểm tra cột **UI State Variants (Ph 19.4)**. Nếu màn hình có biến thể trạng thái (ví dụ OTP sai, hết hạn quote, mất mạng), bắt buộc phải xử lý state tương ứng theo `DealGoScreenState`.
3. **Sử dụng đúng Asset:** Tra cứu cột **Assets Ánh xạ** để chọn đúng hình ảnh minh họa, icon phương tiện trong `design/assets/batch01/` thay vì dùng placeholder tự tạo.
4. **Ưu tiên 6 Golden Reference:** Triển khai theo thứ tự ưu tiên: hoàn thiện 6 màn Golden trước (`C001`, `C004`, `C028`, `S007`, `M013`, `D016`) để đóng băng token và component dùng chung trước khi nhân rộng ra các màn còn lại.
5. **Quy tắc liên kết tài liệu:** Danh mục này là tài liệu kiểm kê tham chiếu. Đặc tả chi tiết hành vi và nghiệp vụ từng màn hình sẽ được hợp nhất vào kế hoạch nhóm `04-experience/` theo chuẩn Governance tại [`00-governance/README.md`](00-governance/README.md#04--experience-6-tệp).
