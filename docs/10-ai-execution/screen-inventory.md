---
doc_id: DG-AI-010
title: "DealGo — Screen inventory (design ↔ routes)"
version: "1.0.0"
status: "ACTIVE"
owner: "UI Designer"
last_updated: "2026-10-14"
related:
  - ../DealGo_MD_File_List.md
  - ../01-product/product-requirements.md
  - ui-mock-first-strategy.md
  - design-system-mobile-handoff.md
---

# Screen inventory — design mockups ↔ implementation

> **Spec only** (WORK_ORDER 1/N). No Flutter/Next code in this pass.  
> Titles from `docs/DealGo_MD_File_List.md` + visual check of golden frames.  
> Status from `mobile/lib/app/router/app_router.dart`, feature `*_routes.dart`, `shell_tab.dart`, and `website/app/**/page.tsx` (2026-10-14).  
> **Do not invent fees or OPEN-* policies** from mockup copy (illustrative prices are design fixtures).

## Status legend

| Status | Meaning |
|---|---|
| `EXISTS` | Dedicated route + page with real UI (mock/fixture OK) |
| `PARTIAL` | Route or surface exists; missing steps, fidelity, or sub-screens vs PNG |
| `MISSING` | No route / no implementable page yet |
| `STATE_ONLY` | Overlay in `design/mockups/screens/states/` (not a primary screen) |

## MVP scope notes

- **MVP (`DEC-PROD-001`):** Ride (two-wheeler + fare negotiation) + Food delivery; one Flutter multi-role; Admin Web ops.
- **Defer (not P0):** car/7-seat as product line, multi-stop, scheduled booking, supermarket/other verticals, promo wallet / advanced marketing, rating/review (CAP-P1), multi-branch staff, free-form chat inbox, standalone parcel “giao hàng” / A/C services on Admin (`A011–A014`).
- Mockups still list cars (C004) and extra verticals (C042) — **implement MVP copy/filter**; do not ship non-MVP verticals.

## Visual recon (PNG opened)

| Frame | Observed |
|---|---|
| `C001` | Brand home: hero, Ride/Food tiles, quick-book card, category row, store cards with green “Freeship” chip, 5-tab bar (center “Đặt”) |
| `C004` | “Chọn loại xe”; route card; map badge; vehicle rows + purple “Đã chọn” chip; primary “Xem giá chi tiết →” |
| `C007` | Offers list; green “Bằng giá bạn đề xuất” / grey “Đề nghị khác” chips; sort pill |
| `C028` | Food checkout cards; orange “COD · Chưa thu tiền” chip; primary “Đặt hàng · … →” |
| `C028__submitting` | Full-screen processing; orange `PROCESSING` chip; idempotency banner |
| `D016` | Driver overview; green Online chip; map; duty toggles; 5-tab (Tổng quan…) |
| `M015` | Queue; orange `NEW · Chờ Shop xác nhận`; green “Đang chế biến”; primary CTA |
| `S007` | Role center; green “Đang xem”; secondary “Chuyển →” |
| `A003` | Admin overview KPIs, chart, activity, sidebar |

Assets: `design/assets/batch01/svg/*`, `design/assets/batch02/png/*` (heroes, food, vehicles, stores).

---

