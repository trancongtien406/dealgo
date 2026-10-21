---
doc_id: DG-ARCH-001
title: "DealGo — System overview"
version: "0.1.1"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-18"
related_decisions:
  - ADR-001
  - ADR-002
  - ADR-003
  - ADR-004
  - ADR-005
  - ADR-006
---

# DealGo — System overview

> Working baseline kỹ thuật. Quyết định sản phẩm đã chốt nằm ở `docs/00-governance/`. ADR chi tiết nằm trong `adr/`.

## Bối cảnh

```text
Flutter app (Customer | Merchant | Driver)
        |
        | HTTPS + Socket.IO
        v
NestJS modular monolith  ---- Redis (lock, queue, presence)
        |                 ---- PostgreSQL (trạng thái, sổ cái)
        |
NestJS worker (BullMQ: outbox, ride expiry) -- cùng PostgreSQL/Redis
        |
Admin Web (Next.js BFF) -- cookie session --> cùng API
```

## Ranh giới

- Flutter và Admin Web hiển thị và gửi ý định. Chúng không chốt giá, không tự gán tài xế, không tự ghi sổ.
- `RideTrip` và `FoodOrder` là hai aggregate. Không dùng chung một máy trạng thái.
- Admin không nằm trong app Flutter.
- Trình duyệt Admin chỉ gọi Route Handlers cùng origin; BFF gọi Nest phía server (`DEALGO_API_BASE_URL`). Mutation cookie kiểm tra same-origin.
- API và worker là hai process, mỗi process một pool Prisma (`DATABASE_POOL_MAX`, mặc định 10).

## Hợp đồng lỗi HTTP

Thành công: `{ "success": true, "statusCode", "message", "data", "requestId" }`.

Lỗi: `{ "success": false, "statusCode", "message", "errorCode", "timestamp", "path", "requestId" }`.

`errorCode` ổn định để client map. Không trả stack cho client.

## Cổng local

| Dịch vụ | Cổng |
|---|---|
| Admin Web | 3000 |
| API | 3001 |
| PostgreSQL | 5433 (Docker Compose; 5432 trong CI / service local) |
| Redis | 6379 |
