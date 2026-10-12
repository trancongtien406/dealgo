# DealGo Design System – Freeze Candidate v1.0

**Chưa freeze chính thức.** Đây là baseline đề xuất từ ảnh trang chủ C001 và các màn của Phase 19.1–19.4. Chốt sau khi thử Flutter thật trên iOS/Android.

## Identity

- Thương hiệu: Deal (tím) + Go (xanh lá), chuẩn chính tả `DealGo`.
- Primary `#6D28D9`, primary pressed `#5820B5`, subtle purple `#F2EAFF`.
- Brand green `#16A34A`, success surface `#E7F8EE`; green text `#13743A`.
- Warning text `#995B0E`, error text `#C12745`.
- Canvas `#FBFAFD`, card `#FFFFFF`, border `#E7E3EF`, text `#171B2C`, secondary `#666B80`.
- CTA luôn tím primary, trừ ngữ nghĩa đặc biệt. Tránh gradient khác nhau giữa các flow.

## Component API cần xây

`DealGoAppBar`, `DealGoCard`, `DealGoPrimaryButton`, `DealGoStatusBadge`, `DealGoPrice`, `DealGoEmptyState`, `DealGoLoadingState`, `DealGoErrorState`, `DealGoOfflineState`, `DealGoExpiredState`, `DealGoConflictState`, `DealGoOrderTimeline`, `DealGoMapSurface`, `DealGoQuoteCard`, `DealGoBottomCTA`.

## Layout

- Spacing scale (dp): 4/8/12/16/20/24/32.
- Page gutter 16dp, card radius 20dp, button radius 16dp, input radius 12dp.
- Buttons 52–56dp height, hit area >=48dp; primary CTA SafeArea và body scroll riêng.
- Headings 22–24sp; body 14–16sp; caption >=12sp; actual Vietnamese font scale test required.

## Role shells

- Customer: Trang chủ / Chuyến đi / Đặt / Mua hàng / Tài khoản (C001 là visual source).
- Shop: Tổng quan / Đơn hàng / Sản phẩm / Thống kê / Tài khoản.
- Driver: Trang chủ / Công việc / Thu nhập / Thông báo / Tài khoản.

## Freeze gates

- [ ] Sign-off từ chủ dự án về mẫu C001, C028, M013, D016, S007 và 25 state variants.
- [ ] Icon set 1 họ, có license và brand logo vector source.
- [ ] Light theme và dark theme (nếu triển khai) golden-test được.
- [ ] UI state contract + domain state machine mapping có test backend.
- [ ] Định nghĩa hệ thống animation (transition, shimmer reduced motion) không làm đảo trạng thái.
- [ ] Responsive + accessibility + multiline Vietnamese verified.
