---
doc_id: DG-AI-010
title: "DealGo — Screen inventory (design ↔ routes)"
version: "2.2.0"
status: "ACTIVE"
owner: "UI Designer"
last_updated: "2026-10-26"
related:
  - ../DealGo_MD_File_List.md
  - ../01-product/product-requirements.md
  - ../00-governance/decisions-and-assumptions.md
  - ui-mock-first-strategy.md
  - design-system-mobile-handoff.md
---

# Screen inventory — design mockups ↔ implementation

> **Sources audited against code:**
> mobile routes in `mobile/lib/app/router/app_router.dart` + `features/**/utils/*_routes.dart` + `shell/presentation/account_routes.dart`;
> Admin routes in `website/app/**/page.tsx` and the `/api/ops/*` BFF → Nest `v1/ops/*` controllers.
> Mockups: `design/mockups/screens/{customer,driver,merchant,admin,shared}` (C001–C048, D001–D045, M001–M044, A001–A035, S001–S028).
> Every live route below reads/writes Nest; fake clients exist only in tests and when `USE_MOCK_DATA` is set.
> **Do not invent fees or OPEN-* policies** from mockup copy (illustrative prices are design fixtures).

## Status legend

| Status | Meaning |
|---|---|
| `LIVE` | Route + page wired to the real backend (read and, where the screen acts, write) |
| `PARTIAL` | Live, but a part of the mockup is not built (noted) |
| `FOLDED` | Covered as a step/section of another live screen, not its own route |
| `DEFERRED` | Not built on purpose (non-MVP or needs a policy) — reason in Notes |
| `MISSING` | Not built and not deliberately deferred (open gap) |

## Platform facts that apply to many rows

- **Maps:** `MapPort` — `TileMapPort` (flutter_map; Mapbox raster from the Admin public token in `GET /v1/public/client-config`, then `MAPS_API_KEY`, or `MAP_TILE_URL` override) when configured, otherwise `PlaceholderMapView` chrome. The token is resolved under the launch splash (cached token used at once and refreshed in the background; first launch waits ≤ 3 s), held in `MapPortSource` (a `ValueNotifier`), and every map screen watches it, so a token that arrives or changes later rebuilds open maps. With a Mapbox source the user picks a map style (Chuẩn `streets-v12` / Vệ tinh `satellite-streets-v12` / Tối `dark-v11`) from a compact layers button; the choice is saved (`map_style` pref) and applies to every live map, switching only the tile URL (attribution adds © Maxar for satellite). A custom `MAP_TILE_URL` has a single look and shows no switcher. Admin monitor/detail maps read `NEXT_PUBLIC_MAPBOX_TOKEN` only for tiles (no hardcoded token) and fall back to the non-map view (DEC-PROD-031/032); road routes come from Nest `GET /v1/ops/routing/route` (`ROUTING_PROVIDER`, straight line when unconfigured, DEC-PROD-045).
- **Live updates:** driver location is **pushed** via Socket.IO `ride-location:`/`food-location:` rooms (REST snapshot only on open/reconnect, DEC-PROD-031); status and offers via `ride:`/`food:` snapshot rooms — no offer polling. Driver GPS cadence follows the server policy per mode (client default before the first reply: 15 s / 50 m / 60 s keep-alive). Markers: pickup dot, dropoff pin, top-down vehicle icon per class rotated by heading (`core/maps/map_markers.dart`).
- **Payments:** cash only at launch. Platform fees on cash jobs become driver debt (Admin driver detail, `DRIVER_DEBT_LIMIT_VND`); merchants pay commission per closed settlement period (Admin store detail). No card/wallet/payout rails.
- **Uploads:** KYC/KYB documents are sent as base64 in the partner application and served to Ops via `GET /v1/ops/partner-applications/:id/documents/:index`.

---

