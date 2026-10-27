---
doc_id: ARCH-HOME-BANNERS
title: "Banner trang chủ do admin quản lý"
status: "CURRENT"
owner: "Tech Lead"
last_updated: "2026-10-27"
related: [ARCH-PLACES-SEARCH]
---

# Banner trang chủ do admin quản lý

Banner đầu trang chủ app (hiện là trang chủ khách hàng) lấy từ server; admin tạo, sửa, sắp xếp,
bật/tắt trên web admin tại **Cài đặt → Banner trang chủ** (`/settings/home-banners`). App không còn banner cứng.

## Dữ liệu (`backend/prisma/schema.prisma`)

- `HomeBanner`: `title`, `subtitle?`, `imageKey?`, `ctaUrl?`, `audiences[]` (CUSTOMER/DRIVER/MERCHANT),
  `service` (ALL/RIDE/FOOD), `regionCode?`, `startsAt?`/`endsAt?`, `sortOrder`, `active`, người tạo/sửa.
- `HomeBannerDailyStat`: bộ đếm `impressions`/`clicks` theo banner và theo ngày (giờ Việt Nam, UTC+7).
- Migration `20261112090000_home_banners`. Thao tác admin ghi audit `HOME_BANNER_CREATE/UPDATE/DELETE/REORDER`.

## Trạng thái

| State | Nghĩa |
|---|---|
| `NO_IMAGE` | Chưa có ảnh; không thể bật (400 `HOME_BANNER_IMAGE_REQUIRED`). |
| `INACTIVE` | Đã tắt. |
| `SCHEDULED` | Đang bật, chưa tới `startsAt`. |
| `EXPIRED` | Đã qua `endsAt`. |
| `LIVE` | Đang hiển thị. |

## CTA

- Trống: banner chỉ để xem, chạm không làm gì.
- `https://…`: mở bằng trình duyệt trong app (`LaunchMode.inAppBrowserView`, lỗi thì mở trình duyệt hệ thống).
- Đường dẫn trong app (`/customer/shop`) hoặc `dealgo://customer/shop` (lưu thành `/customer/shop`):
  phải nằm trong allowlist của **mọi** nhóm người xem được chọn (`home-banner.ts` `APP_PATHS`) —
  khách: `/customer`, `/customer/book|shop|trips`, `/customer/food/stores/<id>`, `/customer/account/vouchers|notifications|help`;
  tài xế: `/driver`, `/driver/jobs|earnings`, `/driver/account/notifications|help`;
  cửa hàng: `/merchant`, `/merchant/orders|products`, `/merchant/account/notifications|help`.
  Sai → 400 `HOME_BANNER_CTA_NOT_ALLOWED`. Web admin kiểm tra cùng allowlist trước khi gửi.
- App vẫn đưa đường dẫn qua `resolveLinkLocation`, nên link không hợp lệ với vai trò hiện tại không bao giờ mở trang chết.

## API

Công khai (không cần đăng nhập):

- `GET /v1/public/home-banners?role=CUSTOMER&service=&region=&lat=&lng=` →
  `{ items: [{ id, title, subtitle, imageUrl, cta: { kind: app|web, target } | null, service }] }`.
  Chỉ banner `LIVE`, đúng vai trò, đúng dịch vụ (hoặc ALL), và không gắn vùng hoặc đúng vùng
  (vùng lấy từ `region` hoặc suy từ `lat`/`lng`; không biết vùng → chỉ banner không gắn vùng). Tối đa 8, theo `sortOrder`.
  Cache trong server 30 s; `Cache-Control: public, max-age=60`.
- `GET /v1/public/home-banners/images/<id>/<uuid>.<ext>`: ảnh (tên file đổi mỗi lần tải lên nên cache lâu được).
- `POST /v1/public/home-banners/events` `{ events: [{ bannerId, type: IMPRESSION|CLICK }] }` (≤ 50, giới hạn 60 lần/phút/IP).

Ops (`/v1/ops/home-banners`, quyền `content.write` cho thao tác ghi): `GET` (kèm state và thống kê tổng/7 ngày/CTR),
`POST`, `PATCH :id`, `DELETE :id`, `POST :id/image` (data URL JPEG/PNG/WebP, ≤ 2 MB), `POST reorder` `{ ids }`.
Web admin gọi qua BFF `website/app/api/ops/home-banners/*` (kiểm tra same-origin và lọc trường) và hiển thị ảnh qua
`website/app/api/public/home-banners/images/[id]/[file]`.

## Ảnh

- Tỉ lệ 2:1, khuyến nghị 1200×600, **không chữ trong ảnh**: app tự vẽ tiêu đề/phụ đề trên lớp gradient tím bên trái.
  Bản xem trước trên web admin dựng đúng khung này.

## Mobile (`mobile/lib/features/home_banner/`)

- `HomeBannerCarousel` (trang chủ khách hàng, ngay dưới ô tìm kiếm): khung 2:1, bo góc 20.
  - Đang tải: khối skeleton. Rỗng hoặc lỗi: ẩn hẳn (không chừa khoảng trống).
  - Tự chuyển mỗi 5 s khi có ≥ 2 banner; dừng khi người dùng chạm giữ, khi trang bị che/khác tab (`TickerMode`),
    khi app ở nền, và khi hệ thống bật giảm chuyển động.
  - Số chấm chỉ báo = số banner (ẩn khi chỉ có 1).
  - Gửi `lat`/`lng` khi đã có quyền vị trí (không hỏi quyền, chờ tối đa 1,5 s).
  - Ảnh: `Image.network` (cache bộ nhớ của Flutter) và tải trước ảnh kế tiếp. Chưa có cache trên đĩa.
- `HomeBannerTracker` (một bản cho cả phiên app): mỗi banner tính 1 lượt hiển thị/phiên, chỉ khi carousel đang hiện;
  gom sự kiện gửi sau 2 s, lượt chạm gửi ngay; đồng thời ghi `home_banner_impression` / `home_banner_click` vào `AnalyticsPort`.
- Bản build mock/test dùng `FakeHomeBannerRepository` (rỗng) nên phần banner bị ẩn.
