---
doc_id: DG-SPEC-FOOD-CX-001
title: "DealGo — Thiết kế lại trải nghiệm Food (Customer)"
version: "1.0.0"
status: "P1_IMPLEMENTED"
owner: "UI/UX Lead + Product Owner"
created_at: "2026-11-03"
related:
  - ../../01-product/competitor-benchmark.md
  - ../../02-domain/merchant-and-catalog-rules.md
  - ../../02-domain/food-delivery-fee-negotiation.md
  - ../../10-ai-execution/screen-inventory.md
  - ../../10-ai-execution/design-system-mobile-handoff.md
decisions_respected:
  - DEC-PROD-001
  - DEC-PROD-002
  - DEC-PROD-003
  - DEC-PROD-033
  - DEC-PROD-036
  - DEC-PROD-042
  - DEC-PROD-067
  - DEC-PROD-068
---

# Thiết kế lại trải nghiệm Food (Customer)

> **Trạng thái:** `DRAFT_FOR_REVIEW`. Tài liệu này đặc tả giao diện và hợp đồng dữ liệu; các mức phí, thời gian và chính sách vẫn thuộc `OPEN-*` hiện hành. Không có con số phí nào trong tài liệu này là chính sách production.

## 1. Vấn đề

`screen-inventory.md` ghi toàn bộ luồng Customer Food (`C022`–`C038`) là `LIVE` và `MISSING 0`. Vấn đề không phải thiếu màn hình mà là **mật độ thông tin, thứ bậc thị giác và khả năng khám phá**. Ba nhóm nguyên nhân, xếp theo mức tác động:

### 1.1. Hệ thống đã có dữ liệu, giao diện không dùng

| Dữ liệu | Bằng chứng | Hệ quả |
|---|---|---|
| `FoodItem.imageUrls` (gallery món, `DEC-PROD-042`) | Có trong Prisma (`schema.prisma:813`), map ra repository (`food-prisma.repository.ts:3388`), API trả nguyên item (`food.service.ts:557-570`), parse vào model (`food_models.dart:275`) nhưng `grep imageUrls mobile/lib/features/food/presentation` = 0 kết quả | Mỗi món chỉ có một ảnh, không có gallery |
| Phân trang quán (`page`/`limit`/`total`) | `food.service.ts:447-493` trả `PageResult`; `dio_food_remote_datasource.dart:209-234` không gửi `page`/`limit` | Không thể cuộn thêm; trang chủ tự cắt còn 8 quán (`food_discovery_page.dart:170`) |
| Tìm theo tên món | `food-prisma.repository.ts:266-270` khớp cả `food_items.name` | UI chỉ nhận danh sách quán (`food_search_page.dart`) — gõ tên món không thấy món |
| `StoreOffer.remainingUses`, `endsAt`, `maxDiscountVnd` | `food_models.dart:96-101` | Vé ưu đãi không có hạn dùng hay số lượt |
| `FoodItem.soldCount`, `prepMinutes` | `food_store_page.dart:1848-1885` | Đã hiển thị trong menu; chưa dùng để xếp hạng/upsell |
| Giờ mở–đóng hôm nay | Chỉ có ở store detail (`StoreSchedule.weekly`), không có trong summary | Card quán ngoài danh sách không nói "mở đến mấy giờ" |

### 1.2. Hệ thống thật sự chưa có

| Thiếu | Bằng chứng | Mức |
|---|---|---|
| Ghi chú món | `FoodOrderLine` không có field note (`schema.prisma:957-973`); cart draft không có (`food_cart_draft.dart:100-112`) | Cao — đối thủ lớn đều có và là kỳ vọng cơ bản của người dùng Việt Nam |
| Ghi chú cho quán / tài xế | `FoodOrder` không có `note` (`schema.prisma:861-943`) | Cao |
| Dụng cụ ăn uống | Không có trong model, DTO lẫn checkout | Trung bình |
| Bán thêm / món ăn kèm | Không có quan hệ gợi ý | Trung bình (ảnh hưởng AOV) |

### 1.3. Thiết kế và kiến trúc thông tin chưa đủ

1. Trang Khám phá chỉ có một banner, một hàng 8 quán cuộn ngang và ba dải món; hết nội dung sau khoảng 1,5 màn hình.
2. Thông tin quyết định (phí giao, ETA, khoảng cách, giờ mở, trạng thái bận) nằm cùng một dòng meta nhỏ, không phân cấp.
3. Không có chỗ cho ghi chú, dụng cụ, thời gian dự kiến trong giỏ và checkout (`food_checkout_page.dart:274-287` chỉ có ô thanh toán).
4. Điểm khác biệt cốt lõi — **đàm phán phí giao** (`food-delivery-fee-negotiation.md`) — chỉ là panel nhỏ ở checkout và một card ở tracking.
5. Type scale tuỳ hứng: `titleMedium.copyWith(fontSize: 15)` (`food_discovery_page.dart:863`) và `16` (`:933`).
6. `food_store_page.dart` dài 2.581 dòng, kiêm hero, menu, ưu đãi, bản đồ, đánh giá, thông tin quán.

