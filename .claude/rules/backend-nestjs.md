# Backend NestJS — DealGo

Áp dụng khi làm việc trong `backend/`. Chi tiết đầy đủ: `.cursor/rules/backend-nestjs.mdc`.

- Đọc `AGENTS.md` + `docs/00-governance/` trước. NestJS scaffold ≠ đã phê duyệt Prisma/PostgreSQL/Redis/Kafka.
- Chỉ thêm ORM/DB/queue sau ADR hoặc khi lockfile/`package.json` đã có và task yêu cầu.
- DI Nest chuẩn; response/error thống nhất qua interceptor/filter khi triển khai.
- Authorize theo principal; server là nguồn sự thật cho Ride/Food.
- Test happy + failure + authz negative; không gọi production DB.
