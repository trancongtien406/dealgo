---
doc_id: ADR-005
title: "Admin Web là BFF Next.js"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - DEC-PROD-002
---

# ADR-005 — Admin Web

## Status

`PROPOSED`.

**Hiện trạng trong code:** Route Handlers BFF trong `website/app/api/ops/*`. Quyết định chờ chủ dự án chuyển sang `ACCEPTED` hoặc thay thế.

## Context

Admin Web tại `website/` là Next.js 16.4 và React 19.3, Tailwind CSS 4. Kênh này không phải vai trò thứ tư trong app Flutter. Mockup A001–A035 nằm ở `design/mockups/screens/admin/`.

## Decision

- Next.js là BFF và giao diện vận hành. Không nhân bản luật giá, phân công hay sổ cái sang Next.js.
- Session admin dùng cookie `HttpOnly`. Browser không giữ access token dài hạn trong `localStorage`.
- Route Handler hoặc server fetch gọi NestJS. Secret chỉ ở server.
- Giao diện bám token admin: sidebar 238px, header 64px, primary `#6D28D9`, canvas `#F8F8FD`, font Inter.
- Menu hiển thị không thay thế kiểm tra quyền trên API.

## Consequences

- Cổng dev: website `3000`, API `3001`.
- Trang private đặt `noindex`.
