# DealGo Backend

API NestJS — nguồn sự thật cho quyền, giá đã chốt, assignment, trạng thái Ride/Food và ledger.

## Chạy

```bash
npm install
npm run start:dev
```

Mặc định lắng nghe cổng `3000` (hoặc `PORT` trong môi trường).

## Ghi chú

- Hiện là scaffold NestJS 11 — ORM/DB/queue/payment **chưa** phê duyệt bằng ADR.
- Không coi cache/push/socket client là nguồn sự thật thay server.
- Chi tiết sản phẩm và quyết định: `../docs/`, `../AGENTS.md`.
