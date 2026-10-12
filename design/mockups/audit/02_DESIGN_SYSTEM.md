# DealGo — Design System v0.1 (proposed baseline)

## Nguyên tắc

Một product, ba mode: **Khách hàng / Shop / Tài xế**. Giữ cùng brand, cùng ngôn ngữ UI, cùng iconography, cùng component; mode chỉ thay điều hướng, nội dung và chức năng phù hợp vai trò. C001 là nguồn nhận diện, KHÔNG phải quy tắc bắt buộc tất cả màn phải có banner lớn.

Các giá trị token dưới đây là **đề xuất thống nhất** từ mockup và cần duyệt trên Flutter trước khi trở thành source of truth.

## 1. Foundation

### Màu

| Token | Giá trị | Ý nghĩa |
|---|---|---|
| `brand.purple.600` | `#6D28D9` | Primary CTA/selected/action |
| `brand.purple.700` | `#5820B5` | Pressed/dark primary |
| `brand.purple.100` | `#F2EAFF` | Background tint, selected container |
| `brand.green.600` | `#16A34A` | Điểm nhấn nhận diện, success |
| `brand.green.100` | `#E7F8EE` | Success container |
| `semantic.warning` | `#CA7A17` | Sắp hết hạn, cần chú ý |
| `semantic.error` | `#D63354` | Destructive, lỗi, hủy |
| `semantic.info` | `#2463C8` | Chỉ dẫn và trạng thái thông tin |
| `surface.canvas` | `#FBFAFD` | Background |
| `surface.card` | `#FFFFFF` | Card, sheet |
| `surface.subtle` | `#F6F3FA` | Input, segmented inactive |
| `text.primary` | `#171B2C` | Content chính |
| `text.secondary` | `#666B80` | Metadata/hint |
| `border.default` | `#E7E3EF` | Border mảnh |

Gradient CTA (tùy chọn, chỉ một style): `#6029CF → #843BDA`. Không kết hợp nhiều gradient tím khác nhau theo từng màn. Màu green không được dùng chỉ để trang trí trạng thái nguy hiểm.

### Typography (Flutter logical sp)

| Vai trò | Kích thước / line-height gợi ý | Cân nặng |
|---|---|---|
| Hero/Home display | 28 / 34 | 800 |
| Page title | 22 / 28 | 750 |
| Section heading | 18 / 24 | 700 |
| Card title | 16 / 22 | 700 |
| Body | 14–16 / 20–24 | 400–500 |
| Secondary | 13 / 19 | 400–500 |
| Caption | 12 / 17 | 500 |
| CTA | 16 / 22 | 700 |
| Monetary highlight | 24–30 / 30–36 | 800 |

Một font gia đình hỗ trợ dấu tiếng Việt đầy đủ, **ưu tiên Inter** nếu đội dự án đã dùng Google Fonts; fallback theo platform. Không bê `font-size:10px` từ HTML dựng mockup thành `10sp` production. Tránh text overflow với textScale 1.3/1.6.

### Layout & Shape

- Spacing: `4, 8, 12, 16, 20, 24, 32` dp (base 4).
- Page horizontal padding: `16dp` trên phone; tablet theo constraint, không kéo full width form.
- Card radius: `20dp`; input radius `12dp`; primary button radius `16dp`; chip radius `999dp`.
- Card border: 1dp, shadow rất nhẹ; không shadow mọi text input.
- Action target tối thiểu khoảng **48×48dp** (đáp ứng Android); với iOS tương đương tối thiểu 44pt.
- Button height: 52–56dp; tuyệt đối tách CTA fixed khỏi nội dung scroll bằng SafeArea.
- Screen logical targets để review: 360×800, 390×844, 430×932; tablet 600dp trở lên nếu trong phạm vi.

## 2. Shared Components — một implementation dùng cho 3 role

