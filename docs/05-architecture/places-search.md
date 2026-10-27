---
doc_id: ARCH-PLACES-SEARCH
title: "Tìm địa điểm và lịch sử tìm kiếm"
status: "CURRENT"
owner: "Tech Lead"
last_updated: "2026-10-27"
related: [ADR-006]
---

# Tìm địa điểm và lịch sử tìm kiếm

## Luồng tìm kiếm (`GET /v1/places/search`)

- App gọi sau khi người dùng ngừng gõ 350 ms, chỉ khi chuỗi có từ 2 ký tự; gửi kèm `lat`/`lng` để ưu tiên gần.
  Điểm ưu tiên là vị trí hiện tại, hoặc điểm đón khi chọn điểm đến trên màn đặt xe.
- Server (`PlacesService.search`):
  1. Tách số nhà khỏi tên đường (`12 Nguyễn Hoàng` → số `12`, đường `Nguyễn Hoàng`).
  2. Lấy ứng viên từ nhà cung cấp Admin chọn (Mapbox hoặc Google, xem dưới; giới hạn Việt Nam, proximity) và, nếu `PLACES_OSM_SEARCH_URL` được đặt,
     từ Photon/OSM: trước hết trong hộp ~50 km quanh điểm ưu tiên; chỉ tìm toàn Việt Nam khi lượt đó không có kết quả khớp chữ (timeout 2,5 s; lỗi → bỏ qua).
  3. Xếp hạng lại (`place-ranking.ts`): theo tầng khoảng cách (≤20 km, ≤80 km, ≤300 km, xa hơn) — thành phố hiện tại trước —
     rồi điểm khớp chữ (không phân biệt dấu), rồi khoảng cách. Gộp trùng cùng tên trong ~500 m (hoặc ~2,5 km cùng phường).
  4. Khi có số nhà mà nhà cung cấp chỉ trả về con đường, server tạo dòng `12 Nguyễn Hoàng, <phường>` gắn `approximate: true`;
     app hiển thị "Số nhà ước tính · kiểm tra ghim".
  5. Trả `{ items: [{ lat, lng, name, address, provider, distanceKm?, approximate? }], available, attribution? }`.
- Cache câu trả lời theo chuỗi đã bỏ dấu + ô ~1 km (2 chữ số thập phân), 500 mục, TTL 10 phút.
  Giữ ngắn vì điều khoản Mapbox không cho lưu kết quả geocoding tạm thời.

## Hai nhà cung cấp: Mapbox và Google Maps

Admin chọn nhà cung cấp cho từng chức năng ở **Cài đặt › Bản đồ** (`/settings/maps`, quyền `settings.write`, có lý do và audit):

| Chức năng | Khoá | Mapbox (mặc định) | Google |
|---|---|---|---|
| Tìm địa chỉ | `MAPS_SEARCH_PROVIDER` | Mapbox Search (`MAPS_PROVIDER`) | Places API (New): Autocomplete rồi Place Details (chỉ trường `location`) cho tối đa 5 gợi ý |
| Địa chỉ từ vị trí | `MAPS_REVERSE_PROVIDER` | Mapbox reverse geocoding | Geocoding API |
| Lộ trình & quãng đường tính cước | `MAPS_ROUTE_PROVIDER` | theo env `ROUTING_PROVIDER` | Routes API `computeRoutes`, `TRAFFIC_UNAWARE` |

- `GOOGLE_MAPS_API_KEY` (chỉ ở server) trống → `GET /v1/ops/maps-providers` trả `googleConfigured: false`, Admin khoá nút Google,
  `PATCH` giá trị `google` bị từ chối `MAPS_PROVIDER_NOT_CONFIGURED`, mọi chức năng chạy Mapbox.
- Google lỗi/hết hạn mức/không có kết quả (`UnavailableMapsError`) → tự dùng Mapbox (và Photon nếu có) cho lượt đó.
- Đổi lựa chọn có hiệu lực sau ≤5 s (cache tham số). Cache tìm kiếm/địa chỉ/lộ trình có nhà cung cấp trong khoá nên không lẫn kết quả.
- Ưu tiên thành phố hiện tại, số nhà ước tính, lịch sử tìm kiếm giữ nguyên với cả hai nhà cung cấp (Google nhận `locationBias` bán kính 50 km).
- **Không trộn nguồn:** khi Google trả kết quả, server không gộp Photon/OSM vào cùng danh sách và gắn `attribution: "google"`;
  app hiện chữ "Google Maps" (12sp, `#5E5E5E`, không dịch) dưới danh sách kết quả. Photon chỉ dùng khi Google không trả gì.
