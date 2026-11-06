---
doc_id: DG-AI-011
title: "DealGo — Bản đồ cài đặt Admin, biến môi trường và OPEN-*"
version: "2.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-27"
---

# Bản đồ cài đặt Admin, biến môi trường và OPEN-*

> Giá trị trong Admin **không** phải chính sách đã duyệt. Số liệu gắn `DRAFT`/`TEST_ONLY` vẫn chờ owner chốt ở [sổ quyết định](../00-governance/decisions-and-assumptions.md) cho tới khi `OPEN-*` tương ứng `RESOLVED`.

Nguồn đúng: `backend/src/platform/settings/platform-settings.catalog.ts` (danh mục, khoảng, nhãn), `platform-settings.seed.ts` (giá trị seed), `backend/src/platform/config/env.ts` (giá trị mặc định lấy từ env cho khoá không seed) và `website/features/platform-settings/` (cách Admin nhóm hiển thị). Bảng ở §3 được sinh từ danh mục này.

## 1. Cấu hình nằm ở đâu

| Nơi | Đường dẫn Admin | API | Quyền | Audit |
|---|---|---|---|---|
| Tham số nền tảng (73 khoá, §3) | Cài đặt › Tham số `/settings/platform` | `GET /v1/ops/platform-settings`, `PATCH /v1/ops/platform-settings/:key` `{ value, reason }` | `settings.write` | `SETTINGS_UPDATE` (giá trị cũ, mới, lý do, người sửa) |
| Hạng xe và giá theo hạng (MOTORBIKE / CAR_4 / CAR_7) | Cài đặt › Loại xe `/settings/vehicle-classes` | `/v1/ops/ride-vehicle-classes` | `settings.write` | không ghi audit |
| Vùng dịch vụ | Khu vực & Giá `/zones` | `/v1/ops/zones` | `zones.write` | `SERVICE_REGION_UPDATE` |
| Phương thức đăng nhập | Cài đặt › Đăng nhập `/settings/auth-methods` | `/v1/ops/auth-methods` | `settings.write` | `AUTH_METHOD_UPDATE` |
| Nhà cung cấp bản đồ (Mapbox / Google) theo chức năng | Cài đặt › Bản đồ `/settings/maps` | `GET /v1/ops/maps-providers`; đổi qua `PATCH /v1/ops/platform-settings/MAPS_*_PROVIDER` | `settings.write` | `SETTINGS_UPDATE` |
| Trang công khai (điều khoản, quyền riêng tư, hỗ trợ) | Cài đặt › Nội dung & Pháp lý `/settings/content` | `/v1/ops/public-pages` | `content.write` | `PUBLIC_PAGE_PUBLISH` (khi xuất bản) |
| Câu hỏi chính sách OPEN-001..021 | Cài đặt › Chính sách OPEN `/settings/faqs` | `GET/POST/PATCH /v1/ops/faqs` | `notifications.write` | `FAQ_UPDATE` |

**Thứ tự đọc giá trị tham số:** dòng trong bảng `platform_settings` thắng. Khoá có seed được tạo bằng migration/seed; khoá không seed lấy giá trị đầu tiên từ env (cột "Mặc định" ghi `(env)`) rồi lưu vào DB khi đọc lần đầu. Sau đó sửa env không đổi giá trị đang dùng — sửa trong Admin.

## 2. Trang Tham số

Trang Tham số có 5 tab:

| Tab | Nội dung |
|---|---|
| **Dòng tiền & hoa hồng** | Một góc nhìn gom các khoá liên quan tới tiền (`CASH_FLOW_GROUPS` trong `cash-flow.ts`): hoa hồng, đối soát & công nợ, voucher, phí huỷ & không gặp khách, giới hạn cước & thanh toán; kèm ví dụ dòng tiền một chuyến/đơn. Khoá ở đây vẫn thuộc một trong bốn tab dưới. |
| **Cước & Trả giá** | §3.1 |
| **Điều phối & SLA** | §3.2 |
| **Vùng & Thanh toán** | §3.3 |
| **Hỗ trợ khách hàng** | §3.4 |

