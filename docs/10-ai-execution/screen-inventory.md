---
doc_id: DG-AI-010
title: "DealGo — Screen inventory (design ↔ routes)"
version: "2.1.0"
status: "ACTIVE"
owner: "UI Designer"
last_updated: "2026-10-25"
related:
  - ../DealGo_MD_File_List.md
  - ../01-product/product-requirements.md
  - ../00-governance/decisions-and-assumptions.md
  - ui-mock-first-strategy.md
  - design-system-mobile-handoff.md
---

# Screen inventory — design mockups ↔ implementation

> **Reality pass 2.0 (round 12d).** Re-audited against code, not against earlier plans:
> mobile routes in `mobile/lib/app/router/app_router.dart` + `features/**/utils/*_routes.dart` + `shell/presentation/account_routes.dart`;
> Admin routes in `website/app/**/page.tsx` and the `/api/ops/*` BFF → Nest `v1/ops/*` controllers.
> Mockups: `design/mockups/screens/{customer,driver,merchant,admin,shared}` (C001–C048, D001–D045, M001–M044, A001–A035, S001–S028).
> Since 1.0.0 the mobile app no longer runs on fixtures: every live route below reads/writes Nest (fake clients only in tests / `useMockData`).
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

- **Maps:** `MapPort` — `TileMapPort` (flutter_map over `MAP_TILE_URL` raster tiles) when configured, otherwise `PlaceholderMapView` chrome. Admin monitor/detail maps read `NEXT_PUBLIC_MAPBOX_TOKEN` only for tiles (no hardcoded token) and fall back to the non-map view (DEC-PROD-031/032); road routes come from Nest `GET /v1/ops/routing/route` (`ROUTING_PROVIDER`, straight line when unconfigured, DEC-PROD-045).
- **Live updates:** ride/food tracking poll + realtime driver location; driver presence via duty cubit.
- **Payments:** COD only (MVP). No card/wallet rails.
- **Uploads:** KYC/KYB documents are sent as base64 in the partner application and served to Ops via `GET /v1/ops/partner-applications/:id/documents/:index`.

---