## 2. Mục tiêu và không mục tiêu

**Mục tiêu**

1. Trang Khám phá trả lời được "ăn gì, ở đâu, giao bao lâu, tốn bao nhiêu" bằng dữ liệu thật, có phân trang.
2. Người dùng tìm được **món** chứ không chỉ quán.
3. Món và đơn có ghi chú; giỏ và checkout có đủ ngữ cảnh trước khi trả tiền.
4. Đàm phán phí giao trở thành yếu tố nhận diện, được giải thích ở đúng thời điểm.
5. Hệ typography/density thống nhất để mọi màn không còn "sơ sài".

**Không mục tiêu**

- Không sao chép layout, màu, icon hay nội dung của ShopeeFood/GrabFood/Green SM Food (`DEC-PROD-003`).
- Không thêm màu nhấn mới: giữ nguyên hệ tím `#6D28D9`, xanh lá/danger/amber/warning hiện có trong token dùng đúng ngữ nghĩa.
- Không mở lại các hạng mục đã `DEFERRED`: đặt trước, tip, ví, hoàn tiền phía khách, self-pickup, nhiều quán/đơn, đa chi nhánh.
- Không đổi route hiện hữu, không phá deep link, không đổi cấu trúc tab.

## 3. Nguyên tắc thiết kế

| # | Nguyên tắc | Cách thực thi |
|---|---|---|
| P1 | Mỗi khối trả lời đúng một câu hỏi | Bảng khối ở §6.1; khối không có dữ liệu thì ẩn, không render khung rỗng |
| P2 | Không bịa dữ liệu | Thiếu rating/ETA/ảnh → ẩn phần tử, không hiển thị số 0 hay sao rỗng |
| P3 | Giá và thời gian luôn đi cùng nhau | Mọi card quán hiển thị ETA và phí; mọi dòng món hiển thị prep time nếu có |
| P4 | Điểm khác biệt phải được kể | Phí giao đề nghị là khối hạng nhất ở checkout và tracking |
| P5 | Một tay | CTA chính trong 1/3 dưới; tap target ≥ 48; không đặt hành động phá huỷ cạnh CTA |
| P6 | Trạng thái có tên | Mọi khối có `loading/empty/error/stale/offline`; quán có `closed/busy/paused/sold-out/outside-area` |
| P7 | Chuyển động có mục đích | 180–240 ms, `easeOut`; stagger tối đa 6 phần tử; tôn trọng reduced motion |

## 4. Bổ sung design system

Chỉ bổ sung, không đổi brand. File: `mobile/lib/core/design_system/tokens/dealgo_tokens.dart`.

### 4.1 Typography — 6 bậc

| Token | Size/Line | Weight | Dùng cho |
|---|---|---|---|
| `display` | 24/28 | 700 | Tổng tiền, số lớn ở hoá đơn |
| `title` | 20/26 | 700 | Tên khối, tên quán ở header store |
| `subtitle` | 16/22 | 700 | Tên quán trong card, tên món trong detail |
| `body` | 14/20 | 400–500 | Mô tả, nội dung chính |
| `meta` | 13/18 | 500 | Dòng `★ 4.8 (120) · 1.2 km · 20–30 phút` |
| `micro` | 12/16 | 500 | Badge, nhãn phụ, "còn 3 lượt" |

**Quy tắc:** trong `features/food/presentation`, cấm `copyWith(fontSize:` trừ `display`. Mọi style lấy từ `Theme.of(context).textTheme` đã map sẵn theo 6 bậc.

### 4.2 Density

| Token | Giá trị |
|---|---|
| `DealGoDensity.blockGap` | 20 (giữa các khối), 24 khi chuyển nhóm chủ đề |
| `DealGoDensity.cardPad` | 12 |
| `DealGoDensity.rowMinHeight` | 96 (menu row, store row) |
| `DealGoDensity.metaGap` | 4 |

Khoảng cách trang: `pageGutter = 16` (đã có), không đổi.

### 4.3 Màu — không thêm hue

| Ngữ nghĩa | Token hiện có | Ghi chú |
|---|---|---|
| CTA, link, tiến trình | `DealGoColors.primary` | Duy nhất một CTA chính mỗi màn |
| Mở cửa, miễn phí giao | `brandGreen` | Chỉ chữ/nhãn, không nền lớn |
| Ưu đãi, giảm giá, huỷ | `danger` / `dangerSurface` | Vé ưu đãi đang dùng; giữ |
| Cảnh báo (bận, sắp hết) | `warning` / `warningSurface` | |
| Đánh giá sao | `amber` | Chỉ icon sao |