## 1. Customer — C001–C048

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| C001 | Trang chủ DealGo (Golden) | `/customer` | LIVE | Home search; **one “Đặt xe” entry** (class chosen inside the flow, `DG-DEC-VEH-001`) + Food; stores from Nest |
| C002 | Bản đồ đặt xe / chọn hành trình | `/customer/book` | LIVE | `RideMapPage`; map-first + draggable bottom sheet; round back button top-left (pops, or returns to Home when the tab is the root) and Android/iOS system back do the same; recenter + map-style buttons top-right; place search; A→B Mapbox route line |
| C003 | Tổng quan điểm đón/đến & tuyến | `/customer/ride/route` | LIVE | Server quote (distance/duration) |
| C004 | Chọn loại phương tiện (Golden) | `/customer/ride/vehicle` | FOLDED | Hot path picks class (MOTORBIKE / CAR_4 / CAR_7) inside C006 fare sheet; standalone route kept (`app_router.dart:344`). MOTORBIKE + CAR catalog (`DG-DEC-VEH-001`); customer must pick `vehicleClassCode`; priced from server quote / class knobs (OPEN-003 Car tariffs still OPEN) |
| C005 | Chi tiết giá cước / điều kiện | `/customer/ride/fare-detail` | LIVE | From the server quote; prices first if opened without one |
| C006 | Tự đề xuất giá chuyến | `/customer/ride/fare` | LIVE | Fare bid within server bounds; round map back button (`MapBackOverlay`) |
| C007 | Danh sách tài xế chào giá | `/customer/ride/offers/:rideId` | LIVE | Sort, match/counter chips; empty/expired/taken states |
| C008 | Chi tiết báo giá và tài xế | `/customer/ride/offers/:rideId/detail` | LIVE | Real driver card (rating, vehicle) |
| C009 | Xác nhận chuyến & thanh toán | `/customer/ride/confirm/:rideId` | LIVE | `C009__fare_changed`; COD |
| C010 | Đang tìm tài xế | `/customer/ride/matching/:rideId` | LIVE | Timeout state; round map back button in every state (`ride-matching-back`, keeps the ride) |
| C011 | Tài xế đã nhận, đang đến đón | `/customer/ride/tracking/:rideId` | LIVE | Driver location on map; offline state; transaction chat sheet |
| C012 | Xác thực mã đón khách | `/customer/ride/tracking/:rideId/pickup-code` | LIVE | Server pickup code |
| C013 | Bản đồ chuyến đang chạy | `/customer/ride/tracking/:rideId` | LIVE | Same route as C011 (IN_TRIP phase) |
| C014 | Trung tâm an toàn chuyến đi | `/customer/ride/tracking/:rideId/safety` | PARTIAL | Public share link (`/chia-se-chuyen/[token]` on web) sent via the system share sheet (`share_plus`; falls back to copy; `ride-safety-copy` copies; link reused until <1 min from expiry) + local emergency contacts; **no SOS backend** |
| C015 | Đổi điểm đến trong chuyến | — | DEFERRED | Needs re-pricing policy for negotiated fares |
| C016 | Hủy chuyến & chọn lý do | `/customer/ride/cancel/:rideId` | LIVE | No invented cancel fee |
| C017 | Biên nhận sau chuyến | `/customer/ride/receipt/:rideId` | LIVE | Includes rating card |
| C018 | Đánh giá & tip tài xế | `/customer/ride/receipt/:rideId` | LIVE | Rating (`RateServiceCard`); tip removed from scope (DEC-PROD-035) |
| C019 | Đặt xe theo lịch | — | DEFERRED | P2 scheduled booking |
| C020 | Thêm / đổi điểm dừng | — | DEFERRED | P2 multi-stop |
| C021 | Chi tiết chuyến đặt trước | — | DEFERRED | P2 with C019 |
| C022 | Khám phá đồ ăn | `/customer/shop` | LIVE | Image-only categories + stores from Nest; store cards show rating (count), km, ETA, fee or green "Miễn phí giao", offer pill, min order, featured dish with struck-through original price |
| C023 | Tìm kiếm quán / món | `/customer/food/search` | LIVE | |
| C024 | Kết quả danh mục | `/customer/food/category?category=<code>` | LIVE | Categories from `GET /v1/public/food-categories` (DEC-PROD-067) |
| C025 | Chi tiết quán & menu | `/customer/food/stores/:storeId` | LIVE | Open/closed/busy from store settings; hero + logo, address, today's hours, rating/ETA/sold chips, min order, "Khách khen" tags, merchant cover + description, ticket-style offers strip with "Dùng"/"Đã dùng" and "Xem tất cả" sheet, floating cart bar (count, total, shortfall/saving, "Xem giỏ hàng"), pinned tabs, menu section chips, best sellers, "Bán chạy"/"Mới" badges, original price struck through, in-store search (DEC-PROD-068) |
| C026 | Chi tiết món & tùy chọn | `/customer/food/stores/:storeId/items/:itemId` | LIVE | Real option groups/prices (DEC-PROD-033); cart bar above the add button when the cart has items (DEC-PROD-068) |
| C027 | Giỏ hàng | `/customer/food/cart` | LIVE | Lines keyed by options; ETA; min-order shortfall blocks checkout (DEC-PROD-068) |
| C028 | Checkout đơn đồ ăn (Golden) | `/customer/food/checkout` | LIVE | Server pricing, voucher code, COD; offline/repriced/submitting states |
| C029 | Chọn voucher | `/customer/account/vouchers` + checkout "Ưu đãi của tôi" sheet | LIVE | List from `GET /v1/promotions/available` (FOOD) plus the store's offers; ticket cards with full conditions, best pick, estimated saving and "Dùng"/"Đã dùng"; code field kept |
| C030 | Đề xuất phí giao hàng | — | DEFERRED | Food delivery fee is server-priced, no fee bidding |
| C031 | Báo giá giao của tài xế | — | DEFERRED | With C030 |
| C032 | Đặt hàng thành công | `/customer/food/order-success` | LIVE | |
| C033 | Theo dõi đơn Food | `/customer/food/orders/:orderId` | LIVE | Reconnect state; driver location; delivery code while on the way (DEC-PROD-036) |
| C034 | Xác nhận thay món / giá | `/customer/food/orders/:orderId` | FOLDED | Order-change card on tracking: accept or cancel within `FOOD_ORDER_CHANGE_RESPONSE_MINUTES` |
| C035 | Hủy đơn & chọn lý do | `/customer/food/orders/:orderId/cancel` | LIVE | |
| C036 | Chi tiết đơn / hóa đơn Food | `/customer/food/orders/:orderId/invoice` | LIVE | Option lines; rating card |
| C037 | Đánh giá món / quán / giao | `/customer/food/orders/:orderId/invoice` | LIVE | Store stars + driver stars + comment (`RateServiceCard`); no per-dish score |
| C038 | Xem đánh giá cửa hàng | `/customer/food/stores/:storeId` (Reviews tab) | LIVE | `GET /v1/ratings/stores/:storeId/reviews` paged, star filter, 1–5 distribution, merchant replies (DEC-PROD-068) |
| C039 | Quán / món yêu thích | — | DEFERRED | P1 |
| C040 | Hình thức giao (tiết kiệm/nhanh/hẹn) | — | DEFERRED | Needs delivery-tier policy |
| C041 | Đơn đặt trước Food | — | DEFERRED | P2 |
| C042 | Siêu thị / tiện lợi | — | DEFERRED | Non-MVP vertical |
| C043 | Trung tâm hoạt động | `/customer/trips` | LIVE | Rides + food orders |
| C044 | Ví khuyến mãi | `/customer/account/vouchers` | PARTIAL | Same vouchers list as C029; no points/wallet |
| C045 | Chi tiết chương trình KM | — | DEFERRED | P1 promo detail |
| C046 | Lịch sử thanh toán | `/customer/account/payments` | LIVE | From real finished rides/delivered orders (COD) |
| C047 | Chi tiết hoàn tiền | — | DEFERRED | COD only — no customer-side refunds yet; Ops sees `/refunds` |
| C048 | Danh sách đơn/chuyến đặt trước | — | DEFERRED | P2 |

