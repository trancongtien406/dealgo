# Changelog

Thay đổi đáng chú ý cho người vận hành, mới nhất ở trên.

## 2026-10-27

### Đổi
- **Mở app không còn màn trắng.** Từ lúc chạm biểu tượng đến trang đầu tiên chỉ có một màn: nền tím DealGo (máy để chế độ tối thì tím đậm)
  với biểu tượng DealGo ở giữa, trên cả iOS và Android (kể cả Android 12+). Bỏ màn chào thứ hai có ảnh minh hoạ và thanh chạy
  cùng thời gian chờ tối thiểu 1,5 giây: app vào thẳng trang chủ / đăng nhập ngay khi khôi phục phiên xong (`DEC-PROD-066`).
- **Banner trang chủ chỉ còn ảnh.** Bỏ tiêu đề/mô tả/nút chữ: banner là một ảnh 2:1 (khuyên dùng 1200×600, tối đa 2 MB),
  chữ nếu cần thì thiết kế sẵn trong ảnh. Form báo khi ảnh lệch tỉ lệ 2:1. Migration
  `20261114090000_home_banner_image_only_region_fk` xoá các cột chữ. App bản cũ bỏ qua banner không có tiêu đề, nên cần cập nhật app để thấy banner.
- **Banner chọn khu vực từ Quản lý khu vực.** Ô "Khu vực" của banner lấy từ danh sách vùng phục vụ (`service_regions`, khoá ngoại),
  không còn danh sách cứng riêng. Một banner nhắm một khu vực hoặc mọi khu vực.
- **Form thêm/sửa khu vực thông minh hơn** (Admin › Khu vực & Giá). Chọn tỉnh/thành → tự điền tên, mã gợi ý (bỏ dấu, không trùng),
  tâm và khung mặc định; hoặc tìm địa điểm để đặt tâm. Kéo góc/kéo giữa khung trên bản đồ để chỉnh vùng, hoặc "Vẽ lại vùng".
  Báo chồng lấn với vùng khác (chỉ cảnh báo). Thêm nút "Sửa tên / vùng trên bản đồ" cho vùng đã có. Kiểm tra cuối cùng vẫn ở backend.
  Endpoint mới `GET /v1/ops/places/search` (quyền `zones.write`) cho ô tìm địa điểm.
- **Vào thẳng trang chủ, không chọn vai trò.** Đăng ký/đăng nhập xong là vào trang chủ khách hàng, kể cả tài khoản
  vừa là tài xế hay cửa hàng. Đổi vai trò ở Trang cá nhân › Vai trò; đăng ký làm tài xế / mở cửa hàng cũng ở Trang cá nhân
  (`DEC-PROD-065`).

### Sửa
- **Bản đồ Admin không còn báo "API KEY REQUIRED".** Nút đổi kiểu bản đồ không còn dùng nền CARTO (CARTO giờ đòi API key)
  mà chỉ dùng Mapbox: Tự động (sáng/tối theo giao diện), Đường phố, Vệ tinh, Tối, cùng OpenStreetMap. Kiểu đã chọn được
  nhớ giữa các trang bản đồ. Thiếu `NEXT_PUBLIC_MAPBOX_TOKEN` thì bản đồ dùng OpenStreetMap và nút đổi kiểu bị khoá.

### Thêm
- **Google Maps là nhà cung cấp bản đồ thứ hai.** Admin › Cài đặt › Bản đồ (`/settings/maps`) chọn Mapbox hoặc Google
  cho tìm địa chỉ, địa chỉ từ vị trí, và lộ trình/quãng đường tính cước (khoá `MAPS_SEARCH_PROVIDER`,
  `MAPS_REVERSE_PROVIDER`, `MAPS_ROUTE_PROVIDER`, mặc định `mapbox`, có audit).
  Cần `GOOGLE_MAPS_API_KEY` (Places API (New), Geocoding API, Routes API) trong `backend.env`; trống thì Google bị khoá trong Admin.
  Google lỗi → tự dùng Mapbox. App hiện ghi chú "Google Maps" dưới kết quả tìm từ Google.
  Chi phí, đánh đổi và lưu ý điều khoản: [places-search.md](../05-architecture/places-search.md).