Không dùng `primary` làm nền cho toàn bộ section; nền chính là `canvas`, card là `card`, viền `border`.

### 4.4 Component nền cần bổ sung

| Component | Trách nhiệm | Ghi chú |
|---|---|---|
| `FoodStoreCard` (2 biến thể: `feed`, `compact`) | Card quán thống nhất toàn app | Thay `_StoreTile` và `_WideStoreCard` |
| `FoodMetaLine` | Ghép meta theo P2 (tự bỏ phần tử null) | Thay các chuỗi `StoreMetaLine` rời rạc |
| `FoodSectionHeader` | Title + hành động phụ | Đã có `_SectionHeader`, nâng thành component chung |
| `FoodVoucherTicket` | Vé ưu đãi có hạn dùng + lượt còn lại | Tái dùng `_OfferTicket` |
| `FoodDishGallery` | PageView ảnh món + indicator | Mới |
| `FoodNoteField` | Ô ghi chú có đếm ký tự + gợi ý | Mới |
| `FoodUpsellStrip` | Danh sách món ăn kèm | Mới |
| `FoodFareOfferCard` | Đàm phán phí giao | Nâng cấp `food_fare_widgets.dart` |
| `FoodTrackingSummary` | Tóm tắt đơn trong màn theo dõi | Mới |

## 5. Kiến trúc thông tin và route

```
Tab Đồ ăn (/customer/shop)
├─ Khám phá            /customer/shop
├─ Tìm kiếm            /customer/food/search
├─ Danh mục            /customer/food/category?category=<code>
├─ Quán                /customer/food/stores/:storeId
│  └─ Món              /customer/food/stores/:storeId/items/:itemId
├─ Giỏ                 /customer/food/cart
├─ Checkout            /customer/food/checkout
├─ Đặt thành công      /customer/food/order-success
└─ Theo dõi            /customer/food/orders/:orderId
   ├─ Huỷ              /customer/food/orders/:orderId/cancel
   └─ Hoá đơn          /customer/food/orders/:orderId/invoice
```

Route và deep link **giữ nguyên**. Mọi thay đổi nằm trong cấu trúc bên trong màn và trong API contract.

## 6. Đặc tả màn hình

### 6.1. Khám phá (`food_discovery_page.dart`)

**Câu hỏi màn hình trả lời:** "Gần đây có gì đáng ăn, giao nhanh, giá hợp lý?"

```
┌──────────────────────────────────────────────┐
│ [📍 123 Nguyễn Văn Linh ▾]          [👤]     │  sticky header
│ Giao trong ~25 phút                          │  etaMinutes nhỏ nhất còn mở
├──────────────────────────────────────────────┤
│ [🔍 Tìm món hoặc quán...]   [⚙ lọc]          │
│ (Gần tôi) (4.5+) (Ưu đãi) (Đang mở)          │  chip lọc nhanh
├──────────────────────────────────────────────┤
│ Ưu đãi hôm nay                    Xem tất cả │
│ [vé 20k] [vé freeship] [vé 15%]              │
├──────────────────────────────────────────────┤
│ Đặt lại đơn quen                             │
│ [ảnh] Bún bò Huế 24h · 3 món · 55k  [Đặt lại]│
├──────────────────────────────────────────────┤
│ Danh mục                                     │
│ [▦][▦][▦][▦]                                 │  grid 4×2, ảnh thật
│ [▦][▦][▦][▦]                                 │
├──────────────────────────────────────────────┤
│ Quán gần bạn                      Sắp xếp ▾  │
│ ┌────┐ Tên quán                  ★4.8 (120) │
│ │ảnh │ 1.2 km · 20–30 phút · 15k  [Giảm 20k] │  list dọc
│ └────┘ Mở đến 22:00 · Đơn từ 30k             │
│ ...                                          │
│              [Đang tải thêm / Hết]           │  infinite scroll
├──────────────────────────────────────────────┤
│ Món mới / Đang giảm giá (strip món, giữ)     │
├──────────────────────────────────────────────┤
│ Đánh giá cao nhất                 Xem tất cả │
│ (3 card quán dạng compact)                   │
└──────────────────────────────────────────────┘
```