**Customer:** LIVE 31 · PARTIAL 2 · FOLDED 2 · DEFERRED 13 · MISSING 0.

---

## 2. Driver — D001–D045

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| D001 | Giới thiệu đăng ký tài xế | `/driver/kyc/intro` | LIVE | |
| D002 | Chọn dịch vụ & điều kiện | `/driver/kyc/steps` | FOLDED | Step `services` |
| D003 | Thông tin cá nhân | `/driver/kyc/steps` | FOLDED | Step `personal` |
| D004 | Chụp CCCD | `/driver/kyc/steps` | FOLDED | Step `identity`; real photo upload |
| D005 | OCR xác nhận dữ liệu | `/driver/kyc/steps` | PARTIAL | Step `ocrConfirm`: manual ID number confirm — **no OCR engine** |
| D006 | Selfie / liveness | `/driver/kyc/steps` | PARTIAL | Selfie photo; **no liveness check** |
| D007 | GPLX | `/driver/kyc/steps` | FOLDED | Step `license` |
| D008 | Loại xe & biển số | `/driver/kyc/steps` | FOLDED | Step `vehicle` |
| D009 | Đăng ký xe & bảo hiểm | `/driver/kyc/steps` | FOLDED | In `vehicle` step |
| D010 | Hồ sơ theo loại dịch vụ | `/driver/kyc/steps` | FOLDED | In `services` step |
| D011 | Liên kết ngân hàng | `/driver/kyc/steps` | FOLDED | Step `bank` (account stored for settlement, no bank API) |
| D012 | Xem lại & gửi duyệt | `/driver/kyc/steps` | LIVE | Submits partner application |
| D013 | Kết quả xét duyệt | `/driver/kyc/status` | LIVE | |
| D014 | Nộp lại sau từ chối | `/driver/kyc/rejected` | LIVE | |
| D015 | Giấy tờ hết hạn / tái xác minh | — | DEFERRED | No document-expiry tracking in backend yet |
| D016 | Dashboard Tài xế (Golden) | `/driver` | LIVE | Real today/7-day jobs + earnings + rating; duty toggle |
| D017 | Bật loại dịch vụ được nhận | `/driver/services` | LIVE | Saved to driver presence (DEC-PROD-023) |
| D018 | Job feed yêu cầu mở | `/driver/jobs` | LIVE | Rides + ready food orders in radius; `D018__job_taken` |
| D019 | Chi tiết yêu cầu & thu nhập | `/driver/rides/:rideId`, `/driver/food/:orderId` | LIVE | Server fields only |
| D020 | Báo giá / trả giá với khách | `/driver/rides/:rideId/offer` | LIVE | |
| D021 | Chuyến đã nhận / điều hướng đón | `/driver/rides/:rideId/active` | LIVE | MapPort map with Đón/Đến pins + "Điều hướng" sheet (DEC-PROD-035) |
| D022 | Đã đến điểm đón / chờ | `/driver/rides/:rideId/active` | LIVE | |
| D023 | Nhập OTP hành khách | `/driver/rides/:rideId/otp` | LIVE | Server-verified code |
| D024 | Bản đồ chuyến đang chạy | `/driver/rides/:rideId/active` | LIVE | MapPort map (13a; was a static box) + nav hand-off to dropoff |
| D025 | Kết thúc chuyến / thu tiền | `/driver/rides/:rideId/active` | LIVE | COD |
| D026 | Điều hướng tới quán lấy đơn | `/driver/food/:orderId` | LIVE | Map from the order's pickup snapshot (DEC-PROD-034) with Quán/Giao pins + "Điều hướng" sheet |
| D027 | Đến quán chờ món | `/driver/food/:orderId` | LIVE | |
| D028 | Xác nhận lấy món | `/driver/food/:orderId` | LIVE | Server pickup |
| D029 | Bản đồ giao tới khách | `/driver/food/:orderId` | LIVE | Same map, dropoff focus |
| D030 | Hoàn tất giao OTP / ảnh | `/driver/food/:orderId` | LIVE | COD confirm from server total; server-issued **delivery code** asked when `FOOD_DELIVERY_CODE_REQUIRED` (default on, DEC-PROD-036); no proof photo by decision |
| D031 | Giao thất bại | `/driver/jobs/failed/:jobId` | LIVE | Reason → server `FAILED` |
| D032 | Công việc đang chạy / giữ chỗ | `/driver/jobs` | FOLDED | Active job resumes from the feed; no separate list |
| D033 | Lịch sử công việc | `/driver/earnings` | LIVE | History list + filters |
| D034 | Chi tiết công việc đã xong | `/driver/jobs/completed/:jobId` | LIVE | |
| D035 | Tổng quan thu nhập | `/driver/earnings` | LIVE | Today / 7 days (UTC+7 days) |
| D036 | COD phải đối soát | — | DEFERRED | Driver wallet/ledger UI; Ops reconciles in `/settlements` |
| D037 | Ví số dư | — | DEFERRED | Wallet (CAP-P2) |
| D038 | Rút tiền | — | DEFERRED | Wallet |
| D039 | Lịch sử rút tiền | — | DEFERRED | Wallet |
| D040 | Hồ sơ tài xế & phương tiện | `/driver/account` | PARTIAL | Account + real notification inbox; vehicle read from KYC; no profile edit |
| D041 | Thêm / đổi phương tiện | — | DEFERRED | Needs re-KYC flow |
| D042 | Khu vực nhận đơn & ca làm | `/driver/services` | PARTIAL | Services/duty only; no shift/area preferences |
| D043 | Điểm đánh giá & hiệu quả | `/driver` | PARTIAL | Rating on dashboard; completion rate only on Admin (DEC-PROD-034) |
| D044 | Trung tâm an toàn tài xế (SOS) | — | DEFERRED | No SOS backend (same as C014) |
| D045 | Hướng dẫn & đào tạo | — | DEFERRED | Content not provided |

