---
doc_id: ADR-004
title: "Flutter client: go_router và Bloc"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-13"
related_decisions:
  - DEC-PROD-002
---

# ADR-004 — Flutter client

## Status

`PROPOSED`.

**Hiện trạng trong code:** `go_router` + `flutter_bloc` trong `mobile/pubspec.yaml`. Quyết định chờ chủ dự án chuyển sang `ACCEPTED` hoặc thay thế.

## Context

Một app Flutter cho Customer, Merchant và Driver. Lúc đề xuất, `mobile/` mới có `lib/main.dart`. Cần điều hướng theo vai trò và state machine cho báo giá, chuyến và đơn.

## Decision

- `go_router` cho điều hướng. Ba shell riêng. Đổi vai trò không tạo `MaterialApp` thứ hai và xoá stack của vai trò trước.
- `flutter_bloc` cho luồng có vòng đời server (phiên, chuyến, đơn, việc tài xế). UI cục bộ nhỏ được dùng `setState`.
- `dio` là HTTP client duy nhất. Token refresh single-flight.
- Token nằm trong secure storage. Không lưu refresh token trong `shared_preferences`.
- Màu bám ảnh màn hình trong `design/mockups/screens/`. Primary `#6D28D9`, canvas `#FBFAFD`.
- Bản đồ, SMS, thanh toán, push đi qua cổng backend hoặc adapter có mock. App không nhúng secret server.

## Consequences

- `activeRole` chỉ là ngữ cảnh UI. Quyền vẫn do API quyết định.
- Package thêm vào `pubspec.yaml` phải resolve trên SDK Dart `^3.13.2` và khoá trong `pubspec.lock`.