| # | Khối | Nguồn dữ liệu | Ẩn khi | Trạng thái |
|---|---|---|---|---|
| 1 | Header địa chỉ + ETA | `FoodCartCubit.dropoffLabel`; ETA = `etaMinutes` nhỏ nhất trong các quán còn mở ở trang đầu | Chưa chọn địa chỉ → hiện "Chọn địa chỉ giao"; không có ETA → ẩn dòng | stale khi đổi địa chỉ |
| 2 | Tìm kiếm + chip lọc | `FoodFilters` hiện có | Không | — |
| 3 | Voucher wall | `GET /v1/promotions/available?service=FOOD` | Không có voucher | empty ẩn khối |
| 4 | Đặt lại đơn quen | `GET /v1/food/orders?limit=3` | Chưa có đơn hoàn tất | skeleton 1 dòng |
| 5 | Danh mục | `GET /v1/public/food-categories` | Danh sách rỗng | skeleton 8 ô |
| 6 | Quán gần bạn | `GET /v1/food/stores?page&limit` | Trang rỗng → empty state | loading/empty/error/loading-more |
| 7 | Món mới / giảm giá | `featuredItems` của trang hiện có | Không có món | ẩn |
| 8 | Đánh giá cao nhất | `sort_by=rating` trang 1 | Chưa đủ `RATING_STORE_MIN_COUNT` | ẩn |

**Bỏ:** hàng 8 card cuộn ngang hiện tại. Danh sách dọc thay thế hoàn toàn, giữ `DealGoStaggerIn` tối đa 6 phần tử.

**Phân trang:** client gửi `page`/`limit=20`, đọc `total`; cuộn tới cách đáy 400 px thì tải trang kế; đổi filter/sort/địa chỉ thì reset trang và huỷ request cũ (`_generation` hiện có đã làm đúng, mở rộng cho page).

### 6.2. Tìm kiếm (`food_search_page.dart`)

| Thành phần | Thay đổi |
|---|---|
| Gợi ý từ khoá | Lấy từ danh mục + tên món bán chạy của trang đầu; bấm là chạy tìm |
| Lịch sử | Giữ (`food_search_history.dart`) |
| **Kết quả món** | Mới: mỗi dòng có ảnh 64, tên món, giá, tên quán, `★`, khoảng cách, ETA; bấm mở thẳng màn món |
| Kết quả quán | Giữ, dùng `FoodStoreCard(compact)` |
| Lọc/sắp xếp | Giữ (`distance`, `rating`) |

Không có kết quả món → **không** hiển thị tiêu đề nhóm rỗng.

### 6.3. Danh mục (`food_category_page.dart`)

Đổi `_StoreRow` sang `FoodStoreCard(feed)`, thêm phân trang, giữ tiêu đề "Quanh bạn" và bộ lọc sắp xếp. Empty state phải phân biệt: chưa có quán trong danh mục vs ngoài vùng phục vụ.

### 6.4. Chi tiết quán (`food_store_page.dart`)

Tách file, không đổi hành vi:

```text
store/
  food_store_page.dart        # khung, scroll, tabs, state
  store_hero.dart             # cover, logo, tên, trust strip
  store_offers.dart           # ticket + sheet "Xem tất cả"
  store_menu.dart             # search trong quán, category rail, menu list
  store_reviews.dart          # summary, filter sao, danh sách
  store_info.dart             # mô tả, địa chỉ, map, giờ mở cửa
```

**Hero:** cover 16:9, logo 56, overlay gradient `primaryDeep` 0→60%, tên trắng, dưới là **trust strip**:

```
✓ Đã xác minh   ·   🕐 Mở đến 22:00   ·   🛵 Phí giao từ 15k
```

Trust strip dùng `meta` 13/18, chữ `textSecondary` trên nền `card`; chỉ hiển thị mục có dữ liệu thật. Hai mục "Mở đến" và "Phí giao từ" đã có nguồn dữ liệu (§7.2) và nằm trong P3. Mục "Đã xác minh" **không** thuộc phạm vi này: chưa có cờ KYB công khai trong API nên không render, không thay bằng nhãn suy đoán; mock trên minh hoạ vị trí, bản triển khai chỉ có hai mục còn lại.

**Vé ưu đãi:** thêm dòng `micro` "Còn {n} lượt · HSD {dd/MM}" khi server trả; giữ hành vi "Dùng"/"Đã dùng".

**Menu row (`rowMinHeight` 96):**

```
┌──────┐  Tên món                       [Bán chạy]
│ ảnh  │  Mô tả 2 dòng, ellipsis...
│ 96   │  45.000₫  35.000₫   ·  Đã bán 120   (>)
└──────┘                              [ + ]
```

- Giá gạch giữ nguyên logic `originalPriceVnd`.
- `(>)` chỉ hiện khi món có > 1 ảnh → mở `FoodDishGallery`.
- Món `available=false`: ảnh giảm opacity 0.4, nhãn "Tạm hết", không có nút thêm.

**Tách khối để tránh file 2.500 dòng** là yêu cầu bắt buộc, không phải refactor tuỳ chọn: mỗi file ≤ 500 dòng.

### 6.5. Chi tiết món (`food_item_options_page.dart`)

