# Changelog

Thay đổi đáng chú ý cho người vận hành, mới nhất ở trên.

## 2026-10-27

### Đổi
- **Vào thẳng trang chủ, không chọn vai trò.** Đăng ký/đăng nhập xong là vào trang chủ khách hàng, kể cả tài khoản
  vừa là tài xế hay cửa hàng. Đổi vai trò ở Trang cá nhân › Vai trò; đăng ký làm tài xế / mở cửa hàng cũng ở Trang cá nhân
  (`DEC-PROD-065`).

### Thêm
- **Google Maps là nhà cung cấp bản đồ thứ hai.** Admin › Cài đặt › Bản đồ (`/settings/maps`) chọn Mapbox hoặc Google
  cho tìm địa chỉ, địa chỉ từ vị trí, và lộ trình/quãng đường tính cước (khoá `MAPS_SEARCH_PROVIDER`,
  `MAPS_REVERSE_PROVIDER`, `MAPS_ROUTE_PROVIDER`, mặc định `mapbox`, có audit).
  Cần `GOOGLE_MAPS_API_KEY` (Places API (New), Geocoding API, Routes API) trong `backend.env`; trống thì Google bị khoá trong Admin.
  Google lỗi → tự dùng Mapbox. App hiện ghi chú "Google Maps" dưới kết quả tìm từ Google.
  Chi phí, đánh đổi và lưu ý điều khoản: [places-search.md](../05-architecture/places-search.md).
