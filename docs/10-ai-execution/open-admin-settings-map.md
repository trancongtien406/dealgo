---
doc_id: DG-AI-011
title: "DealGo — OPEN-* → Admin settings vs env vs FAQ"
version: "1.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-14"
---

# OPEN-* → Admin / Env / FAQ

> **Không** coi giá trị trong Admin là policy đã duyệt. Mọi số/câu trả lời gắn nhãn `TEST_ONLY` / `PROPOSED` cho đến khi owner `RESOLVED` trong governance.

## A. Admin Platform Settings (DB wins; code defaults — **không** liệt kê trong `.env.example`)

| Key | OPEN liên quan | Ý nghĩa | Env? |
|---|---|---|---|
| _(đã gỡ)_ `PILOT_ZONE_LABEL` | OPEN-001 | Thay bằng bảng `service_regions` (Admin → Khu vực & Giá); nhãn pilot tự sinh từ các vùng ACTIVE | Không còn env/setting text tự do |
| `PAYMENT_METHODS_ENABLED` | OPEN-002 | JSON kênh thu (COD/SANDBOX…) — **không** secret PSP | Idem |
| `RIDE_MIN_FARE_VND` / `RIDE_MAX_FARE_VND` / `RIDE_REFERENCE_VND_PER_KM` | OPEN-003 / 019 | Bound giá Ride TEST_ONLY | Idem |
| `FOOD_MIN_DELIVERY_VND` / `FOOD_MAX_DELIVERY_VND` | OPEN-003 | Bound phí giao Food TEST_ONLY | Idem |
| `DRIVER_SEARCH_RADIUS_KM` | OPEN-004 | Bán kính tìm tài xế TEST_ONLY | Idem |
| `RIDE_OFFER_TTL_SECONDS` | OPEN-004 / 019 | TTL đề nghị giá | Idem |
| `RIDE_NEGOTIATION_MAX_ROUNDS` | OPEN-019 | Số vòng thương lượng (optional) | Idem |
| `MAX_CONCURRENT_JOBS_PER_DRIVER` | OPEN-005 | Giới hạn job đồng thời (lưu; enforce dần) | Idem |
| `CONTACT_WINDOW_MINUTES` | OPEN-014 / 021 | Cửa sổ chat/voice sau trạng thái chốt | Idem |

Chỉnh qua Admin UI `/settings/platform` hoặc `PATCH /v1/ops/platform-settings/:key`.

## B. Luôn ENV (secrets / infra) — không đưa lên Admin UI

JWT secrets, `DATABASE_URL`, Redis, `FCM_*`, VNPAY/MoMo keys, LiveKit keys, SMS provider keys, S3 keys, bootstrap ops password.

OPEN-008 (chọn vendor): Admin có thể ghi **FAQ / ghi chú lựa chọn**; bật provider thật vẫn cần key env + review pháp lý.

## C. FAQ Admin (soạn thảo trả lời — owner quyết sau)

OPEN-001..021 thành câu hỏi FAQ với `suggestedAnswer` PROPOSED. Admin sửa / PUBLISH khi sẵn sàng dùng cho hỗ trợ nội bộ (chưa đồng nghĩa RESOLVED governance).

| OPEN | Vì sao FAQ chứ không chỉ setting số? |
|---|---|
| OPEN-006 | Pháp nhân / hợp đồng — văn bản, không knob |
| OPEN-007 | SLO / budget — văn bản vận hành |
| OPEN-008 | Vendor trade-off + secret vẫn env |
| OPEN-009..018, 020–021 | Quyết định nghiệp vụ/UX/pháp lý cần diễn giải |
| OPEN-001..005 phần “tại sao” | Setting số + FAQ giải thích đề xuất |

## D. Mapping nhanh OPEN-001..008

| ID | Admin setting số/cờ | FAQ draft | Env secrets |
|---|---|---|---|
| OPEN-001 | Zones UI `/zones` (bảng `service_regions`, tạo/sửa/bật-tắt vùng, audit `SERVICE_REGION_UPDATE`) | Có | — |
| OPEN-002 | `PAYMENT_METHODS_ENABLED` | Có | PSP keys |
| OPEN-003 | Fare/delivery bounds | Có | — |
| OPEN-004 | Radius + offer TTL | Có | — |
| OPEN-005 | `MAX_CONCURRENT_JOBS_PER_DRIVER` | Có | — |
| OPEN-006 | — | Có (chính) | — |
| OPEN-007 | — | Có (chính) | — |
| OPEN-008 | Ghi chú FAQ | Có (chính) | Provider keys |