**Driver:** LIVE 23 · PARTIAL 5 · FOLDED 9 · DEFERRED 8 · MISSING 0.

---

## 3. Merchant — M001–M044

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| M001 | Giới thiệu đăng ký bán hàng | `/merchant/kyb/intro` | LIVE | |
| M002 | Loại hình / ngành hàng | `/merchant/kyb/steps` | FOLDED | Step `businessType` |
| M003 | Thông tin quán & đại diện | `/merchant/kyb/steps` | FOLDED | Steps `shopInfo`, `representative` |
| M004 | CCCD / hộ chiếu | `/merchant/kyb/steps` | FOLDED | Step `documents` |
| M005 | Tài liệu KD & MST | `/merchant/kyb/steps` | FOLDED | Step `documents` |
| M006 | Địa chỉ & ghim quán | `/merchant/kyb/steps` | FOLDED | In `shopInfo`; store point drives food pickup |
| M007 | Ảnh mặt tiền / logo / bìa | `/merchant/kyb/steps` | FOLDED | Photos in `documents` |
| M008 | Ngân hàng nhận tiền | — | DEFERRED | No payout rails (settled by Ops) |
| M009 | Điều khoản hợp tác | `/merchant/kyb/steps` | FOLDED | Accepted on `review` |
| M010 | Kiểm tra & gửi duyệt | `/merchant/kyb/steps` | LIVE | |
| M011 | Trạng thái duyệt | `/merchant/kyb/status` | LIVE | |
| M012 | Bổ sung / nộp lại | `/merchant/kyb/rejected` | LIVE | |
| M013 | Dashboard Shop (Golden) | `/merchant` | LIVE | Store logo + rating, queue with item thumbnails, today stats with icons |
| M014 | Chọn cửa hàng / chi nhánh | — | DEFERRED | P1 multi-branch |
| M015 | Hàng đợi đơn (Golden) | `/merchant/orders` | LIVE | Empty/error states |
| M016 | Chi tiết đơn & xác nhận | `/merchant/orders/:orderId` | LIVE | Accept/reject, option lines; conflict state |
| M017 | Bếp đang chế biến | `/merchant/orders` | FOLDED | "Preparing" section + kitchen lines; mark ready |
| M018 | Điều chỉnh món / giá | `/merchant/orders/:orderId` | FOLDED | Order-change sheet (out of stock / quantity), customer confirms (C034) |
| M019 | Bàn giao & mã tài xế | `/merchant/orders/:orderId` | LIVE | Server **handover code** shown while ASSIGNED; driver enters it at pickup when `FOOD_HANDOVER_CODE_REQUIRED` (default off, DEC-PROD-036) |
| M020 | Lịch sử đơn Shop | `/merchant/history` | LIVE | Finished orders + filters/search (DEC-PROD-039) |
| M021 | Đơn hủy / bồi hoàn / tranh chấp | — | DEFERRED | Ops `/disputes`, `/refunds` |
| M022 | Cấu hình nhận đơn auto/manual | `/merchant/settings/accept` | LIVE | Enforced at checkout (DEC-PROD-028) |
| M023 | Giờ hoạt động / lịch nghỉ | `/merchant/settings/hours` | LIVE | DEC-PROD-027 |
| M024 | Chế độ bận / tạm ngưng | `/merchant/settings/busy` | LIVE | DEC-PROD-026/028 |
| M025 | Danh mục menu | `/merchant/products/categories` | LIVE | CRUD + DnD reorder (DEC-PROD-040) + search filter (DEC-PROD-042) |
| M026 | Danh sách sản phẩm / menu | `/merchant/products` | LIVE | Search + filter tabs All/On sale/Hidden + soldCount (DEC-PROD-042); price with struck-through original price |
| M027 | Tạo / sửa món | `/merchant/products/:itemId/edit` | LIVE | Edit fields (039) incl. original price (068); photo upload (040); gallery up to MENU_ITEM_MAX_IMAGES + draft/hidden badge + soldCount (042) |
| M028 | Biến thể / size / topping | `/merchant/products/:itemId/variants` | LIVE | Real option groups (DEC-PROD-033) |
| M029 | Tồn kho còn/hết | `/merchant/products` | LIVE | Availability toggle (no stock counts by design) |
| M030 | Hồ sơ Shop | `/merchant/account`, `/merchant/settings/profile`, `/merchant/settings/location` | LIVE | Store name + logo upload/remove (DEC-PROD-045); cover photo upload/remove and description (DEC-PROD-068); store category picker (DEC-PROD-067); minimum order (DEC-PROD-068); store pickup location (DEC-PROD-044) |
| M031 | Đánh giá & phản hồi | `/merchant/reviews` | LIVE | Review list + public reply / remove reply (DEC-PROD-068) |
| M032 | Khu vực phục vụ & pickup | — | DEFERRED | Pickup point from KYB; service radius is platform-wide |
| M033 | Doanh thu & đơn hoàn tất | `/merchant/stats` | LIVE | Real stats |
| M034 | Số dư & công nợ | — | DEFERRED | Partner wallet |
| M035 | Quyết toán đối soát | — | DEFERRED | Ops `/settlements` |
| M036 | Chi tiết đợt quyết toán | — | DEFERRED | Ops |
| M037 | Ngân hàng & rút | — | DEFERRED | Wallet |
| M038 | Rút tiền & lịch sử | — | DEFERRED | Wallet |
| M039 | Báo cáo bán hàng | `/merchant/stats` | PARTIAL | Same as M033; no export |
| M040 | Chiến dịch khuyến mãi Shop | `/merchant/offers` | LIVE | Store offers as ticket cards: conditions, usage, dates, pause/resume/end (DEC-PROD-068) |
| M041 | Tạo / sửa khuyến mãi Shop | `/merchant/offers/new` | LIVE | Create percent / fixed offer; no edit after create (DEC-PROD-068) |
| M042 | Nhân viên & cấp quyền | — | DEFERRED | Multi-staff |
| M043 | Mời / sửa quyền nhân viên | — | DEFERRED | Multi-staff |
| M044 | Cập nhật giấy tờ hết hạn | — | DEFERRED | Same as D015 |