## 1. Customer — C001–C048

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| C001 | Trang chủ DealGo (Golden) | `/customer` | LIVE | Home search, services, stores from Nest |
| C002 | Bản đồ đặt xe / chọn hành trình | `/customer/book` | LIVE | `RideMapPage`; place search; tile map when configured |
| C003 | Tổng quan điểm đón/đến & tuyến | `/customer/ride/route` | LIVE | Server quote (distance/duration) |
| C004 | Chọn loại phương tiện (Golden) | `/customer/ride/vehicle` | LIVE | Only motorbike is dispatched: single pre-selected option priced from the server quote |
| C005 | Chi tiết giá cước / điều kiện | `/customer/ride/fare-detail` | LIVE | From the server quote; prices first if opened without one |
| C006 | Tự đề xuất giá chuyến | `/customer/ride/fare` | LIVE | Fare bid within server bounds |
| C007 | Danh sách tài xế chào giá | `/customer/ride/offers/:rideId` | LIVE | Sort, match/counter chips; empty/expired/taken states |
| C008 | Chi tiết báo giá và tài xế | `/customer/ride/offers/:rideId/detail` | LIVE | Real driver card (rating, vehicle) |
| C009 | Xác nhận chuyến & thanh toán | `/customer/ride/confirm/:rideId` | LIVE | `C009__fare_changed`; COD |
| C010 | Đang tìm tài xế | `/customer/ride/matching/:rideId` | LIVE | Timeout state |
| C011 | Tài xế đã nhận, đang đến đón | `/customer/ride/tracking/:rideId` | LIVE | Driver location on map; offline state; transaction chat sheet |
| C012 | Xác thực mã đón khách | `/customer/ride/tracking/:rideId/pickup-code` | LIVE | Server pickup code |
| C013 | Bản đồ chuyến đang chạy | `/customer/ride/tracking/:rideId` | LIVE | Same route as C011 (IN_TRIP phase) |
| C014 | Trung tâm an toàn chuyến đi | `/customer/ride/tracking/:rideId/safety` | PARTIAL | Public share link (`/chia-se-chuyen/[token]` on web) + local emergency contacts; **no SOS backend** |
| C015 | Đổi điểm đến trong chuyến | — | DEFERRED | Needs re-pricing policy for negotiated fares |
| C016 | Hủy chuyến & chọn lý do | `/customer/ride/cancel/:rideId` | LIVE | No invented cancel fee |
| C017 | Biên nhận sau chuyến | `/customer/ride/receipt/:rideId` | LIVE | Includes rating card |
| C018 | Đánh giá & tip tài xế | `/customer/ride/receipt/:rideId` | LIVE | Rating (`RateServiceCard`); tip removed from scope (DEC-PROD-035) |
| C019 | Đặt xe theo lịch | — | DEFERRED | P2 scheduled booking |
| C020 | Thêm / đổi điểm dừng | — | DEFERRED | P2 multi-stop |
| C021 | Chi tiết chuyến đặt trước | — | DEFERRED | P2 with C019 |
| C022 | Khám phá đồ ăn | `/customer/shop` | LIVE | Categories + stores from Nest |
| C023 | Tìm kiếm quán / món | `/customer/food/search` | LIVE | |
| C024 | Kết quả danh mục | `/customer/food/category` | LIVE | |
| C025 | Chi tiết quán & menu | `/customer/food/stores/:storeId` | LIVE | Open/closed/busy from store settings |
| C026 | Chi tiết món & tùy chọn | `/customer/food/stores/:storeId/items/:itemId` | LIVE | Real option groups/prices (DEC-PROD-033) |
| C027 | Giỏ hàng | `/customer/food/cart` | LIVE | Lines keyed by options |
| C028 | Checkout đơn đồ ăn (Golden) | `/customer/food/checkout` | LIVE | Server pricing, voucher code, COD; offline/repriced/submitting states |
| C029 | Chọn voucher | `/customer/account/vouchers` + checkout code field | PARTIAL | List from `GET /v1/promotions/available` (FOOD); checkout takes a code — no in-checkout picker sheet |
| C030 | Đề xuất phí giao hàng | — | DEFERRED | Food delivery fee is server-priced, no fee bidding |
| C031 | Báo giá giao của tài xế | — | DEFERRED | With C030 |
| C032 | Đặt hàng thành công | `/customer/food/order-success` | LIVE | |
| C033 | Theo dõi đơn Food | `/customer/food/orders/:orderId` | LIVE | Reconnect state; driver location; delivery code while on the way (DEC-PROD-036) |
| C034 | Xác nhận thay món / giá | — | DEFERRED | P1 partial adjustments (merchant M018 too) |
| C035 | Hủy đơn & chọn lý do | `/customer/food/orders/:orderId/cancel` | LIVE | |
| C036 | Chi tiết đơn / hóa đơn Food | `/customer/food/orders/:orderId/invoice` | LIVE | Option lines; rating card |
| C037 | Đánh giá món / quán / giao | `/customer/food/orders/:orderId/invoice` | LIVE | Store stars + driver stars + comment (`RateServiceCard`); no per-dish score |
| C038 | Xem đánh giá cửa hàng | `/customer/food/stores/:storeId` (Reviews tab) | LIVE | `GET /v1/ratings/stores/:storeId/reviews` + summary in heading |
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