Khoá hiện trong tab Dòng tiền & hoa hồng: `FOOD_MIN_DELIVERY_VND`, `FOOD_MAX_DELIVERY_VND`, `RIDE_COMMISSION_BIKE_PERCENT`, `RIDE_COMMISSION_CAR_PERCENT`, `FOOD_DRIVER_COMMISSION_PERCENT`, `VOUCHER_SHARED_PLATFORM_PERCENT`, `RIDE_NO_SHOW_WAIT_MINUTES`, `RIDE_FREE_CANCEL_MINUTES`, `RIDE_CANCEL_FEE_BIKE_VND`, `RIDE_CANCEL_FEE_CAR_VND`, `DRIVER_DEBT_LIMIT_VND`, `FOOD_MERCHANT_COMMISSION_PERCENT`, `MERCHANT_SETTLEMENT_CYCLE_DAYS`.

## 3. Danh mục tham số

Cột "Tham chiếu" trỏ tới quyết định (`DEC-PROD-*`) hoặc vấn đề còn mở (`OPEN-*`) trong sổ quyết định.

### Tab "Cước & Trả giá" (18)

| Key | Mặc định | Khoảng | Ý nghĩa | Tham chiếu |
|---|---|---|---|---|
| `RIDE_MIN_FARE_VND` | `10000` (env) | ≥ 1 | Giá sàn gốc khi tạo hạng xe mới và dự phòng khi hạng xe chưa có giá sàn. Giá áp dụng sửa ở Cài đặt › Loại xe. | OPEN-003, OPEN-019 |
| `RIDE_MAX_FARE_VND` | `500000` (env) | ≥ 1 | Giá trần gốc khi tạo hạng xe mới. Giá trần áp dụng sửa ở Cài đặt › Loại xe. | OPEN-003, OPEN-019 |
| `RIDE_REFERENCE_VND_PER_KM` | `8000` (env) | ≥ 1 | Giá/km gốc khi tạo hạng xe mới. Giá/km áp dụng sửa ở Cài đặt › Loại xe. | OPEN-003, OPEN-019 |
| `FOOD_MIN_DELIVERY_VND` | `5000` (env) | ≥ 1 | Phí giao tối thiểu (kẹp sau khi tính theo km). | OPEN-003 |
| `FOOD_MAX_DELIVERY_VND` | `100000` (env) | ≥ 1 | Phí giao tối đa (kẹp sau khi tính theo km). | OPEN-003 |
| `RIDE_COMMISSION_BIKE_PERCENT` | `0` | 0–100 | Hoa hồng DealGo trên giá chốt của chuyến xe máy; chốt % lúc hoàn thành; tài xế nợ khoản này. | OPEN-003, DEC-PROD-062 |
| `RIDE_COMMISSION_CAR_PERCENT` | `0` | 0–100 | Hoa hồng DealGo trên giá chốt của chuyến ô tô; chốt % lúc hoàn thành. | OPEN-003, DEC-PROD-062 |
| `FOOD_DRIVER_COMMISSION_PERCENT` | `0` | 0–100 | Hoa hồng DealGo trên phí giao (không tính tiền món); chốt % lúc giao xong. | OPEN-003, DEC-PROD-062 |
| `VOUCHER_SHARED_PLATFORM_PERCENT` | `100` | 0–100 | Phần DealGo chịu với voucher đồng tài trợ (SHARED); phần còn lại trừ vào tiền của quán. | DEC-PROD-015 |
| `RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE` | `80` | 0–100 | Giá khách đưa tối thiểu tính theo % giá tham khảo, làm tròn lên 1.000đ; 0 = chỉ dùng giá sàn của hạng xe. | DEC-PROD-059 |
| `RIDE_COUNTER_MAX_PERCENT_OF_OFFER` | `150` | 100–300 | Giá tài xế trả lại tối đa tính theo % giá khách đưa, làm tròn xuống 1.000đ. | DEC-PROD-059 |
| `RIDE_FREE_CANCEL_MINUTES` | `5` | 0–30 | Khách huỷ miễn phí trong số phút này sau khi có tài xế (và trước khi tài xế tới). | DEC-PROD-060 |
| `RIDE_CANCEL_FEE_BIKE_VND` | `3000` | 0–200000 | Phí huỷ muộn / không xuất hiện cho xe máy; cộng vào chuyến hoàn thành kế tiếp của khách, trả cho tài xế bị huỷ. | DEC-PROD-060 |
| `RIDE_CANCEL_FEE_CAR_VND` | `10000` | 0–500000 | Phí huỷ muộn / không xuất hiện cho ô tô; cộng vào chuyến hoàn thành kế tiếp của khách, trả cho tài xế bị huỷ. | DEC-PROD-060 |
| `RIDE_MAX_LIVE_OFFERS_PER_RIDE` | `0` | 0–100 | Số đề nghị đang mở tối đa trên một chuyến; 0 = không giới hạn. | DEC-PROD-061 |
| `RIDE_MAX_FARE_RAISES_PER_RIDE` | `3` | 0–20 | Số lần khách được tăng giá trên một chuyến; mỗi lần mở vòng mới, tài xế được sửa giá lại; 0 = không giới hạn. | DEC-PROD-061 |
| `FOOD_MERCHANT_COMMISSION_PERCENT` | `20` | 0–50 | Chiết khấu quán trả DealGo trên tiền món; ghi vào sao kê quán. | DEC-PROD-061 |
| `MERCHANT_SETTLEMENT_CYCLE_DAYS` | `7` | 1–31 | Chu kỳ mặc định của sao kê hoa hồng quán (N ngày gần nhất, theo ngày Việt Nam). | DEC-PROD-062 |