| Component | Biến thể | Quy tắc |
|---|---|---|
| `DealGoAppBar` | back/title/brand/actions | Chiều cao do platform+SafeArea, logo đúng asset và consistent. |
| `DealGoPrimaryButton` | filled/outline/destructive/disabled/loading | Loading không lặp submit; disable có lý do. |
| `DealGoCard` | default/selected/semantic | Selected dùng border + icon/label, không chỉ màu. |
| `DealGoStatusBadge` | pending/success/error/info | Mapping từ domain status, không viết strings tùy ý. |
| `DealGoTextField` | normal/error/readOnly/OTP | Error text, keyboard type, autofill, hint semantics. |
| `DealGoMoney` | amount/discount/refund/fee/held | Định dạng VND, dấu +/- có ngữ nghĩa. |
| `DealGoRouteSummary` | ride/food/compact/map | Pickup/dropoff/ETA lấy cùng domain model. |
| `DealGoMapSurface` | select/preview/navigation | Attribution/map controls/skeleton/location-permission. |
| `DealGoOfferCard` | driver/buyer/supplier | Quote ID, countdown, valid/expired, ETA & price. |
| `DealGoOrderTimeline` | customer/shop/driver | Một status model, 3 presentation adapters. |
| `DealGoProductRow` | item/customization/stock | Variant/size/topping và ảnh theo snapshot. |
| `DealGoBottomCTA` | single/dual/action with summary | Sticky và SafeArea, không che keyboard/content. |
| `DealGoBottomSheet` | filter/select/confirm/permission | Drag/keyboard/back/dismiss policy nhất quán. |
| `DealGoEmptyState` | empty/offline/error/retry | Không tự tạo route mới. |

## 3. Navigation: 1 app, 3 role shells

**Customer 5 tabs (đang có trên C001):** Trang chủ / Chuyến đi / Đặt / Mua hàng / Tài khoản. Card **Đồ ăn** đi vào `C022`. Đừng tự đổi vị trí 5 tabs giữa các màn thuộc customer shell.

**Shop 5 tabs đề xuất:** Tổng quan / Đơn hàng / Sản phẩm / Thống kê / Tài khoản. Định nghĩa một lần từ `M013` và dùng cho shop root routes. Các màn onboarding KYC không có bottom nav.

**Driver 5 tabs đề xuất:** Trang chủ / Công việc / Thu nhập / Thông báo / Tài khoản. Luồng active navigation (bản đồ, OTP, nhận/giao) có ưu tiên thông tin tác nghiệp; có thể ẩn bottom tabs.

`S007` thay active role; dùng stack độc lập mỗi role nếu phù hợp, nhưng các công việc pending/online vẫn thuộc backend và cần UI badge thông báo xuyên role. Kiểm tra deep link mở đúng mode và user có quyền.

## 4. UX patterns bắt buộc

1. **Giá và quotation:** quote snapshot có hạn dùng, phụ phí, giảm giá, timestamp; hiển thị thay đổi giá trước xác nhận, không đổi âm thầm.
2. **Tài chính:** trình bày cụ thể thanh toán khách, tiền shop, thu hộ COD, thu nhập driver, phí nền tảng, hoàn tiền và khoản tạm giữ.
3. **KYC:** progress step, thông tin phải sửa, lý do từ chối, trạng thái đang xét duyệt, re-verification.
4. **Giao nhận:** proof, OTP và mốc thời gian; hỗ trợ issue handling và offline recovery.
5. **Không điều hướng sai:** `back` theo flow (quay lại không reset quote/order nếu chưa thực sự huỷ).
6. **Confirmation:** các hành động destructive/bất hồi phục có confirm + lý do/tác động.
7. **Accessibility:** tương phản rõ, `Semantics`, thứ tự focus, mô tả badge và trạng thái, test font scale.

## 5. Component states

Mỗi component quan trọng phải có tối thiểu `default`, `loading`, `disabled`, `error`, `success` (nếu phù hợp). Mỗi màn quan trọng phải có `initial`, `loading`, `data`, `empty`, `error`, `offline` (nếu có network). Các màn quote/matching bổ sung `expired`, `withdrawn`, `selected-by-other`, `retry`.

## 6. Brand asset / imagery

- Logo chính **DealGo**: tím `Deal`, xanh `Go`, copy đúng chữ hoa/chữ thường. Tạo SVG source/vector asset được phép sử dụng; không cắt phần chữ từ ảnh screenshot làm logo production.
- `DealGo Driver/Shop` là nhãn mode, không phải brand thay thế.
- Hình món, nhà hàng, xe, avatar, bản đồ dùng asset registry + nguồn/licensing hợp lệ. C001 có hero Đà Nẵng; các route tác nghiệp ưu tiên thông tin thay ảnh lớn.
- Cố định một icon family, stroke 1.8–2.2dp; không trộn icon 3D, emoji, outline trong cùng công năng trừ illustration có chủ đích.

## 7. Responsive acceptance

Test với SafeArea iPhone có notch, Android hole-punch/gestures; keyboard mở ở OTP, form, chat, tìm kiếm, đề xuất giá. Scroll tới trường cuối và submit được; nút CTA không che bottom sheet, không va hệ thống navigation; chữ tăng 1.6x vẫn không clip thông tin mức giá/cảnh báo.