## 1. Customer — C001–C048

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| C001 | Trang chủ DealGo (Golden) | `/customer` | EXISTS | MOB-FINISH pixel-pass: rounded category tiles, Freeship chips, quick-book CTA; map still stub elsewhere |
| C002 | Bản đồ đặt xe / chọn hành trình | `/customer/book` | EXISTS | `RideMapPage`; Đón ngay/Đặt lịch; suggestions; state `C002__map_loading`; map = design-chrome placeholder |
| C003 | Tổng quan điểm đón/đến & tuyến | `/customer/ride/route` | EXISTS | `RideRouteOverviewPage`; map + stats fixtures; CTA → C004 |
| C004 | Chọn loại phương tiện (Golden) | `/customer/ride/vehicle` | EXISTS | MVP: prefer two-wheeler; cars in mock = fixture only |
| C005 | Chi tiết giá cước / điều kiện | `/customer/ride/fare-detail` | EXISTS | `RideFareBreakdownPage` (fixture components); CTA → C006 bid |
| C006 | Tự đề xuất giá chuyến | `/customer/ride/fare` | EXISTS | Fare bidding |
| C007 | Danh sách tài xế chào giá | `/customer/ride/offers/:rideId` | EXISTS | MOB-FINISH: sort pill, match/counter chips, detail pill, CTA “Xem tài xế…”; states empty/expired/taken |
| C008 | Chi tiết báo giá và tài xế | `/customer/ride/offers/:rideId/detail` | EXISTS | Linked from C007 “Xem chi tiết”; query `offerId` optional |
| C009 | Xác nhận chuyến & thanh toán | `/customer/ride/confirm/:rideId` | EXISTS | State `C009__fare_changed` |
| C010 | Đang tìm tài xế | `/customer/ride/matching/:rideId` | EXISTS | State `C010__matching_timeout` |
| C011 | Tài xế đã nhận, đang đến đón | `/customer/ride/tracking/:rideId` | EXISTS | MOB-FINISH: map chrome overlays + driver/trip/OTP cards; map SDK still stub; offline state |
| C012 | Xác thực mã đón khách (Pickup OTP) | `/customer/ride/tracking/:rideId/pickup-code` | EXISTS | Customer OTP view; linked from tracking |
| C013 | Bản đồ chuyến đang chạy | `/customer/ride/tracking/:rideId` | EXISTS | Map overlay + progress on same tracking route as C011 |
| C014 | Trung tâm an toàn chuyến đi | `/customer/ride/tracking/:rideId/safety` | EXISTS | Share trip + emergency contacts UI; no fake SOS backend |
| C015 | Đổi điểm đến trong chuyến | — | MISSING | Defer until policy; do not invent fee |
| C016 | Hủy chuyến & chọn lý do | `/customer/ride/cancel/:rideId` | EXISTS | Reason picker; wired from matching/offers/tracking; no invented fees |
| C017 | Biên nhận sau chuyến | `/customer/ride/receipt/:rideId` | EXISTS | |
| C018 | Đánh giá & tip tài xế | — | MISSING | **Defer P1** (rating/review) |
| C019 | Đặt xe theo lịch | — | MISSING | **Defer P2** scheduled |
| C020 | Thêm / đổi điểm dừng | — | MISSING | **Defer P2** multi-stop |
| C021 | Chi tiết chuyến đặt trước | — | MISSING | **Defer P2** |
| C022 | Khám phá đồ ăn | `/customer/shop` | EXISTS | MOB-FINISH: location pill + banner/categories/store cards vs PNG |
| C023 | Tìm kiếm quán / món | `/customer/food/search` | EXISTS | `FoodSearchPage`; filters, history, popular keywords |
| C024 | Kết quả danh mục | `/customer/food/category` | EXISTS | `FoodCategoryPage`; sort chips + store list |
| C025 | Chi tiết quán & menu | `/customer/food/stores/:storeId` | EXISTS | MOB-FINISH: open chip, meta chips, promo banner (no invented fee amounts), menu Freeship |
| C026 | Chi tiết món & tùy chọn | `/customer/food/stores/:storeId/items/:itemId` | EXISTS | `FoodItemOptionsPage` full-page; sheet helper retained |
| C027 | Giỏ hàng | `/customer/food/cart` | EXISTS | |
| C028 | Checkout đơn đồ ăn (Golden) | `/customer/food/checkout` | EXISTS | MOB-FINISH: COD chip + “Đặt hàng · … →”; states offline/repriced/submitting |
| C029 | Chọn voucher | — | MISSING | **Defer P1** promo |
| C030 | Đề xuất phí giao hàng | — | MISSING | **Defer** (Ride negotiation ≠ Food fee bid) |
| C031 | Báo giá giao của tài xế | — | MISSING | **Defer** with C030 |
| C032 | Đặt hàng thành công | `/customer/food/order-success` | EXISTS | |
| C033 | Theo dõi đơn Food | `/customer/food/orders/:orderId` | EXISTS | State `C033__tracking_reconnect` |
| C034 | Xác nhận thay món / giá | — | MISSING | **Defer P1** partial adjustments |
| C035 | Hủy đơn & chọn lý do | `/customer/food/orders/:orderId/cancel` | EXISTS | Reason picker; wired from food tracking; soft-fail Nest |
| C036 | Chi tiết đơn / hóa đơn Food | `/customer/food/orders/:orderId/invoice` | EXISTS | `FoodInvoicePage`; linked from C033 tracking |
| C037 | Đánh giá món / quán / giao | — | MISSING | **Defer P1** |
| C038 | Xem đánh giá cửa hàng | — | MISSING | **Defer P1** |
| C039 | Quán / món yêu thích | — | MISSING | **Defer P1** |
| C040 | Hình thức giao (tiết kiệm/nhanh/hẹn) | — | MISSING | **Defer** until CAP |
| C041 | Đơn đặt trước Food | — | MISSING | **Defer P2** |
| C042 | Siêu thị / tiện lợi | — | MISSING | **Defer P2** other vertical |
| C043 | Trung tâm hoạt động | `/customer/trips` | EXISTS | `CustomerActivityPage` + filter chips |
| C044 | Ví khuyến mãi | — | MISSING | **Defer P1** |
| C045 | Chi tiết chương trình KM | — | MISSING | **Defer P1** |
| C046 | Lịch sử thanh toán | `/customer/account/payments` | EXISTS | Soft shell + TEST_ONLY fixture rows; from Account |
| C047 | Chi tiết hoàn tiền | — | MISSING | P0 soft; Admin refunds cover ops |
| C048 | Danh sách đơn/chuyến đặt trước | — | MISSING | **Defer P2** |