- Bản đồ nền trong app và Admin vẫn là Mapbox/OSM; không đổi được sang Google (cần `google_maps_flutter`/Map Tiles API).

### Chi phí và đánh đổi (giá niêm yết Google, 2026; mỗi SKU có hạn mức miễn phí hằng tháng)

| SKU Google | Giá / 1.000 lượt | Ghi chú |
|---|---|---|
| Autocomplete Requests | ~2,83 USD | mỗi lượt gõ (sau debounce 350 ms, cache 10 phút) |
| Place Details Essentials (IDs Only/Location) | ~5 USD | tối đa 5 lần mỗi lượt tìm; cache theo `placeId` 24 giờ |
| Geocoding | ~5 USD | mỗi lần thả ghim (cache ô ~11 m, 1 giờ) |
| Routes: Compute Routes Essentials | ~5 USD | mỗi lộ trình (cache 10 phút) |

- Một lượt tìm có thể tốn tới 1 Autocomplete + 5 Details; nên Google đắt hơn Mapbox nhiều lần ở chức năng tìm địa chỉ.
  Khuyến nghị: giữ Mapbox mặc định, bật Google từng chức năng khi cần (ví dụ chỉ tìm địa chỉ ở VN), đặt hạn mức/cảnh báo ngân sách trong Google Cloud.
- Google thường đủ số nhà/tên đường ở Việt Nam hơn Mapbox; Mapbox rẻ hơn và cho phép bản đồ nền cùng nguồn.
- **Điều khoản:** Google Maps Platform yêu cầu kết quả Places và lộ trình hiển thị trên bản đồ thì phải là bản đồ Google.
  App đang vẽ trên nền Mapbox và chỉ ghi chú "Google Maps" — owner cần xem lại điều khoản trước khi bật Google lâu dài.

## Photon/OSM: tuỳ chọn, tự host cho production

- `PLACES_OSM_SEARCH_URL` **không bắt buộc**. Trống → tính năng chỉ dùng Mapbox (vẫn có xếp hạng lại, số nhà ước tính).
- Production: tự host [Photon](https://github.com/komoot/photon) với dữ liệu trích Việt Nam
  (index Photon build từ bản trích OSM `vietnam-latest` của Geofabrik; Photon cần Java 17+, ~2–4 GB RAM cho VN).
  Ví dụ trong cùng mạng Docker: `PLACES_OSM_SEARCH_URL=http://photon:2322`. Cập nhật index định kỳ (ví dụ hằng tháng).
- Endpoint công khai `https://photon.komoot.io` có giới hạn fair-use, không dành cho traffic production — chỉ dùng khi dev.
  Không đặt nó làm giá trị mặc định ở bất kỳ môi trường nào.
- Dữ liệu OSM theo giấy phép ODbL: hiển thị ghi công "© OpenStreetMap contributors" khi dùng kết quả OSM.

## Lịch sử tìm kiếm (`/v1/me/place-history`)

| Phương thức | Đường dẫn | Mô tả |
|---|---|---|
| GET | `/v1/me/place-history` | `{ items: [{ id, name, address, lat, lng, lastUsedAt }] }`, mới nhất trước, tối đa 20 |
| POST | `/v1/me/place-history` | Body `{ name, address?, lat, lng }`; cùng địa điểm (tên bỏ dấu + toạ độ 3 chữ số) thì đưa lên đầu; giữ 20 dòng/người |
| DELETE | `/v1/me/place-history/:id` | Xoá một dòng của chính người dùng (404 nếu không phải của mình) |
| DELETE | `/v1/me/place-history` | Xoá hết |

- Bảo vệ bằng `CustomerSessionGuard`; bảng `PlaceSearchHistory` (unique theo người dùng + khoá gộp trùng).
- Chỉ lưu địa điểm người dùng đã chọn (không lưu danh sách kết quả của nhà cung cấp). Địa điểm đã lưu (Nhà/Công ty) và "vị trí hiện tại" không ghi vào lịch sử.
- App: cache cục bộ (`SharedPreferences` key `dealgo.placeHistory.v1`) hiện ngay, rồi làm mới từ server; xoá khi đăng xuất.
  Hiện ở mục "Gần đây" của màn "Bạn muốn đi đâu" (xoá từng dòng, "Xóa hết" có xác nhận) và trong ô tìm kiếm của màn chọn trên bản đồ (5 dòng khi ô trống).