**Merchant:** LIVE 18 · PARTIAL 3 · FOLDED 9 · DEFERRED 14 · MISSING 0.

---

## 4. Admin — A001–A035 (website)

All pages read Nest through the `/api/ops/*` BFF; none renders fixtures.

| Design id | Title | Website route | Status | Notes |
|---|---|---|---|---|
| A001 | Đăng nhập quản trị | `/login` | LIVE | Ops session cookie |
| A002 | Quên / đặt lại mật khẩu | `/login/forgot` | LIVE | "Liên hệ quản trị viên" guidance (DEC-PROD-036); super-admin resets from A034 |
| A003 | Dashboard tổng quan (Golden) | `/overview` | LIVE | `GET /v1/ops/overview` |
| A004 | Giám sát vận hành trực tiếp | `/monitor`, `/exceptions` | LIVE | Snapshot + exceptions; map needs Mapbox token |
| A005 | Danh sách chuyến xe | `/rides` | LIVE | |
| A006 | Chi tiết chuyến xe | `/rides/[code]` | LIVE | Cancel/reassign, ledger, people |
| A007 | Danh sách phiên trả giá | `/negotiations` | LIVE | |
| A008 | Chi tiết phiên trả giá | `/negotiations/[code]` | LIVE | |
| A009 | Danh sách đơn đồ ăn | `/food-orders` | LIVE | |
| A010 | Chi tiết đơn đồ ăn | `/food-orders/[code]` | LIVE | Option lines, pickup snapshot, cancel/reassign |
| A011 | Danh sách đơn giao hàng | `/deliveries` | LIVE | Food deliveries view (parcel vertical non-MVP) |
| A012 | Chi tiết đơn giao hàng | `/deliveries/[code]` | LIVE | Uses food order detail |
| A013 | Danh sách yêu cầu dịch vụ A/C | — | DEFERRED | Non-MVP vertical |
| A014 | Chi tiết yêu cầu A/C | — | DEFERRED | Non-MVP |
| A015 | Danh sách khách hàng | `/customers` | LIVE | |
| A016 | Chi tiết khách hàng | `/customers/[code]` | LIVE | Activities; account-deletion restore needs `customers.write` (DEC-PROD-045) |
| A017 | Danh sách tài xế | `/drivers` | LIVE | Real trips count (DEC-PROD-034) |
| A018 | Chi tiết tài xế | `/drivers/[code]` | LIVE | Real trips + completion rate (driver cancels only, DEC-PROD-035); platform-fee debt card (balance, payments, mark collected; audited) |
| A019 | Duyệt KYC tài xế | `/drivers/kyc`, `/drivers/kyc/[code]` | LIVE | Documents viewer, approve/reject |
| A020 | Danh sách cửa hàng | `/stores` | LIVE | |
| A021 | Chi tiết cửa hàng | `/stores/[code]` | LIVE | |
| A022 | Duyệt hồ sơ cửa hàng | `/stores/approvals` | LIVE | |
| A023 | Kiểm duyệt sản phẩm / thực đơn | `/catalog/moderation` | LIVE | Approve/reject items |
| A024 | Danh sách giao dịch | `/transactions` | LIVE | Read-only |
| A025 | Đối soát & thanh toán đối tác | `/settlements`, `/stores/[code]` | PARTIAL | Day buckets (ICT) read-only; store commission statement per `MERCHANT_SETTLEMENT_CYCLE_DAYS` with "store paid" record; **no payout execution** |
| A026 | Xử lý hoàn tiền | `/refunds` | PARTIAL | List only (COD — no refund rail) |
| A027 | Khiếu nại / tranh chấp | `/disputes` | LIVE | |
| A028 | Chi tiết xử lý khiếu nại | `/disputes/[code]` | LIVE | Resolve |
| A029 | Quản lý khuyến mãi | `/promotions` | LIVE | Create + status |
| A030 | Quản lý danh mục | `/catalog` | LIVE | Food store categories CRUD: image/icon, drag reorder, active toggle, auto code (DEC-PROD-067) |
| A031 | Thông báo & CMS | `/notifications`, `/settings/content` | LIVE | Campaign submit → approve/reject → cancel (DEC-PROD-044), CMS items |
| A032 | Thống kê & phân tích | `/reports` | PARTIAL | From overview metrics; no BI/export |
| A033 | Khu vực & quy tắc giá | `/zones` | PARTIAL | Zones CRUD; pricing rules read-only |
| A034 | Nhân sự & phân quyền | `/staff` | LIVE | Staff + role-grant approve/reject; super-admin "Đặt lại mật khẩu" for other Admin logins (audit + sessions revoked); staff roles enforced on ops routes (DEC-PROD-044); RBAC matrix tab reads `GET /v1/ops/staff/rbac-matrix`; `customers.write` for restores (DEC-PROD-045) |
| A035 | Cấu hình & nhật ký | `/settings`, `/settings/{auth-methods,platform,faqs,content}`, `/audit-logs` | LIVE | |

