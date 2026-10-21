---
doc_id: ADR-002
title: "PostgreSQL và Prisma"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - ADR-001
---

# ADR-002 — PostgreSQL và Prisma

## Status

`PROPOSED`. Working baseline cho schema và migration.

> Đã triển khai trong code (rà soát 2026-10-18): Prisma 7 + PostgreSQL (`backend/prisma/schema.prisma`, `backend/prisma/migrations/`). Trạng thái vẫn `PROPOSED` — chủ repo cần quyết định `ACCEPTED`/supersede.

## Context

Ride, Food, ledger và phân quyền cần transaction, ràng buộc duy nhất và khoá dòng. Scaffold chưa chọn ORM.

## Decision

- PostgreSQL 16 là cơ sở dữ liệu giao dịch.
- Prisma là lớp schema, migration và truy vấn có kiểu.
- Tiền lưu bằng số nguyên VND (minor unit = 1 đồng). Không dùng float cho số tiền.
- Mọi lệnh tạo chuyến, đơn, offer và bút toán nhận `Idempotency-Key`.
- Assignment và chuyển trạng thái nhạy cảm chạy trong transaction. Chấp nhận một người thắng bằng ràng buộc duy nhất hoặc cập nhật có điều kiện trạng thái, không dựa vào kiểm tra rồi ghi ở client.

## Consequences

- `DATABASE_URL` là secret vận hành. Local dùng Docker Compose, user/password chỉ dành cho máy dev và được ghi trong `.env.example`.
- Prisma Client không được import từ Flutter hay từ Client Component của Admin Web.
