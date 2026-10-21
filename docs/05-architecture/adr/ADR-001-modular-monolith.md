---
doc_id: ADR-001
title: "Modular monolith trên NestJS"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - DEC-PROD-001
  - DEC-PROD-004
---

# ADR-001 — Modular monolith trên NestJS

## Status

`PROPOSED`. Chủ dự án yêu cầu ngày 2026-10-13 chọn stack production để code tiếp, chỉ điền secret sau. Chưa có biên bản `ACCEPTED`. Code Phase 1 trở đi bám đề xuất này cho đến khi bị supersede.

> Đã triển khai trong code (rà soát 2026-10-18): NestJS 12 modular monolith trong `backend/src/modules/*`. Trạng thái vẫn `PROPOSED` — chủ repo cần quyết định `ACCEPTED`/supersede.

## Context

MVP là Ride hai bánh và Food trên một Flutter app, cộng Admin Web. Backend hiện là scaffold NestJS, chưa có ORM. Tách microservice ngay từ đầu làm tăng chi phí giao dịch, quan sát và triển khai khi chưa có SLO (`OPEN-007`).

## Decision

Một process NestJS, chia module theo bounded context. Mỗi module sở hữu use case và không đọc bảng của module khác ngoài contract công khai (service/port).

Module dự kiến: `identity`, `access`, `merchant`, `catalog`, `ride`, `food`, `dispatch`, `location`, `ledger`, `comms`, `ops`.

Server là nguồn sự thật cho quyền, giá đã chốt, assignment, trạng thái và sổ cái.

## Consequences

- Triển khai một artifact API. Tách service sau chỉ khi một context có tải hoặc vòng đời deploy riêng và có ADR mới.
- Không dùng Kafka ở MVP. Hàng đợi nội bộ nằm ở ADR-003.
- Giao tiếp liên module trong process đi qua application service, không qua HTTP nội bộ.
