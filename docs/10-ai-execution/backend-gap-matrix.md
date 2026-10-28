---
doc_id: DG-AI-003
title: "DealGo — Backend gap matrix"
version: "1.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-26"
related_decisions:
  - ADR-001
  - ADR-002
  - ADR-003
  - ADR-006
  - DEC-PROD-007
---

# Backend gap matrix

> Test xanh không phải là Definition of Done. Done = đúng nghiệp vụ trong docs + contract OpenAPI khớp code + lưu trữ thật + xử lý nhánh lỗi và tranh chấp đồng thời khi có.

Tài liệu mô tả hiện trạng của `backend/`. Code là nguồn chuẩn; tham số tiền và vận hành xem [bản đồ cài đặt Admin](open-admin-settings-map.md), biến môi trường xem [catalog env](../09-operations/secrets-and-env-catalog.md).

## Hiện trạng theo phân hệ

| Phân hệ | Đã có trong code | Còn thiếu |
|---|---|---|
| Nền tảng | NestJS 12 modular monolith; `/health/live` + `/health/ready` (Postgres, Redis); requestId; envelope lỗi chuẩn; `DATABASE_POOL_MAX` mỗi process; OpenAPI sinh từ code (`npm run openapi:export`) | ADR còn `PROPOSED` |
| Xác thực | OTP SĐT (ESMS / SpeedSMS / mock), passkey, email + mật khẩu (đăng ký 2 bước OTP, quên mật khẩu); bật/tắt từng phương thức qua `/v1/ops/auth-methods`; grant `SUSPENDED` chỉ ops mở lại | — |
| Đối tác | KYC tài xế / KYB quán có duyệt ops và audit; S3 cho giấy tờ; `PartnerEligibilityService` chặn đối tác chưa duyệt | — |
| Ride | Trả giá kiểu inDrive (khách đề giá, tài xế báo giá / counter, khách chọn), xe máy / ô tô 4 / ô tô 7; giới hạn báo giá theo cài đặt; hết hạn bằng worker; mã đón; huỷ có phí theo hạng xe; chia sẻ chuyến | — |
| Food | Giỏ một quán → đặt → quán nhận → tài xế nhận → giao / `FAILED`; quán đề xuất điều chỉnh đơn, khách đồng ý trong `FOOD_ORDER_CHANGE_RESPONSE_MINUTES`; phí giao do server tính; giới hạn công suất quán | — |
| Khuyến mãi | Bảng `promotions` + `promotion_redemptions`; trừ ngân sách và `usageLimit`/`userLimit` khi dùng; nhà tài trợ PLATFORM / MERCHANT / SHARED | — |
| Tiền | Ledger kép ghi cùng transaction; COD; phí huỷ khách cộng vào chuyến tiền mặt kế tiếp; hoa hồng tài xế (theo cước) và quán (theo tạm tính) là cài đặt; công nợ phí nền tảng của tài xế; sao kê quán theo kỳ ICT và ghi nhận "đã trả quán" | Không thu tiền online thật: VNPAY/MoMo chỉ tạo intent chuyển hướng + webhook `CAPTURED_STUB`; không payout; hoàn tiền chỉ là bản ghi |
| Vận hành (ops) | API cho chuyến, đơn, khách, tài xế, quán, nhân sự, ngoại lệ, huỷ / gán lại, khiếu nại → hoàn tiền, phiếu hỗ trợ, khuyến mãi, khu vực & giá, hạng xe, nội dung, FAQ, thông báo, nhật ký audit, xem chat có lý do; RBAC theo quyền (`ops-permissions.ts`) | `revenueVnd` / `commissionVnd` ở Tổng quan trả `null`; sửa hạng xe không ghi audit; mô tả OpenAPI của `GET /v1/ops/settlements` ghi "UTC day" trong khi service gom theo ngày ICT |
| Realtime / push | Socket.IO + Redis adapter; outbox `FOR UPDATE SKIP LOCKED`; push FCM HTTP v1 theo vai trò kèm đường dẫn mở app; push cuốc mới gần tài xế; push chat | Push chat lọc theo công tắc `ride`/`food`, không theo công tắc `chat` |
| Chat / thoại | Chat theo chuyến/đơn, mã hoá AES-256-GCM khi lưu, xoá theo `CHAT_RETENTION_DAYS`; cửa sổ liên lạc `CONTACT_WINDOW_MINUTES`; gọi thoại LiveKit (`integrations/voice`): `POST /v1/rides/:id/calls`, `POST /v1/food/orders/:id/calls`, `/v1/calls/:id/accept|decline|end`, `GET /v1/calls/config`; chỉ khách ↔ tài xế được gán khi chuyến/đơn đang chạy; bảng `voice_calls`, socket `call`, push `Call.incoming` / `Call.missed`, ghi chú cuộc gọi nhỡ vào chat; công tắc Admin `VOICE_CALLS_ENABLED` | Chính sách lưu giữ liên lạc `OPEN-021` chưa chốt |
| Worker | `outbox-relay`, `ride-expiry`, `chat-retention`, `account-purge`, `upload-orphan-cleanup`, `worker-heartbeat` (BullMQ, process riêng) | — |
| Kiểm thử / CI | Unit (vitest), integration Postgres/Redis, các spec tranh chấp trong `backend/test/concurrency/` (gán tài xế, nhận đơn, voucher, webhook, công suất quán…); CI chạy typecheck + lint + test | Chưa có ma trận P0 đầy đủ |

## Khoảng trống cần quyết định

| Khoảng trống | Ghi chú |
|---|---|
| Biểu phí, hoa hồng (`OPEN-003`) | Là cài đặt Admin với giá trị mặc định DRAFT; chờ chủ dự án duyệt số |
| Cổng thanh toán (`OPEN-002`) | Ra mắt chỉ tiền mặt; không tuyên bố đã thu tiền thật |
| `PAYMENT_METHODS_ENABLED` | Đã gỡ — thay bằng `PAYMENT_METHOD_REGISTRY` (được kiểm khi đặt chuyến/đơn) |
| Lưu giữ liên lạc (`OPEN-021`) | `CONTACT_WINDOW_MINUTES` mặc định 120, là TEST_ONLY |
| Migration trùng tiền tố | Ba thư mục `20261014160000_*`; không đổi tên vì đã áp dụng |

## Definition of Done

- Schema / migration phản ánh bất biến nghiệp vụ.
- Service kiểm quyền sở hữu theo đối tượng.
- Không tin giá hoặc vai trò từ client.
- Có test tranh chấp cho race P0.
- Production không âm thầm dùng mock: `PUSH_PROVIDER`, `VOICE_PROVIDER`, khoá chat đều fail closed khi `NODE_ENV=production`.
- Contract OpenAPI khớp code.