```
┌───────────────────────────────────────┐
│ ‹                        1/3          │  gallery 1:1, indicator
│            [ ảnh món ]                │
├───────────────────────────────────────┤
│ Tên món                               │  subtitle
│ 45.000₫  35.000₫                      │  price row
│ ● Đã bán 120 · Khoảng 15 phút         │  meta
│ Mô tả đầy đủ của quán…                │  body
├───────────────────────────────────────┤
│ Kích cỡ (bắt buộc)                    │
│ ( M ) ( L +5.000₫ )                   │
│ Topping (chọn tối đa 2)               │
│ [ ] Trân châu +5k  [ ] Pudding +7k    │
├───────────────────────────────────────┤
│ Ghi chú cho quán                      │  mới
│ [ Ít cay, không hành…        0/200 ]  │
├───────────────────────────────────────┤
│ Món ăn kèm                            │  mới
│ [ảnh] Trà đào 20k   [ảnh] Chè 15k     │
└───────────────────────────────────────┘
│ [−] 1 [+]        [ Thêm · 45.000₫ ]   │  sticky CTA
```

- Giá trong CTA tính realtime từ option đã chọn; server vẫn là nguồn giá cuối.
- Ô ghi chú giới hạn 200 ký tự, đếm ký tự, không bắt buộc, placeholder theo món ("Ít đá, không đường…").
- Nhóm bắt buộc phải hiển thị "(bắt buộc)"; nút thêm bị disable + lý do khi chưa chọn đủ.
- "Món ăn kèm": tối đa 6, cùng quán, khác `menuCategoryId`, còn bán, sắp theo `soldCount`; ẩn nếu < 2 món.

### 6.6. Giỏ (`food_cart_page.dart`)

```
Quán · ETA 25 phút
─ Lines ───────────────────────────────
2× Bún bò · L · Trân châu         90.000₫
   "ít cay" · [Sửa] [Xoá]
─ Mua thêm cho đủ bữa ────────────────  mới
[ảnh] Trà đào 20k [+]   [ảnh] Chè 15k [+]
─ Giao hàng ──────────────────────────
📍 123 Nguyễn Văn Linh          [Đổi]
⏱ Giao trong ~25 phút
─ Ghi chú ────────────────────────────  mới
[ Ghi chú cho quán / tài xế    0/300 ]
Dụng cụ ăn uống            (Có) (Không)
─ Tạm tính 90.000₫ ──────────────────
Phí giao 15.000₫ · Giảm 10.000₫
Tổng 95.000₫
[ Tiếp tục · 95.000₫ ]
```

- Thiếu món tối thiểu: giữ thông báo hiện có, CTA hiển thị "Còn thiếu X" và không cho tiếp tục.
- Upsell: chỉ món còn bán, khác nhóm với món đã có, không trùng line, tối đa 6.
- Đổi quán → xoá ghi chú/upsell của quán cũ (cart đã reset theo `storeChanged`).

### 6.7. Checkout (`food_checkout_page.dart`)

```
Địa chỉ giao
📍 123 Nguyễn Văn Linh        [Đổi]
──────────────────────────────────────
PHÍ GIAO — BẠN ĐỀ NGHỊ            ★ khối chính
Gợi ý cho quãng này: 15.000₫
      [−]   15.000₫   [+]
Tài xế có thể nhận đúng mức này hoặc trả giá cao hơn.
Bạn còn 3 lần nâng giá khi đang chờ tài xế.
──────────────────────────────────────
Voucher            [Chọn hoặc nhập mã  ›]
Ghi chú cho quán / tài xế
[ … 0/300 ]
Dụng cụ ăn uống    (Có) (Không)
──────────────────────────────────────
Tạm tính · Phí giao · Giảm giá · Tổng
[ Đặt đơn · 95.000₫ ]
```

- Bước giá, sàn/trần và số lần nâng lấy từ server (`FOOD_FARE_STEP_VND`, `FOOD_FARE_FLOOR_PERCENT_OF_SUGGESTED`, `FOOD_MAX_FARE_RAISES_PER_ORDER`); không hardcode.
- Khi `FOOD_DELIVERY_FEE_MODE=FIXED`: khối đổi thành "Phí giao cố định 15.000₫", không có stepper, không có câu "tài xế có thể trả giá".
- Lỗi `FOOD_OFFER_AMOUNT_INVALID` / `FOOD_OFFER_EXPIRED` hiển thị inline ngay dưới stepper, không chỉ snackbar.
- Voucher panel giữ nguyên (`food_checkout_widgets.dart:797`).

### 6.8. Đặt thành công (`food_order_success_page.dart`)

Giữ luồng hiện có, thêm: ETA dự kiến, phí giao đã chốt, dòng "Tài xế sẽ thấy mức bạn đề nghị", CTA chính "Theo dõi đơn", phụ "Về trang chủ".

### 6.9. Theo dõi (`food_tracking_page.dart`)

