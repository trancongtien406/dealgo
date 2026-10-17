---
doc_id: ADR-003
title: "Redis, hàng đợi và realtime"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - ADR-001
---

# ADR-003 — Redis, hàng đợi và realtime

## Status

`PROPOSED`.

## Context

Cần khoá ngắn hạn, presence tài xế, rate limit, job nền (hết hạn offer, gửi thông báo) và đẩy trạng thái tới app. Kafka chưa có số liệu tải để biện minh.

## Decision

- Redis 7 cho cache, khoá, rate limit và presence. Presence không thay thế trạng thái chuyến/đơn trong PostgreSQL.
- BullMQ trên Redis cho job có retry và dead-letter.
- Socket.IO cho cập nhật trạng thái trong phiên. Sau mất kết nối, client gọi lại API đọc snapshot. Event realtime không phải nguồn sự thật.
- Outbox: ghi sự kiện trong cùng transaction với thay đổi nghiệp vụ, worker phát sau. Phase 1 chỉ dựng bảng và hợp đồng; worker đầy đủ theo từng vertical.

## Consequences

- Một instance API có thể chạy thiếu Redis ở dev nếu biến `REDIS_URL` trống: health báo `degraded`, không giả lập thành công job nền.
- Đa instance sau này dùng Redis adapter cho Socket.IO. Phase 1 chạy một process.