### Tab "Điều phối & SLA" (26)

| Key | Mặc định | Khoảng | Ý nghĩa | Tham chiếu |
|---|---|---|---|---|
| `DRIVER_SEARCH_RADIUS_KM` | `5` (env) | 0.1–100 | Bán kính (km) quanh điểm đón / quán để tìm tài xế, lọc danh sách chuyến mở, đơn sẵn sàng. Không còn dùng cho danh sách quán của khách (xem `FOOD_BROWSE_RADIUS_KM`). | OPEN-004 |
| `FOOD_BROWSE_RADIUS_KM` | `15` (seed) | 1–50 | Bán kính (km) khách thấy/tìm quán ăn quanh vị trí của mình; `max_km` chỉ có thể thu hẹp thêm. Tách khỏi bán kính điều phối tài xế. | DEC-PROD-059 |
| `RIDE_OFFER_TTL_SECONDS` | `20` (env, t71u) | 1–86400 | Hiệu lực mỗi đề nghị giá của tài xế; không vượt quá thời gian mở yêu cầu. | OPEN-004, OPEN-019 |
| `CONTACT_WINDOW_MINUTES` | `120` (env) | 1–10080 | Chat mở suốt chuyến/đơn và thêm số phút này sau khi chuyến/đơn kết thúc. Gọi thoại chỉ khi chuyến/đơn đang chạy (`DEC-PROD-064`). | OPEN-014, OPEN-021 |
| `MAX_CONCURRENT_JOBS_PER_DRIVER` | `1` (env) | 1–20 | Số việc đang chạy tối đa của một tài xế; kiểm tra khi khách chọn tài xế và khi tài xế nhận đơn Food. | OPEN-005 |
| `RATING_WINDOW_DAYS` | `7` | 1–365 | Số ngày sau khi hoàn thành mà khách còn đánh giá được. | DEC-PROD-013 |
| `RIDE_PICKUP_CODE_MAX_ATTEMPTS` | `5` | 1–20 | Số lần nhập sai mã đón; vượt quá thì mã bị khoá, Ops huỷ hoặc điều phối lại. | DEC-PROD-017 |
| `FOOD_DELIVERY_CODE_REQUIRED` | `true` | true/false | Bật: tài xế phải nhập mã 4 số khách đọc trên app mới hoàn tất giao. | DEC-PROD-036 |
| `FOOD_DELIVERY_CODE_MAX_ATTEMPTS` | `5` | 1–20 | Số lần nhập sai mã giao / mã bàn giao; vượt quá thì mã bị khoá, Ops xử lý. | DEC-PROD-036 |
| `FOOD_HANDOVER_CODE_REQUIRED` | `false` | true/false | Bật: tài xế phải nhập mã quán hiển thị khi lấy món. | DEC-PROD-036 |
| `RATING_STORE_MIN_COUNT` | `3` | 1–50 | Dưới số đánh giá này app chỉ hiện "Quán mới" / số lượt, không hiện điểm trung bình. | DEC-PROD-019 |
| `AUTH_PASSWORD_RESET_CODE_TTL_MINUTES` | `10` | 5–60 | Hiệu lực mã 6 số đặt lại mật khẩu gửi qua email. | DEC-PROD-045, OPEN-020 |
| `AUTH_PASSWORD_RESET_MAX_ATTEMPTS` | `5` | 3–10 | Số lần nhập sai mã đặt lại mật khẩu trước khi mã bị khoá. | DEC-PROD-045, OPEN-020 |
| `RIDE_REQUEST_WINDOW_SECONDS` | `300` | 60–1800 | Thời gian yêu cầu chuyến mở để tài xế chào giá; khách tăng giá thì gia hạn. | DEC-PROD-059 |
| `RIDE_MAX_OFFER_EDITS_PER_DRIVER` | `2` | 0–10 | Số lần một tài xế được sửa giá trong một vòng. | DEC-PROD-059 |
| `RIDE_ASSIGNED_START_TIMEOUT_MINUTES` | `5` | 0–60 | Tài xế được chọn phải bấm "Đang đến" trong thời gian này, quá hạn chuyến quay lại tìm tài xế; 0 = tắt. | DEC-PROD-059 |
| `RIDE_EN_ROUTE_TIMEOUT_MINUTES` | `30` | 0–180 | Tài xế phải tới điểm đón trong thời gian này, quá hạn chuyến quay lại tìm tài xế; 0 = tắt. | DEC-PROD-059 |
| `ROUTE_OFF_ROUTE_THRESHOLD_M` | `150` | 30–2000 | Tài xế lệch khỏi tuyến đã lưu quá số mét này thì server tính lại tuyến. | DEC-PROD-031 |
| `ROUTE_REROUTE_MIN_INTERVAL_SECONDS` | `120` | 30–1800 | Khoảng tối thiểu giữa hai lần tính lại tuyến cho một chuyến/đơn. | DEC-PROD-031 |
| `RIDE_NO_SHOW_WAIT_MINUTES` | `5` | 1–30 | Thời gian chờ tại điểm đón trước khi tài xế được báo khách không xuất hiện. | DEC-PROD-060 |
| `FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES` | `5` | 0–60 | Quán phải nhận đơn trong thời gian này, quá hạn đơn tự huỷ (MERCHANT_TIMEOUT); 0 = tắt. | DEC-PROD-059 |
| `FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES` | `30` | 0–240 | Đơn đã xong mà không tài xế nhận sau số phút này thì tự huỷ (NO_DRIVER); 0 = tắt. | DEC-PROD-059 |
| `FOOD_EARLY_ASSIGN_LEAD_MINUTES` | `10` | 0–60 | Tài xế được nhận đơn đang làm khi món còn ≤ số phút này là xong; 0 = chỉ nhận khi quán báo xong. | DEC-PROD-059 |
| `DISPATCH_REQUIRE_FRESH_PRESENCE` | `true` | true/false | Bật: chỉ tài xế online có vị trí mới (≤ 2 phút) mới thấy và nhận việc. Chỉ tắt ở môi trường thử. | DEC-PROD-059 |
| `CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS` | `24` | 1–168 | Khoảng thời gian tính số lần khách huỷ. | DEC-PROD-061 |
| `CUSTOMER_CANCEL_COOLDOWN_MINUTES` | `30` | 0–1440 | Thời gian tạm chặn đặt chuyến, tính từ lần huỷ gần nhất; 0 = tắt. | DEC-PROD-061 |
| `DRIVER_CANCEL_RATE_WINDOW_DAYS` | `7` | 1–90 | Khoảng thời gian tính tỷ lệ huỷ của tài xế. | DEC-PROD-061 |
| `FOOD_FAIL_MIN_WAIT_MINUTES` | `10` | 0–60 | Tài xế chờ ít nhất số phút này (tính từ lúc lấy món) mới được báo giao thất bại vì không liên lạc được khách. | DEC-PROD-061 |
| `FOOD_ORDER_CHANGE_RESPONSE_MINUTES` | `5` | 1–30 | Khách phải xác nhận đơn bị quán sửa / hết món trong thời gian này, quá hạn đơn tự huỷ, không phí. | DEC-PROD-061 |