Extra Admin routes without a mockup id: `/support-tickets`, `/support-tickets/[id]` (S021–S023 Ops side), `/support`, `/terms`, `/privacy`, `/chia-se-chuyen/[token]` (public trip share).

**Admin:** LIVE 29 · PARTIAL 4 · DEFERRED 2 · MISSING 0.

---

## 5. Shared states → host screens

| State file | Host screen | Kind |
|---|---|---|
| `S004__otp_invalid` | S004 / `/login/otp` | validation |
| `S004__resend_cooldown` | S004 / `/login/otp` | cooldown |
| `S015__search_empty` | S015 / `{role}/places` | empty |
| `S016__location_denied` | S016 / map pin flows | permission |
| `S017__payment_unavailable` | S017 payment methods | error |
| `C002__map_loading` | C002 `/customer/book` | loading |
| `C007__offers_empty` | C007 offers | empty |
| `C007__quote_expired` | C007 offers | expired |
| `C007__quote_taken` | C007 offers | conflict |
| `C009__fare_changed` | C009 confirm | conflict |
| `C010__matching_timeout` | C010 matching | timeout |
| `C011__tracking_offline` | C011 tracking | offline |
| `C028__checkout_offline` | C028 checkout | offline |
| `C028__checkout_repriced` | C028 checkout | conflict |
| `C028__submitting` | C028 checkout | submitting |
| `C033__tracking_reconnect` | C033 food tracking | reconnect |
| `D015_BLOCKED` | D015 eligibility | blocked |
| `D015_RESTORED` | D015 eligibility | restored |
| `D016__driver_offline` | D016 home | offline |
| `D016__ineligible_expired` | D016 home | ineligible |
| `D018__job_taken` | D018 jobs | conflict |
| `D023__passenger_otp_wrong` | D023 OTP | validation |
| `D030__cod_unconfirmed` | D030 complete | warning |
| `M011_REJECTED` | M011 KYB status | rejected |
| `M012_RESUBMITTED` | M012 resubmit | pending |
| `M015__queue_empty` | M015 queue | empty |
| `M015__queue_error` | M015 queue | error |
| `M016__accept_conflict` | M016 order | conflict |
| `M019__handoff_code_wrong` | M019 handoff | validation |