**Customer counts:** EXISTS ~29 · PARTIAL ~2 · MISSING ~17 (of which **~12 deferred** non-MVP). MOB-FINISH golden pixel-pass: C001/C007/C011/C022/C025/C028 (map = chrome stub).

---

## 2. Driver — D001–D040

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| D001 | Giới thiệu đăng ký tài xế | `/driver/kyc/intro` | EXISTS | Intro matches D001 brand/hero/features; mock CTAs |
| D002 | Chọn dịch vụ & điều kiện | `/driver/kyc/steps` | PARTIAL | Step in 9-step wizard (not separate route) |
| D003 | Thông tin cá nhân theo giấy tờ | `/driver/kyc/steps` | PARTIAL | |
| D004 | Chụp CCCD mặt trước/sau | `/driver/kyc/steps` | PARTIAL | Mock attach only — no S3 |
| D005 | OCR xác nhận dữ liệu | `/driver/kyc/steps` | PARTIAL | Stub OCR confirm UI |
| D006 | Selfie / liveness | `/driver/kyc/steps` | PARTIAL | Mock attach slot |
| D007 | GPLX | `/driver/kyc/steps` | PARTIAL | |
| D008 | Loại xe & biển số | `/driver/kyc/steps` | PARTIAL | Vehicle step; registration/insurance still thin |
| D009 | Đăng ký xe & bảo hiểm | `/driver/kyc/steps` | PARTIAL | Folded into vehicle step |
| D010 | Hồ sơ theo loại dịch vụ | `/driver/kyc/steps` | PARTIAL | Covered by services step |
| D011 | Liên kết ngân hàng | `/driver/kyc/steps` | PARTIAL | Mock bank attach |
| D012 | Xem lại & gửi duyệt | `/driver/kyc/steps` | EXISTS | Review + submit |
| D013 | Kết quả xét duyệt | `/driver/kyc/status` | EXISTS | |
| D014 | Nộp lại sau từ chối | `/driver/kyc/rejected` | EXISTS | |
| D015 | Giấy tờ hết hạn / tái xác minh | — | PARTIAL | States `D015_BLOCKED` / `D015_RESTORED`; no dedicated route |
| D016 | Dashboard Tài xế (Golden) | `/driver` | EXISTS | MOB-FINISH: Online chip, duty map chrome, 2×2 stats fixture, service toggles |
| D017 | Bật loại dịch vụ được nhận | `/driver/services` | EXISTS | Full config page (duty, services, vehicle, area); local mock save |
| D018 | Job feed yêu cầu mở | `/driver/jobs` | EXISTS | MOB-FINISH: area/Online, mode card, food/ride cards; income copy = server fields / đối soát; `D018__job_taken` |
| D019 | Chi tiết yêu cầu & thu nhập | `/driver/rides/:rideId` | EXISTS | Ride open detail; food open detail at `/driver/food/:orderId` |
| D020 | Báo giá / trả giá với khách | `/driver/rides/:rideId/offer` | EXISTS | Demo CTA → active ride lifecycle |
| D021 | Chuyến đã nhận / điều hướng đón | `/driver/rides/:rideId/active` | EXISTS | Phase machine; mock map/nav (no map SDK) |
| D022 | Đã đến điểm đón / chờ | `/driver/rides/:rideId/active` | EXISTS | Arrived phase |
| D023 | Nhập OTP hành khách | `/driver/rides/:rideId/otp` | EXISTS | MOB-FINISH polish vs PNG; 4-digit boxes; wrong-code; matches `ridePickupCode` |
| D024 | Bản đồ chuyến đang chạy | `/driver/rides/:rideId/active` | PARTIAL | On-trip phase; PlaceholderMapView chrome improved, no Map SDK |
| D025 | Kết thúc chuyến / thu tiền | `/driver/rides/:rideId/active` | EXISTS | Complete phase; no invented surcharges |
| D026 | Điều hướng tới quán lấy đơn | `/driver/food/:orderId` | EXISTS | Post-claim navigate phase |
| D027 | Đến quán chờ món | `/driver/food/:orderId` | EXISTS | Wait phase |
| D028 | Xác nhận lấy món | `/driver/food/:orderId` | EXISTS | Pickup confirm phase |
| D029 | Bản đồ giao tới khách | `/driver/food/:orderId` | PARTIAL | Deliver phase; map mock |
| D030 | Hoàn tất giao OTP / ảnh | `/driver/food/:orderId` | PARTIAL | Complete phase UI; COD from server total; no photo/OTP capture yet |
| D031 | Giao thất bại | `/driver/jobs/failed/:jobId` | EXISTS | Outcome UI shell; linked from jobs + food “Báo sự cố” |
| D032 | Công việc đang chạy / giữ chỗ | `/driver/jobs` | PARTIAL | Active vs open not split like D032 |
| D033 | Lịch sử công việc | `/driver/jobs` / earnings | PARTIAL | No dedicated history route |
| D034 | Chi tiết công việc đã xong | `/driver/jobs/completed/:jobId` | EXISTS | Fixture earnings; linked from jobs / failed sample |
| D035 | Tổng quan thu nhập | `/driver/earnings` | EXISTS | Uses Material `FilterChip` — replace |
| D036 | COD phải đối soát | — | MISSING | P0 soft (ledger/ops); UI gap |
| D037 | Ví số dư | — | MISSING | **Defer** wallet (CAP-P2) unless read-only stub |
| D038 | Rút tiền | — | MISSING | **Defer** wallet |
| D039 | Lịch sử rút tiền | — | MISSING | **Defer** wallet |
| D040 | Hồ sơ tài xế & phương tiện | `/driver/account` | PARTIAL | Account shell; not full D040 |