| Khối | Nội dung |
|---|---|
| Header | Copy theo phase (đã có `food_tracking_page.dart:765-793`) + ETA đếm ngược |
| Timeline | 5 bước + timestamp (đã có `:395`) |
| Bản đồ | Giữ `LiveDriverMap`, nhãn stale khi GPS quá hạn |
| Driver card | Tên, đánh giá, gọi/chat (đã có) |
| **Tóm tắt đơn** | Quán, số món, tổng, phí đã chốt, "Xem hoá đơn" |
| Fare card | Đang chờ / có N đề nghị / đã chốt; dùng `FoodFareOfferCard` |
| Trợ giúp | Huỷ đơn (theo phase), trợ giúp, gọi quán |

### 6.10. Hoá đơn (`food_invoice_page.dart`)

Giữ breakdown hiện có; thêm ghi chú món/đơn nếu có, `utensils`, và CTA "Đặt lại" (đã có `food_reorder_button.dart`).

## 7. Hợp đồng dữ liệu

### 7.1. Prisma (additive, không phá dữ liệu)

```prisma
model FoodOrderLine {
  // ...
  /// Customer note for this line ("ít cay, không hành"); null = none.
  note String? @db.VarChar(200)
}

model FoodOrder {
  // ...
  /// Customer note for the store / driver; null = none.
  note String? @db.VarChar(300)
  /// Cutlery requested with this order (default true per market norm).
  utensils Boolean @default(true)
}
```

Migration: `20261103120000_food_order_notes` — chỉ `ADD COLUMN`, cột nullable hoặc có default, không backfill.

### 7.2. API

| Method | Path | Thay đổi |
|---|---|---|
| `GET` | `/v1/food/stores` | Không đổi shape; **client** gửi `page`/`limit` và đọc `total` |
| `GET` | `/v1/food/stores` | Thêm `closesAtToday: "22:00" \| null` vào mỗi item (tính từ `food_store_hours` + `lastOrderMinutes`) |
| `GET` | `/v1/food/search?q&lat&lng&page&limit` | **Mới**: `{ dishes: PageResult<DishHit>, stores: PageResult<StoreBrowseItem> }` |
| `GET` | `/v1/food/stores/:id/suggestions?exclude=<ids>` | **Mới (P3)**: tối đa 6 món cùng quán, khác nhóm, còn bán |
| `POST` | `/v1/food/orders` | `note?`, `utensils?`, mỗi line `note?` |
| `GET` | `/v1/food/orders/:id`, `/orders`, merchant/driver/ops view | Trả `note`, `utensils`, line `note` |

```ts
interface DishHit {
  item: { id, name, priceVnd, originalPriceVnd, imageUrl, soldCount, prepMinutes };
  store: { id, name, distanceKm, etaMinutes, deliveryFeeFromVnd, openNow, closedReason };
}
```

**Quy tắc:** ghi chú là dữ liệu người dùng, hiển thị nguyên văn cho quán và tài xế nhưng phải escape ở mọi output; không đưa ghi chú vào analytics/log.

### 7.3. Mobile

| File | Thay đổi |
|---|---|
| `food_models.dart` | `FoodOrderLineDraft.note`, `PlacedFoodOrder.note/utensils`, `FoodStoreSummary.closesAtToday` |
| `food_cart_cubit.dart` | `note` (đơn), `utensils`, `line.note`; reset theo `storeChanged` |
| `food_cart_draft.dart` | Lưu/khôi phục `note`, `utensils`, line `note` |
| `place_food_order_body.dart` | Gửi `note`, `utensils`, line `note` |
| `food_search_page.dart` | Gọi endpoint search mới, render nhóm món |
| `food_discovery_cubit.dart` | Thêm `page`/`hasMore`/`loadMore`, giữ `_generation` |

## 8. i18n

Thêm key vào **cả** `app_vi.arb` và `app_en.arb` (đặt cạnh các key `foodDiscovery*` hiện có):

| Key | VI |
|---|---|
| `foodDeliverIn` | `Giao trong ~{minutes} phút` |
| `foodStoreOpenUntil` | `Mở đến {time}` |
| `foodStoreFeeFrom` | `Phí giao từ {amount}` |
| `foodStoreMinOrderShort` | `Đơn từ {amount}` |
| `foodVoucherRemaining` | `Còn {count} lượt` |
| `foodVoucherExpires` | `HSD {date}` |
| `foodReorderTitle` | `Đặt lại đơn quen` |
| `foodReorderAction` | `Đặt lại` |
| `foodSearchDishes` | `Món ăn` |
| `foodSearchStores` | `Quán` |
| `foodItemNoteLabel` | `Ghi chú cho quán` |
| `foodItemNoteHint` | `Ví dụ: ít cay, không hành…` |
| `foodItemNoteCounter` | `{count}/200` |
| `foodItemUpsellTitle` | `Món ăn kèm` |
| `foodCartUpsellTitle` | `Mua thêm cho đủ bữa` |
| `foodOrderNoteLabel` | `Ghi chú cho quán / tài xế` |
| `foodOrderNoteHint` | `Ví dụ: gọi trước khi tới, để ở lễ tân…` |
| `foodUtensilsLabel` | `Dụng cụ ăn uống` |
| `foodUtensilsYes` | `Có` |
| `foodUtensilsNo` | `Không` |
| `foodFareSuggestedLabel` | `Gợi ý cho quãng này` |
| `foodFareExplainNegotiate` | `Tài xế có thể nhận đúng mức này hoặc trả giá cao hơn.` |
| `foodFareRaisesLeft` | `Bạn còn {count} lần nâng giá khi đang chờ tài xế.` |
| `foodFareFixedLabel` | `Phí giao cố định {amount}` |
| `foodTrackingOrderSummary` | `Tóm tắt đơn` |
| `foodEmptyNoStoresInCategory` | `Chưa có quán trong danh mục này` |
| `foodEmptyOutOfArea` | `DealGo chưa giao tới khu vực này` |