### Shared mobile screens (S001–S028)

| Id | Title | Route | Status | Notes |
|---|---|---|---|---|
| S001 | Splash / session | splash | LIVE | Session restore → role home |
| S002 | Onboarding intro | onboarding | LIVE | `CustomerOnboardingPage` |
| S003 | Phone login | `/login`, `/login/phone`, `/login/email`, `/login/email/forgot` | LIVE | Firebase phone / email per enabled auth methods; email forgot-password with 6-digit emailed code (DEC-PROD-045) |
| S004 | OTP | `/login/otp` | LIVE | Invalid + cooldown states |
| S005 | First profile | profile setup | LIVE | Name + avatar |
| S006 | Permissions | permissions | LIVE | |
| S007 | Role center (Golden) | `/roles` | LIVE | Granted roles |
| S008 | Notifications inbox | `/{role}/account/notifications` | LIVE | |
| S009 | Chat list (free) | — | DEFERRED | Free-form chat out of scope; per-transaction chat sheet on tracking |
| S010 | Chat detail (free) | tracking sheet | PARTIAL | Transaction chat only |
| S011 | Account | `/{role}/account` | LIVE | |
| S012 | Edit profile | `/{role}/edit-profile` | LIVE | Name/email/avatar (DEC-PROD-038) |
| S013 | Saved addresses | `/{role}/account/addresses` | LIVE | |
| S014 | Add/edit address | addresses sheet | LIVE | `address_form_sheet` |
| S015 | Place search | place picker | LIVE | `S015__search_empty`; header back + iOS edge swipe-back (platform page); rows: current location, "Chọn trên bản đồ", recent/saved, results |
| S016 | Map pin | `MapPinPickerPage` (from S015 "Chọn trên bản đồ" and the address form map button) | LIVE | Centre pin over a draggable map; address resolves once the map rests (500 ms) through an LRU cache (~11 m cells, 64 entries, in-flight dedup); search inside the picker (350 ms debounce, no reverse call for a picked result); my-location (denied → Settings action); style switcher; zoom by pinch/double-tap; attribution; confirm returns the pinned place; back closes search first, then the picker. Serves ride pickup/dropoff, food delivery, saved addresses and merchant store pin (`S016__location_denied`) |
| S017 | Payment methods | — | DEFERRED | COD only (MVP) |
| S018 | Link payment | — | DEFERRED | No payment rail |
| S019 | Help center | `/{role}/account/help` | LIVE | FAQs from Ops |
| S020 | Help article | help center | FOLDED | FAQ expands inline |
| S021 | Create support ticket | `/{role}/account/help/tickets/new` | LIVE | |
| S022 | Ticket list | `/{role}/account/help/tickets` | LIVE | |
| S023 | Ticket detail & replies | `/{role}/account/help/tickets/:ticketId` | LIVE | Ops replies from `/support-tickets` |
| S024 | Notification preferences | `/{role}/notification-prefs` | LIVE | Prefs filter outbox; SYSTEM always on (DEC-PROD-038) |
| S025 | Security & privacy | `/{role}/security` | LIVE | Change password, add passkey (unsupported devices handled, DEC-PROD-045), link to sessions (DEC-PROD-038) |
| S026 | Terms & consent | web `/terms`, `/privacy` | PARTIAL | Web pages; no in-app consent record |
| S027 | Delete account | `/{role}/delete-account` | LIVE | Re-auth (SMS OTP / password), blockers, grace period + purge (DEC-PROD-037) |
| S028 | Devices & sessions | `/{role}/sessions` | LIVE | List/revoke/revoke-others (DEC-PROD-038) |

**Shared:** LIVE 21 · PARTIAL 3 · FOLDED 1 · DEFERRED 3 · MISSING 0.

---

## 6. Gap list