**Driver counts:** EXISTS ~22 · PARTIAL ~14 · MISSING ~4 (+ deferred wallet). MOB-FINISH: D016/D018/D023 polish; map still PlaceholderMapView; KYC steps still collapsed; no invented driver income.

> D041–D045 exist as mockups but are **out of this table** (WO = D001–D040). Treat as P1+.

---

## 3. Merchant — M001–M040

| Design id | Title | Route path | Status | Notes |
|---|---|---|---|---|
| M001 | Giới thiệu đăng ký bán hàng | `/merchant/kyb/intro` | EXISTS | Brand/partner-mode intro polish (MOB-2) |
| M002 | Loại hình / ngành hàng | `/merchant/kyb/steps` | PARTIAL | Collapsed KYB wizard vs M002–M010 |
| M003 | Thông tin quán & đại diện | `/merchant/kyb/steps` | PARTIAL | |
| M004 | CCCD / hộ chiếu | `/merchant/kyb/steps` | PARTIAL | |
| M005 | Tài liệu KD & MST | `/merchant/kyb/steps` | PARTIAL | |
| M006 | Địa chỉ & ghim quán | `/merchant/kyb/steps` | PARTIAL | |
| M007 | Ảnh mặt tiền / logo / bìa | `/merchant/kyb/steps` | PARTIAL | |
| M008 | Ngân hàng nhận tiền | `/merchant/kyb/steps` | PARTIAL | |
| M009 | Điều khoản hợp tác | `/merchant/kyb/steps` | PARTIAL | |
| M010 | Kiểm tra & gửi duyệt | `/merchant/kyb/steps` | PARTIAL | |
| M011 | Trạng thái duyệt | `/merchant/kyb/status` | EXISTS | State `M011_REJECTED` |
| M012 | Bổ sung / nộp lại | `/merchant/kyb/rejected` | EXISTS | State `M012_RESUBMITTED` |
| M013 | Dashboard Shop (Golden) | `/merchant` | EXISTS | MOB-FINISH: store hero, stats, queue rows + “Xem →”; finance from queue totals (not withdraw) |
| M014 | Chọn cửa hàng / chi nhánh | — | MISSING | **Defer P1** multi-branch |
| M015 | Hàng đợi đơn (Golden) | `/merchant/orders` | EXISTS | MOB-FINISH: NEW chip copy; empty/error states |
| M016 | Chi tiết đơn & xác nhận | `/merchant/orders/:orderId` | EXISTS | MOB-FINISH accept/reject footer + NEW chip; item list on PLACED; conflict state |
| M017 | Bếp đang chế biến | `/merchant/orders` | PARTIAL | Queue sections; not full kitchen board |
| M018 | Điều chỉnh món / giá | — | MISSING | **Defer P1** |
| M019 | Bàn giao & mã tài xế | `/merchant/orders/:orderId` | PARTIAL | Handoff UI thin; state `M019__handoff_code_wrong` |
| M020 | Lịch sử đơn Shop | `/merchant/orders` | PARTIAL | Filter history incomplete |
| M021 | Đơn hủy / bồi hoàn / tranh chấp | — | MISSING | P0 soft; Admin disputes cover ops |
| M022 | Cấu hình nhận đơn auto/manual | `/merchant/settings/accept` | EXISTS | Local/mock toggle; from home + account |
| M023 | Giờ hoạt động / lịch nghỉ | `/merchant/settings/hours` | EXISTS | Local/mock schedule |
| M024 | Chế độ bận / tạm ngưng | `/merchant/settings/busy` | EXISTS | Local/mock busy/pause |
| M025 | Danh mục menu | `/merchant/products` | PARTIAL | Catalog list exists |
| M026 | Danh sách sản phẩm / menu | `/merchant/products` | EXISTS | Live write when `!useMockData` |
| M027 | Tạo / sửa món | `/merchant/products` | PARTIAL | Inline/edit incomplete vs M027 |
| M028 | Biến thể / size / topping | `/merchant/products/:itemId/variants` | EXISTS | Editor shell; no invented topping fees; from products list |
| M029 | Tồn kho còn/hết | `/merchant/products` | PARTIAL | Availability toggle only |
| M030 | Hồ sơ Shop | `/merchant/account` | PARTIAL | |
| M031 | Đánh giá & phản hồi | — | MISSING | **Defer P1** |
| M032 | Khu vực phục vụ & pickup | — | MISSING | P0 soft |
| M033 | Doanh thu & đơn hoàn tất | `/merchant/stats` | PARTIAL | Stats tab ≠ full finance |
| M034 | Số dư & công nợ | — | MISSING | **Defer** partner wallet UI |
| M035 | Quyết toán đối soát | — | MISSING | Admin `/settlements` covers ops |
| M036 | Chi tiết đợt quyết toán | — | MISSING | Admin |
| M037 | Ngân hàng & rút | — | MISSING | **Defer** |
| M038 | Rút tiền & lịch sử | — | MISSING | **Defer** |
| M039 | Báo cáo bán hàng | `/merchant/stats` | PARTIAL | |
| M040 | Chiến dịch khuyến mãi Shop | — | MISSING | **Defer P1** |