**Customer:** LIVE 31 · PARTIAL 3 · DEFERRED 14 · MISSING 0.

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
| D021 | Chuyến đã nhận / điều hướng đón | `/driver/rides/:rideId/active` | LIVE | MapPort map + Google Maps / Waze hand-off (DEC-PROD-035) |
| D022 | Đã đến điểm đón / chờ | `/driver/rides/:rideId/active` | LIVE | |
| D023 | Nhập OTP hành khách | `/driver/rides/:rideId/otp` | LIVE | Server-verified code |
| D024 | Bản đồ chuyến đang chạy | `/driver/rides/:rideId/active` | LIVE | MapPort map (13a; was a static box) + nav hand-off to dropoff |
| D025 | Kết thúc chuyến / thu tiền | `/driver/rides/:rideId/active` | LIVE | COD |
| D026 | Điều hướng tới quán lấy đơn | `/driver/food/:orderId` | LIVE | Map from the order's pickup snapshot (DEC-PROD-034) + Google Maps / Waze |
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
| M013 | Dashboard Shop (Golden) | `/merchant` | LIVE | Queue + today stats |
| M014 | Chọn cửa hàng / chi nhánh | — | DEFERRED | P1 multi-branch |
| M015 | Hàng đợi đơn (Golden) | `/merchant/orders` | LIVE | Empty/error states |
| M016 | Chi tiết đơn & xác nhận | `/merchant/orders/:orderId` | LIVE | Accept/reject, option lines; conflict state |
| M017 | Bếp đang chế biến | `/merchant/orders` | FOLDED | "Preparing" section + kitchen lines; mark ready |
| M018 | Điều chỉnh món / giá | — | DEFERRED | P1 with C034 |
| M019 | Bàn giao & mã tài xế | `/merchant/orders/:orderId` | LIVE | Server **handover code** shown while ASSIGNED; driver enters it at pickup when `FOOD_HANDOVER_CODE_REQUIRED` (default off, DEC-PROD-036) |
| M020 | Lịch sử đơn Shop | `/merchant/history` | LIVE | Finished orders + filters/search (DEC-PROD-039) |
| M021 | Đơn hủy / bồi hoàn / tranh chấp | — | DEFERRED | Ops `/disputes`, `/refunds` |
| M022 | Cấu hình nhận đơn auto/manual | `/merchant/settings/accept` | LIVE | Enforced at checkout (DEC-PROD-028) |
| M023 | Giờ hoạt động / lịch nghỉ | `/merchant/settings/hours` | LIVE | DEC-PROD-027 |
| M024 | Chế độ bận / tạm ngưng | `/merchant/settings/busy` | LIVE | DEC-PROD-026/028 |
| M025 | Danh mục menu | `/merchant/products/categories` | LIVE | CRUD + DnD reorder (DEC-PROD-040) + search filter (DEC-PROD-042) |
| M026 | Danh sách sản phẩm / menu | `/merchant/products` | LIVE | Search + filter tabs All/On sale/Hidden + soldCount (DEC-PROD-042) |
| M027 | Tạo / sửa món | `/merchant/products/:itemId/edit` | LIVE | Edit fields (039); photo upload (040); gallery up to MENU_ITEM_MAX_IMAGES + draft/hidden badge + soldCount (042) |
| M028 | Biến thể / size / topping | `/merchant/products/:itemId/variants` | LIVE | Real option groups (DEC-PROD-033) |
| M029 | Tồn kho còn/hết | `/merchant/products` | LIVE | Availability toggle (no stock counts by design) |
| M030 | Hồ sơ Shop | `/merchant/account`, `/merchant/settings/profile`, `/merchant/settings/location` | LIVE | Store name + logo upload/remove (DEC-PROD-045); store pickup location (DEC-PROD-044) |
| M031 | Đánh giá & phản hồi | `/merchant/stats` | PARTIAL | Rating average in stats; no review list / reply |
| M032 | Khu vực phục vụ & pickup | — | DEFERRED | Pickup point from KYB; service radius is platform-wide |
| M033 | Doanh thu & đơn hoàn tất | `/merchant/stats` | LIVE | Real stats |
| M034 | Số dư & công nợ | — | DEFERRED | Partner wallet |
| M035 | Quyết toán đối soát | — | DEFERRED | Ops `/settlements` |
| M036 | Chi tiết đợt quyết toán | — | DEFERRED | Ops |
| M037 | Ngân hàng & rút | — | DEFERRED | Wallet |
| M038 | Rút tiền & lịch sử | — | DEFERRED | Wallet |
| M039 | Báo cáo bán hàng | `/merchant/stats` | PARTIAL | Same as M033; no export |
| M040 | Chiến dịch khuyến mãi Shop | — | DEFERRED | Promotions are Ops-run (A029) |
| M041 | Tạo / sửa khuyến mãi Shop | — | DEFERRED | With M040 |
| M042 | Nhân viên & cấp quyền | — | DEFERRED | Multi-staff |
| M043 | Mời / sửa quyền nhân viên | — | DEFERRED | Multi-staff |
| M044 | Cập nhật giấy tờ hết hạn | — | DEFERRED | Same as D015 |

**Merchant:** LIVE 18 · PARTIAL 3 · FOLDED 8 · DEFERRED 15 · MISSING 0.

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
| A018 | Chi tiết tài xế | `/drivers/[code]` | LIVE | Real trips + completion rate (driver cancels only, DEC-PROD-035); balance card hidden until a wallet exists |
| A019 | Duyệt KYC tài xế | `/drivers/kyc`, `/drivers/kyc/[code]` | LIVE | Documents viewer, approve/reject |
| A020 | Danh sách cửa hàng | `/stores` | LIVE | |
| A021 | Chi tiết cửa hàng | `/stores/[code]` | LIVE | |
| A022 | Duyệt hồ sơ cửa hàng | `/stores/approvals` | LIVE | |
| A023 | Kiểm duyệt sản phẩm / thực đơn | `/catalog/moderation` | LIVE | Approve/reject items |
| A024 | Danh sách giao dịch | `/transactions` | LIVE | Read-only |
| A025 | Đối soát & thanh toán đối tác | `/settlements` | PARTIAL | Day buckets read-only; **no payout execution** |
| A026 | Xử lý hoàn tiền | `/refunds` | PARTIAL | List only (COD — no refund rail) |
| A027 | Khiếu nại / tranh chấp | `/disputes` | LIVE | |
| A028 | Chi tiết xử lý khiếu nại | `/disputes/[code]` | LIVE | Resolve |
| A029 | Quản lý khuyến mãi | `/promotions` | LIVE | Create + status |
| A030 | Quản lý danh mục | `/catalog` | LIVE | Rename store categories (DEC-PROD-039) |
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
| S015 | Place search | place picker | LIVE | `S015__search_empty` |
| S016 | Map pin | place picker | PARTIAL | Pin on tile map when configured; `S016__location_denied` |
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