### (a) Done — MVP journeys live end to end

- Customer ride: book → quote → bid → offers → confirm → matching → tracking (map, pickup code, chat, share) → receipt + rating (C001–C017).
- Customer food: discovery/search/category → store → item options → cart → checkout (server price, voucher code, COD) → tracking → invoice + store/driver rating, store reviews, cancel (C022–C038, C043, C046).
- Driver: KYC wizard with real uploads → Ops approval → duty/services → job feed (rides + ready food in radius from the order's pickup point) → offer / claim → lifecycle with map, OTP, COD, failure → history/earnings (D001–D035).
- Merchant: KYB → Ops approval → queue → accept/reject → kitchen → ready; accept/hours/busy settings enforced at checkout; menu, availability, item options; stats (M001–M029, M033).
- Admin: every A001–A035 MVP page on live Nest data, incl. interventions (cancel/reassign), KYC/KYB review with documents, moderation, disputes, promotions, notifications/CMS, zones, staff/grants, platform settings, audit log, support tickets; real driver trips + completion rate.
- Shared: login/register passkey-first không cần identifier (phone/email là fallback), OTP, onboarding, profile setup, permissions, roles, inbox, addresses, places, help/FAQ, support tickets.
- Engineering: Mapbox token only from env; option pricing server-side; pickup snapshot on orders; Postgres concurrency suite with 20 s per-test timeout.

### (b) Deliberately deferred — with reason

| Area | Ids | Reason |
|---|---|---|
| Scheduled / multi-stop / pre-orders | C019–C021, C041, C048 | P2 in PRD; no scheduling engine |
| Change destination mid-trip | C015 | Re-pricing a negotiated fare needs policy |
| Food delivery fee bidding, delivery tiers | C030, C031, C040 | Food fee is server-priced; tiers need policy |
| Favourites, promo detail, store-level promos, review replies | C039, C045, M040, M041, M031 (reply) | P1 marketing/review depth |
| Wallets, payouts, withdrawals, refunds to customer | D036–D039, M008, M034–M038, C047, S017, S018, A025 payout, A026 execution | Cash-only launch; no payment/payout rail |
| Other verticals | C042, A013, A014 | Non-MVP (DEC-PROD-001) |
| Multi-branch, merchant staff | M014, M042, M043 | P1 |
| Document expiry / re-verification, vehicle change | D015, M044, D041 | Backend does not track document expiry yet |
| SOS backends | C014 (SOS part), D044 | Needs an emergency-response operator; no fake SOS |
| Driver training content | D045 | No content supplied |
| Free-form chat | S009 | Out of scope; transaction chat exists |
| Delivery proof photo | D030 part | Decided: delivery code instead (DEC-PROD-036) |
| OCR / liveness | D005, D006 parts | Needs a vendor |
| seed-scale raw-SQL orders without pickup snapshot | — | Read path falls back to the store point |

### (c) Product decisions applied (DEC-PROD-035 … DEC-PROD-040)

| Topic | Ids | Current behaviour |
|---|---|---|
| Account deletion | S027 | Re-auth, blockers, grace period + purge (DEC-PROD-037) |
| Profile, notification prefs, security, sessions | S012, S024, S025, S028 | Live (DEC-PROD-038) |
| Customer cancel after driver assigned | C011 | Allowed; `cancelledBy` recorded; late-cancel fee rules in [cancellation domain](../02-domain/cancellation-refund-disputes.md) (DEC-PROD-035) |
| Driver navigation | Driver ride/food job pages | One "Điều hướng" button → bottom sheet (Google Maps, Apple Maps on iOS, Waze, Google Maps web), destination follows the phase |
| Food delivery proof | D030 | Delivery code (`FOOD_DELIVERY_CODE_REQUIRED`, default on); no proof photo (DEC-PROD-036) |
| Merchant handoff code | M019 | `FOOD_HANDOVER_CODE_REQUIRED`, default off (DEC-PROD-036) |
| Merchant item editing, categories, order history | M027, M025, A030, M020 | Live incl. photo upload and category drag-reorder (DEC-PROD-039, DEC-PROD-040) |
| Tip | C018 | Out of scope; no tip UI (DEC-PROD-035) |
| Admin password reset | A002 | Super-admin reset; forgot page tells staff to contact an admin |

**Open product question:** option images and per-option quantity limits (C026/M028).

---

## Evidence sources

- Mockups: `design/mockups/screens/{customer,driver,merchant,admin,shared,states}/`
- Catalog titles: `docs/DealGo_MD_File_List.md`
- Mobile routes: `mobile/lib/app/router/app_router.dart`, `features/**/utils/*_routes.dart`, `features/shell/presentation/account_routes.dart`
- Admin routes: `website/app/**/page.tsx`; BFF paths `website/lib/api/paths.ts`; Nest `backend/src/**/*controller.ts`
- Decisions: `docs/00-governance/decisions-and-assumptions.md`

**NOT_VISUALLY_VERIFIED:** pixel parity for every frame on a physical device; screenshots cover the golden set only.