**Merchant counts:** EXISTS ~12 · PARTIAL ~20 · MISSING ~8 (+ deferred finance/promo/branch). MOB-FINISH: M013/M015/M016 accept–reject polish; KYB wizard still collapsed vs M002–M010.

> M041–M044 mockups exist beyond WO scope.

---

## 4. Admin — A001–A035

| Design id | Title | Website route | Status | Notes |
|---|---|---|---|---|
| A001 | Đăng nhập quản trị | `/login` | EXISTS | Demo login when `ADMIN_UI_MOCK` |
| A002 | Quên / đặt lại mật khẩu | `/login/forgot` | EXISTS | |
| A003 | Dashboard tổng quan (Golden) | `/overview` (`/` re-exports) | PARTIAL | Route OK; charts/KPI fidelity vs PNG incomplete |
| A004 | Giám sát vận hành trực tiếp | `/monitor` | PARTIAL | Also related: `/exceptions` (list-only) |
| A005 | Danh sách chuyến xe | `/rides` | EXISTS | Nest-backed when `!ADMIN_UI_MOCK` |
| A006 | Chi tiết chuyến xe | `/rides/[code]` | EXISTS | Cancel/reassign live |
| A007 | Danh sách phiên trả giá | `/negotiations` | EXISTS | |
| A008 | Chi tiết phiên trả giá | `/negotiations/[code]` | EXISTS | |
| A009 | Danh sách đơn đồ ăn | `/food-orders` | EXISTS | Nest-backed |
| A010 | Chi tiết đơn đồ ăn | `/food-orders/[code]` | EXISTS | |
| A011 | Danh sách đơn giao hàng | `/deliveries` | EXISTS | **Non-MVP vertical** — keep fixture; defer product |
| A012 | Chi tiết đơn giao hàng | `/deliveries/[code]` | EXISTS | **Non-MVP** |
| A013 | Danh sách yêu cầu dịch vụ A/C | — | MISSING | **Out of MVP** (ui-mock-first) |
| A014 | Chi tiết yêu cầu A/C | — | MISSING | **Out of MVP** |
| A015 | Danh sách khách hàng | `/customers` | PARTIAL | Fixture until Nest ops users API |
| A016 | Chi tiết khách hàng | `/customers/[code]` | PARTIAL | Fixture |
| A017 | Danh sách tài xế | `/drivers` | PARTIAL | Fixture |
| A018 | Chi tiết tài xế | `/drivers/[code]` | PARTIAL | Fixture |
| A019 | Duyệt KYC tài xế | `/drivers/kyc`, `/drivers/kyc/[code]` | EXISTS | Nest approve/reject |
| A020 | Danh sách cửa hàng | `/stores` | PARTIAL | Fixture |
| A021 | Chi tiết cửa hàng | `/stores/[code]` | PARTIAL | Fixture |
| A022 | Duyệt hồ sơ cửa hàng | `/stores/approvals` | EXISTS | Nest partner apps |
| A023 | Kiểm duyệt sản phẩm / thực đơn | `/catalog/moderation` | PARTIAL | |
| A024 | Danh sách giao dịch | `/transactions` | PARTIAL | Fixture |
| A025 | Đối soát & thanh toán đối tác | `/settlements` | EXISTS | Nest day buckets; KPI still fixture |
| A026 | Xử lý hoàn tiền | `/refunds` | PARTIAL | |
| A027 | Khiếu nại / tranh chấp | `/disputes` | EXISTS | |
| A028 | Chi tiết xử lý khiếu nại | `/disputes/[code]` | EXISTS | |
| A029 | Quản lý khuyến mãi | `/promotions` | PARTIAL | **P1 marketing depth** |
| A030 | Quản lý danh mục | `/catalog` | PARTIAL | |
| A031 | Thông báo & CMS | `/notifications` | PARTIAL | |
| A032 | Thống kê & phân tích | `/reports` | PARTIAL | Not full BI |
| A033 | Khu vực & quy tắc giá | `/zones` | PARTIAL | Do not invent price rules |
| A034 | Nhân sự & phân quyền | `/staff` | PARTIAL | Fixture; Nest grants list gap |
| A035 | Cấu hình & nhật ký | `/settings`, `/settings/auth-methods` | PARTIAL | Auth-methods Nest-backed |