## 6. Final gap list (round 12d)

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
| Item/price adjustment after order | C034, M018 | P1 partial-adjustment flow |
| Favourites, promo detail, store-level promos, review replies | C039, C045, M040, M041, M031 (reply) | P1 marketing/review depth |
| Wallets, payouts, withdrawals, refunds to customer | D036–D039, M008, M034–M038, C047, S017, S018, A025 payout, A026 execution, A018 balance | COD-only MVP; no payment/payout rail |
| Other verticals | C042, A013, A014 | Non-MVP (DEC-PROD-001) |
| Multi-branch, merchant staff | M014, M042, M043 | P1 |
| Document expiry / re-verification, vehicle change | D015, M044, D041 | Backend does not track document expiry yet |
| SOS backends | C014 (SOS part), D044 | Needs an emergency-response operator; no fake SOS |
| Driver training content | D045 | No content supplied |
| Free-form chat | S009 | Out of scope; transaction chat exists |
| Delivery proof photo | D030 part | Decided: delivery code instead (DEC-PROD-036) |
| OCR / liveness | D005, D006 parts | Needs a vendor |
| seed-scale raw-SQL orders without pickup snapshot | — | Read path falls back to the store point |

### (c) Decided in round 13 (DEC-PROD-035 … DEC-PROD-039)

> Status per item: **13a** done = 3, 4, 8, 9, 10 · **13b** done = 5, 7, 11 · **13c** done = 1 (+ super-admin UI, merchant ASSIGNED refresh) · **13d** done = 2 (S012/S024/S025/S028) · **13e** done = 6 (M027/M025/A030/M020) · **13f** closes soft gaps of 6 (photo upload + category DnD).

1. **Account deletion (S027)** — **done in 13c** (DEC-PROD-037).
2. **Edit profile / notification prefs / security / sessions (S012, S024, S025, S028)** — **done in 13d** (DEC-PROD-038).
3. **Customer cancel after driver assigned** — **done in 13a** (DEC-PROD-035 `cancelledBy`).
4. **Driver navigation** — **done in 13a** (Google Maps / Waze buttons).
5. **Food delivery proof (D030)** — **OTP mã giao hàng done in 13b** (DEC-PROD-036); photo-at-handoff still open if needed.
6. **Merchant item editing (M027) + category CRUD (M025/A030) + order history (M020)** — **done in 13e** (DEC-PROD-039); **photo upload + category drag-reorder done in 13f** (DEC-PROD-040).
7. **Merchant handoff code (M019)** — **mechanism done in 13b** (setting `FOOD_HANDOVER_CODE_REQUIRED`, default off); product choice whether to turn on by default.
8. **Tip (C018)** — **out of scope / done in 13a** (no tip UI).
9. **Driver "Số dư khả dụng" (A018)** — **done in 13a** (card hidden until wallet).
10. **Option images / per-option quantity limits (C026/M028)** — needed?
11. **Admin password reset (A002)** — **done in 13b/13c** (super-admin reset + forgot page points to contact admin).

---

## Evidence sources

- Mockups: `design/mockups/screens/{customer,driver,merchant,admin,shared,states}/`
- Catalog titles: `docs/DealGo_MD_File_List.md`
- Mobile routes: `mobile/lib/app/router/app_router.dart`, `features/**/utils/*_routes.dart`, `features/shell/presentation/account_routes.dart`
- Admin routes: `website/app/**/page.tsx`; BFF paths `website/lib/api/paths.ts`; Nest `backend/src/**/*controller.ts`
- Decisions: `docs/00-governance/decisions-and-assumptions.md` (DEC-PROD-001…045)

**NOT_VISUALLY_VERIFIED:** pixel parity for every frame on a physical device; screenshots cover the golden set and the screens changed in rounds 10–12.

<!-- round13e applied 2026-10-19T14:17:28+00:00 -->

<!-- round13f applied -->

<!-- round14a applied -->
<!-- round14b applied DEC-PROD-042 -->
<!-- round14c applied DEC-PROD-043 -->