### Tab "Vùng & Thanh toán" (18)

| Key | Mặc định | Khoảng | Ý nghĩa | Tham chiếu |
|---|---|---|---|---|
| `FOOD_DELIVERY_VND_PER_KM` | `3000` (env) | ≥ 1 | Phí giao theo km đường đi từ quán tới điểm giao. | OPEN-003 |
| `PAYMENT_METHOD_REGISTRY` | mặc định chỉ tiền mặt | Admin › Cài đặt › Thanh toán | Bật/tắt từng phương thức theo BIKE/CAR/FOOD, thứ tự, lý do ẩn. Thay thế `PAYMENT_METHODS_ENABLED` (đã gỡ, migration `20261128090200` xoá giá trị cũ). | OPEN-002 |
| `ONBOARDING_DRIVER_KYC_REQUIRED` | `true` | true/false | Tắt: app bỏ bước nộp giấy tờ, tài xế vẫn chọn hạng xe và chờ Admin duyệt. | DEC-PROD-048 |
| `ONBOARDING_MERCHANT_KYB_REQUIRED` | `true` | true/false | Tắt: app bỏ bước nộp giấy tờ, cửa hàng vẫn chờ Admin duyệt. | DEC-PROD-048 |
| `KYC_AUTO_APPROVE_DRIVER` | `false` | true/false | Bật: hồ sơ tài xế nộp đủ điều kiện được duyệt ngay (audit `KYC_AUTO_APPROVE`, actor SYSTEM); không đủ → chờ ops, lý do trong `autoApproveSkipped`. | DEC-PROD-070 (t61u) |
| `KYC_AUTO_APPROVE_MERCHANT` | `false` | true/false | Như trên cho hồ sơ cửa hàng (KYB). | DEC-PROD-070 (t61u) |
| `MENU_ITEM_MAX_IMAGES` | `4` | 1–8 | Số ảnh tối đa của một món. | DEC-PROD-042 |
| `AUTH_PASSWORD_RESET_MAX_PER_HOUR` | `5` | 1–20 | Số yêu cầu đặt lại mật khẩu mỗi email mỗi giờ (ngoài giới hạn theo IP). | DEC-PROD-045, OPEN-020 |
| `CHAT_RETENTION_DAYS` | `90` | 7–3650 | Worker xoá tin nhắn chat cũ hơn số ngày này. | DEC-PROD-056 |
| `APP_REVIEW_LOGIN_ENABLED` | `false` | true/false | Bật tài khoản duyệt App Store / Google Play (đăng nhập bằng mã `APP_REVIEW_OTP_CODE` trong env). | DEC-PROD-052 |
| `APP_REVIEW_PHONE` | `(trống)` | — | SĐT của tài khoản duyệt app. | DEC-PROD-052 |
| `APP_REVIEW_EMAIL` | `(trống)` | — | Email của tài khoản duyệt app. | DEC-PROD-052 |
| `FOOD_MAX_DELIVERY_KM` | `15` | 1–50 | Khoảng cách đường chim bay tối đa từ quán tới điểm giao. | DEC-PROD-059 |
| `SERVICE_ZONE_ENFORCED` | `true` | true/false | Bật: Ride yêu cầu điểm đón và điểm đến trong khu vực ACTIVE; Food yêu cầu điểm giao trong khu vực ACTIVE và quán có toạ độ. | DEC-PROD-059 |
| `DRIVER_DEBT_LIMIT_VND` | `200000` | 0–10000000 | Tài xế nợ hoa hồng/phí vượt mức này thì không nhận việc mới cho tới khi Admin ghi nhận đã thu; 0 = tắt. | DEC-PROD-060 |
| `CUSTOMER_CANCEL_LIMIT_COUNT` | `3` | 0–20 | Số chuyến khách huỷ sau khi đã có tài xế trong khoảng tính, vượt thì tạm chặn đặt chuyến; 0 = tắt. | DEC-PROD-061 |
| `DRIVER_CANCEL_RATE_WARN_PERCENT` | `20` | 0–100 | Ngưỡng tỷ lệ huỷ để cảnh báo trên Admin; không tự khoá tài xế. | DEC-PROD-061 |
| `RIDE_REQUEST_PUSH_ENABLED` | `true` | true/false | Gửi push chuyến mới cho tài xế gần đó (để app ở nền/tắt vẫn nhận được). | DEC-PROD-061 |
| `NEW_JOB_CUSTOM_SOUND_ENABLED` | `true` | true/false | Âm báo giọng nói khi có cuốc/đơn mới (tài xế, quán). Tắt = âm mặc định của máy. | DEC-PROD-061 |
| `RIDE_REQUEST_PUSH_MAX_DRIVERS` | `30` | 0–200 | Số tài xế gần nhất nhận push mỗi chuyến; 0 = không gửi. | DEC-PROD-061 |
| `PARCEL_SERVICE_FEE_VND` | `0` | 0–200000 | Giao hàng: phí dịch vụ cộng vào giá tham chiếu (cùng phụ phí S/M/L/XL trong `PARCEL_SIZE_CLASSES`) trước khoảng trả giá; snapshot vào đơn. | DEC-PROD-071 |
| `PARCEL_RETURN_FEE_VND` | `10000` | 0–500000 | Giao hàng: phí hoàn hàng, chỉ tính khi đơn giao thất bại → `RETURNED` (phí khách `PARCEL_RETURN`). | DEC-PROD-071 |
| `RIDE_REPOST_RAISE_HINT_PERCENT` | `10` | 0–50 | Mức tăng giá app gợi ý khi khách đăng lại chuyến hết hạn. | DEC-PROD-061 |