**Admin counts:** EXISTS ~16 · PARTIAL ~17 · MISSING 2 (A013–A014, non-MVP).

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

### Shared mobile screens (S001–S028) — route map (abbrev.)

| Id | Title | Route | Status | MVP |
|---|---|---|---|---|
| S001 | Splash / session | app bootstrap | PARTIAL | P0 |
| S002 | Onboarding intro | — | MISSING | soft |
| S003 | Phone login | `/login` | EXISTS | P0 |
| S004 | OTP | `/login/otp` | EXISTS | P0 |
| S005 | First profile | — | MISSING | soft |
| S006 | Permissions | — | MISSING | soft |
| S007 | Role center (Golden) | `/roles` | EXISTS | P0 |
| S008 | Notifications inbox | `/{role}/account/notifications` | EXISTS | P0 |
| S009 | Chat list (free) | — | MISSING | **OOS** free chat; txn chat = sheets |
| S010 | Chat detail (free) | — | MISSING | **OOS**; txn chat on tracking |
| S011 | Account | `/{role}/account` | EXISTS | P0 |
| S012 | Edit profile | — | MISSING | soft |
| S013 | Saved addresses | `/{role}/addresses` | EXISTS | P0 |
| S014 | Add/edit address | — | PARTIAL | via places |
| S015 | Place search | `/{role}/places` | EXISTS | P0 |
| S016 | Map pin | — | PARTIAL | in map flows |
| S017 | Payment methods | — | MISSING | soft (COD on C028) |
| S018 | Link payment | — | MISSING | soft |
| S019 | Help center | `/{role}/help` | EXISTS | P0 |
| S020–S023 | Help article / tickets | — | MISSING | soft |
| S024–S028 | Notif prefs / security / terms / delete / sessions | — | MISSING | soft / legal |