## 9. Trạng thái và trường hợp biên

| Bề mặt | Trạng thái bắt buộc |
|---|---|
| Khối feed | loading (skeleton đúng hình dạng), empty (ẩn khối hoặc copy rõ), error (retry tại chỗ), stale (đang refresh, giữ nội dung cũ + progress 2 px) |
| Danh sách quán | `loading-more`, `end-of-list`, `offline` |
| Card quán | `openNow`, `closed` (overlay + lý do), `BUSY` (nhãn "Quán đang bận"), `PAUSED` (nhãn "Tạm ngừng nhận đơn") |
| Món | `sold-out`, `moderation pending` (không hiện), `price changed` (checkout revalidate) |
| Giỏ | `min-order shortfall`, `store changed`, `item removed` |
| Checkout | `submitting` (khoá CTA + chặn back), `repriced`, `offline`, `voucher rejected`, `fare out of range` |
| Theo dõi | `no driver yet` (fare card), `GPS stale`, `reconnect`, `merchant busy` |
| Chung | `forbidden`, `session expired` |

## 10. Accessibility và chuyển động

- Tap target ≥ 48 (`DealGoDimensions.minTapTarget`); nút "+" trong menu row được nới hit area bằng `Padding` trong suốt, không tăng kích thước thị giác.
- Mọi card quán có `Semantics(button: true, label: "<tên>, <rating>, <khoảng cách>, <ETA>, <phí>")`.
- Không truyền đạt trạng thái chỉ bằng màu: `Tạm hết` luôn kèm nhãn chữ.
- Contrast: chữ `textTertiary` chỉ dùng cho micro ≥ 12, không dùng cho giá.
- Text scale 1.3: card quán chuyển sang layout dọc, không cắt tên; menu row giãn chiều cao thay vì ellipsis tên món.
- Reduced motion: tắt `DealGoStaggerIn` và hero parallax.
- Stagger tối đa 6 phần tử đầu; danh sách dài không animate từng dòng.

## 11. Hiệu năng

- Feed dùng `CustomScrollView` + `SliverList`, không lồng `SingleChildScrollView` ngang trong list dọc ngoài các strip món có chủ đích.
- Ảnh: `cacheWidth` theo kích thước hiển thị (menu 96→192 px @2x, card 236→472 px @2x); placeholder asset theo danh mục (đã có `foodDishFallbackImage`).
- Prefetch ảnh trang kế chỉ khi người dùng cuộn qua 50% danh sách.
- Ghi chú dùng `TextEditingController` theo vòng đời widget, không giữ trong Bloc.

## 12. Kế hoạch kiểm thử

| Loại | Nội dung |
|---|---|
| Widget | Mỗi khối feed có test `loading/empty/error/data`; `FoodMetaLine` bỏ phần tử null; `FoodStoreCard` với mọi trạng thái |
| Cubit | Phân trang: tải trang 2, huỷ khi đổi filter, không trùng item, `hasMore` đúng |
| Ghi chú | Giới hạn 200/300 ký tự, lưu vào draft, reset khi đổi quán, gửi đúng payload |
| Đàm phán phí | Stepper theo step server; chặn khi chạm trần; `FIXED` mode ẩn stepper |
| Golden | 3 viewport (360/390/430) × 6 màn; text scale 1.0 và 1.3 |
| E2E | Tìm món → mở món → chọn topping + ghi chú → giỏ → checkout (đổi phí giao) → theo dõi → hoá đơn |
| Backend | Migration additive chạy trên DB có dữ liệu; note đi qua merchant/driver/ops view; search trả đúng nhóm và phân trang |

Tận dụng `mobile/test/screenshots/screens_capture_test.dart` và `mobile/test/features/food/food_fare_negotiation_test.dart` hiện có.

## 13. Phân kỳ