### Tab "Hỗ trợ khách hàng" (11)

| Key | Mặc định | Khoảng | Ý nghĩa | Tham chiếu |
|---|---|---|---|---|
| `MAPS_SEARCH_PROVIDER` | `mapbox` | mapbox/google | Nhà cung cấp tìm địa chỉ (ô tìm điểm đón/đến). `google` chỉ lưu được khi server có `GOOGLE_MAPS_API_KEY`; Google lỗi → tự dùng Mapbox. Nên đổi ở Cài đặt › Bản đồ. | DEC-PROD-045 |
| `MAPS_REVERSE_PROVIDER` | `mapbox` | mapbox/google | Nhà cung cấp đổi toạ độ ghim thành địa chỉ. | DEC-PROD-045 |
| `MAPS_ROUTE_PROVIDER` | `mapbox` | mapbox/google | Nhà cung cấp lộ trình vẽ trên bản đồ và quãng đường tính cước. `mapbox` = theo env `ROUTING_PROVIDER`. | DEC-PROD-045 |
| `SUPPORT_TICKET_MAX_OPEN_PER_USER` | `5` | 1–50 | Số yêu cầu hỗ trợ đang mở tối đa của một người dùng. | DEC-PROD-018 |
| `SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY` | `3` | 1–50 | Số yêu cầu từ form website cho cùng SĐT/email trong 24 giờ. | DEC-PROD-018 |
| `SUPPORT_TICKET_TEXT_MAX_CHARS` | `2000` | 200–5000 | Độ dài tối đa của mô tả và mỗi tin trao đổi hỗ trợ. | DEC-PROD-018 |
| `UPLOAD_MAX_FILE_KB` | `4096` | 100–5120 | Dung lượng tối đa mỗi tệp (giấy tờ KYC/KYB, đính kèm hỗ trợ, ảnh đại diện, logo, ảnh món); trần cứng 5120. | DEC-PROD-020 |
| `UPLOAD_ALLOWED_TYPES` | `["image/jpeg","image/png","image/webp","application/pdf"]` | — | Định dạng tệp được phép (mảng JSON trong image/jpeg, image/png, image/webp, application/pdf). | DEC-PROD-020 |
| `UPLOAD_ORPHAN_MAX_AGE_HOURS` | `72` | 24–2160 | Worker xoá tệp không còn gắn với hồ sơ, ticket hay ảnh nào khi cũ hơn số giờ này. | DEC-PROD-022 |
| `ACCOUNT_DELETION_GRACE_DAYS` | `7` | 0–90 | Sau khi xác nhận xoá, tài khoản bị khoá ngay; hết số ngày này worker ẩn danh hoá dữ liệu. Ops khôi phục được trong thời gian chờ. | DEC-PROD-037 |
| `VOICE_CALLS_ENABLED` | `true` | true/false | Khách và tài xế được gán gọi thoại cho nhau trong app khi chuyến/đơn đang chạy (LiveKit, chỉ âm thanh, không ghi âm). Tắt: app ẩn nút gọi, API trả `VOICE_DISABLED`. Cần thêm `VOICE_PROVIDER=livekit` + `LIVEKIT_*`. | DEC-PROD-007, DEC-PROD-064 |