---

## 6. P0 implementation order (MVP Ride + Food only)

Skip deferred rows above. Order = user journey blockers first.

### Mobile P0 — missing / critical partial

| Priority | Ids | Work |
|---|---|---|
| P0-1 | C008 | **Done** — `/offers/:rideId/detail` |
| P0-2 | C012, D023 | C012 **Done**; D023 still PARTIAL on driver ride detail |
| P0-3 | C016, C035 | **Done** — cancel reason routes |
| P0-4 | C014 | **Done** — safety center |
| P0-5 | C036 | Food receipt / invoice after complete |
| P0-6 | D021–D030 | Split driver ride/food lifecycle UI to match phases (map + CTAs) |
| P0-7 | D031, D034 | **Done** — failed + completed job routes |
| P0-8 | M017, M019 | Kitchen board + handoff code fidelity |
| P0-9 | M022–M024 | **Done** — mock settings routes |
| P0-10 | M027–M028 | M028 **Done** (variants shell); M027 still PARTIAL |
| P0-11 | D001–D012, M001–M010 | Expand KYC/KYB steps toward mockups (still mock upload OK) |
| P0-12 | C002/C013, D016 map | PlaceholderMapView chrome done; real Map SDK/keys still later |
| P0-13 | S017 soft | Payment method list if non-COD required by policy |
| P0-14 | Design system | Chip / segmented / banners (see handoff doc) |

### Admin P0 — fidelity / data (routes mostly exist)

| Priority | Ids | Work |
|---|---|---|
| P0-A1 | A003 | Pixel/KPI fidelity vs golden |
| P0-A2 | A015–A018, A020–A021, A024 | Live Nest lists when APIs exist; else honest fixture labels |
| P0-A3 | A004 + `/exceptions` | Monitor polish; intervene stays on ride/food detail |
| P0-A4 | A026, A034 | Refunds UX; staff matrix until grants list API |
| P0-A5 | A011–A014 | **Do not prioritize** (non-MVP) |

### Counts for orchestrator

| Surface | P0 `MISSING` (MVP only) | P0 `PARTIAL` (critical) |
|---|---:|---:|
| Mobile (C+D+M+S soft) | **~18** | **~40** (incl. collapsed KYC/KYB + lifecycle) |
| Admin (A001–A035) | **0** MVP-route missing (2 non-MVP A013–A014) | **~17** fidelity/data |

---

## Evidence sources

- Mockups: `design/mockups/screens/{customer,driver,merchant,admin,shared,states}/`
- Catalog titles: `docs/DealGo_MD_File_List.md`
- Mobile routes: `mobile/lib/app/router/app_router.dart`, `shell_tab.dart`, `*_routes.dart`
- Admin routes: `website/app/**/page.tsx`
- Product scope: `docs/01-product/product-requirements.md` §5
- Prior UI phases: `docs/10-ai-execution/ui-mock-first-strategy.md`

**MOB-FINISH remaining gaps (honest):**
- Map SDK not wired — `PlaceholderMapView` design chrome only (C002/C011/C013/D016/D021/D024/D029).
- KYC/KYB still collapsed wizards (D002–D011, M002–M010).
- Deferred MISSING screens unchanged (C015/C018–C021/C029–C031/C034/C037–C042/C044–C045/C047–C048, wallet D036–D039, M014/M018/M031/…).
- Pixel parity not device-screenshot verified for every frame; golden set polished vs PNG by inspection.
- Illustrative fixture prices/ratings in mock UI are design fixtures — not OPEN policy.

**NOT_VISUALLY_VERIFIED:** full C/D/M matrix beyond golden set; physical device screenshots.