| Phase | Phạm vi | Backend | Tiêu chí hoàn thành |
|---|---|---|---|
| **P1** | Typography 6 bậc, density, `FoodStoreCard`, feed dọc + phân trang, gallery món, tách `food_store_page.dart` | Không | Cuộn feed tải thêm trang và dừng đúng `isLast` (không còn lát cắt 8 quán); không còn `copyWith(fontSize:` trong feature |
| **P2** | Ghi chú món/đơn, dụng cụ, upsell giỏ, khối phí giao ở checkout | Migration + DTO + 3 view | Đơn có ghi chú hiển thị đúng ở khách, quán, tài xế, ops |
| **P3** | Search theo món, voucher wall, đặt lại, `closesAtToday`, trust strip (mở đến + phí giao từ) | 2 endpoint + 1 field | Gõ tên món ra kết quả món; card quán có "mở đến" và "phí giao từ" |
| **P4** | Tracking summary, fare storytelling, hoá đơn, golden/motion | Không | Golden 6 màn pass; test a11y pass |

Mỗi phase phải chạy được độc lập và không phá client cũ.

## 14. Tiêu chí chấp nhận

1. Trang Khám phá không còn giới hạn 8 quán; cuộn tải thêm, hết danh sách có nhãn rõ.
2. Không khối nào hiển thị số liệu không có thật (rating 0, ETA giả, "0 quán").
3. Tìm "bún bò" trả về cả món và quán, món đứng trước.
4. Món có nhiều ảnh mở được gallery; ảnh đơn vẫn hoạt động khi chỉ có một ảnh.
5. Ghi chú món/đơn đi trọn vòng: nhập → giỏ → checkout → đơn → quán/tài xế → hoá đơn.
6. Checkout giải thích được phí giao trong 3 dòng chữ, đúng mode `NEGOTIATE`/`FIXED`.
7. Không route/deep link nào đổi; back stack không mất giỏ.
8. Không có màu nhấn mới ngoài hệ token hiện tại.
9. `flutter analyze` sạch; test mới cho mỗi khối; golden 3 viewport.
10. Tài liệu `screen-inventory.md` được cập nhật trạng thái từng mục sau khi merge.

## 15. Quyết định còn mở

| ID | Câu hỏi | Owner | Mặc định đề xuất |
|---|---|---|---|
| `FOOD-CX-OD-01` | Dụng cụ ăn uống mặc định Có hay Không | Product + Ops | Có (`utensils = true`) |
| `FOOD-CX-OD-02` | Giới hạn ký tự ghi chú (200/300) và có kiểm duyệt nội dung không | Product + Trust | 200 ký tự món, 300 ký tự đơn, không kiểm duyệt tự động ở MVP |
| `FOOD-CX-OD-03` | Upsell tính ở server hay client | Tech | Client ở P2 (từ `store.items`), server ở P3 |
| `FOOD-CX-OD-04` | Shape cuối của endpoint search (gộp vào `stores` hay tách) | Tech | Tách endpoint để phân trang độc lập |
| `FOOD-CX-OD-05` | Có hiển thị số quán đang mở ở header không | Product | Không, chỉ ETA (tránh số liệu sai khi phân trang) |
| `FOOD-CX-OD-06` | Voucher wall lấy "mã khả dụng" hay "mã đã lưu" | Product | Mã khả dụng cho dịch vụ FOOD (`/v1/promotions/available`) |

## 16. Phụ lục bằng chứng

- Hiện trạng màn hình: `docs/10-ai-execution/screen-inventory.md` §1 (`C022`–`C038`).
- Trang chủ chỉ 8 quán: `mobile/lib/features/food/presentation/pages/food_discovery_page.dart:170`.
- Không gửi phân trang: `mobile/lib/features/food/data/datasources/dio_food_remote_datasource.dart:209-234`.
- Server trả `PageResult`: `backend/src/modules/food-order/food.service.ts:447-493`.
- Tìm theo tên món ở SQL: `backend/src/modules/food-order/food-prisma.repository.ts:266-270`.
- Gallery chưa render: `backend/prisma/schema.prisma:813`, `mobile/lib/features/food/domain/entities/food_models.dart:275`.
- Không có ghi chú: `backend/prisma/schema.prisma:861-973`.
- Checkout chỉ có ô thanh toán: `mobile/lib/features/food/presentation/pages/food_checkout_page.dart:274-287`.
- Đàm phán phí giao đã chạy: `docs/02-domain/food-delivery-fee-negotiation.md` §3–§5.
- Đối thủ (dữ liệu công khai 2026): ShopeeFood hướng dẫn có ghi chú món, dụng cụ ăn uống, tip, giao tận cửa, một quán/đơn; Green SM Food nêu ghi chú tài xế, mã khuyến mãi, phụ phí ban đêm/thời tiết/lễ, giới hạn 15 km. Ghi nhận như **pattern tham khảo**, không phải chính sách DealGo (`DEC-PROD-003`).