## 4. Chỉ đặt bằng biến môi trường

Không đưa lên Admin: secret và hạ tầng — `DATABASE_URL`, `REDIS_URL`, JWT secret, khoá mã hoá chat, khoá FCM, nhà cung cấp SMS/email, nhà cung cấp mặc định và key bản đồ/routing (`MAPS_PROVIDER`, `MAPBOX_*`, `GOOGLE_MAPS_API_KEY`, `ROUTING_*`; còn lựa chọn Mapbox/Google theo chức năng thì ở Cài đặt › Bản đồ), object storage, Sentry, mã đăng nhập App Review (`APP_REVIEW_OTP_CODE`), mật khẩu bootstrap ops. Danh sách đầy đủ và ràng buộc production: [secrets-and-env-catalog.md](../09-operations/secrets-and-env-catalog.md).

## 5. OPEN-* → nơi cấu hình

Mỗi `OPEN-001..021` có một câu hỏi seed ở Chính sách OPEN (`ops-faq.seed.ts`) với câu trả lời đề xuất; xuất bản câu trả lời **không** có nghĩa là quyết định đã `RESOLVED`.

| OPEN | Cấu hình hiện có | Chỉ văn bản / chờ quyết định |
|---|---|---|
| OPEN-001 | Vùng dịch vụ `/zones`; `SERVICE_ZONE_ENFORCED` | Địa bàn pilot |
| OPEN-002 | `PAYMENT_METHOD_REGISTRY` (backend áp khi đặt chuyến/đơn; tiền mặt luôn bật) | PSP, đơn vị thu hộ |
| OPEN-003 | Giá theo hạng xe; phí giao Food; hoa hồng theo dịch vụ; chiết khấu quán | Mức % và biểu giá chính thức |
| OPEN-004 | Bán kính, độ mới vị trí, thời gian mở yêu cầu, TTL đề nghị, timeout | Chiến lược điều phối chính thức |
| OPEN-005 | `MAX_CONCURRENT_JOBS_PER_DRIVER` | Kiêm nhiệm vai trò |
| OPEN-006 | Checklist KYC ô tô (`VEHICLE_INSURANCE`, cờ env `PARTNER_CAR_KYC_EXTRA_DOCS`), `ONBOARDING_*_REQUIRED` | Pháp nhân, hợp đồng |
| OPEN-007 | — | SLO, ngân sách |
| OPEN-008 | — (nhà cung cấp chọn bằng env) | Lựa chọn vendor |
| OPEN-011 | `FOOD_HANDOVER_CODE_REQUIRED`, `FOOD_DELIVERY_CODE_REQUIRED`, số lần thử | Ảnh/chữ ký |
| OPEN-014 / 021 | `CONTACT_WINDOW_MINUTES`, `CHAT_RETENTION_DAYS`, `VOICE_CALLS_ENABLED` | Chính sách liên hệ, lưu trữ |
| OPEN-018 | `DRIVER_DEBT_LIMIT_VND`, `MERCHANT_SETTLEMENT_CYCLE_DAYS`, hoa hồng | Duyệt của Finance/Ops |
| OPEN-019 | Toàn bộ tham số thương lượng ở tab Cước & Trả giá | Duyệt số liệu của PO |
| Còn lại | — | Theo sổ quyết định |
