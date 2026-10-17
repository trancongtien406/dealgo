---
doc_id: DG-AI-001
title: "DealGo — Implementation roadmap"
version: "0.1.0"
status: "PROPOSED"
owner: "Tech Lead"
last_updated: "2026-10-14"
related_decisions:
  - DEC-PROD-001
  - DEC-PROD-002
  - ADR-001
  - ADR-006
---

# Lộ trình triển khai

Thứ tự là lát cắt dọc. Một phase xong khi API, client liên quan và test của phase đó chạy được trên adapter mock. Không chờ đủ 165 màn và 35 trang admin trước khi nối luồng.

Chính sách giá, vùng thương mại, pháp lý đối tác và vendor thật vẫn là `OPEN-*`. Code dùng cấu hình `TEST_ONLY` và fail closed khi thiếu policy tiền thật.

| Phase | Kết quả quan sát được | Owner chính |
|---|---|---|
| 0 | ADR-001..006, overview, catalog secret | Orchestrator |
| 1 | API health + config; Postgres/Redis local; Flutter token và 3 shell; Admin login + khung A003 | Backend, Flutter, Frontend |
| 2 | Đăng ký/đăng nhập: passkey, SMS mock, email mock; session; chọn vai trò đã được cấp | Backend, Flutter, Frontend |
| 3 | Ride: giá tham khảo, khách đề xuất, tài xế counter, khách chọn, một assignment | Backend, Flutter |
| 4 | Food: cửa hàng, menu, giỏ một quán, đơn, merchant nhận, tài xế giao | Backend, Flutter |
| 5 | Sổ cái sandbox, COD ghi nhận, hoàn điều chỉnh có audit; không thu tiền thật | Backend, Frontend |
| 6 | Admin: duyệt KYC/KYB, xem chuyến/đơn, hàng ngoại lệ | Frontend, Backend |
| 7 | Realtime snapshot, push mock, chat theo giao dịch, thoại mock | Backend, Flutter |
| 8 | Ma trận test P0, CI, runbook local | Test, Backend |

**Trạng thái thật (2026-10-14):** Backend foundation ~**90%+** after **Phase H+I** (FCM/LiveKit/PSP stubs, ops cancel/reassign, presence, history, store geo, auth-method flags). Admin detail intervene + auth-methods live; customers/drivers/stores still fixture. Flutter: architecture remediation (one Dio, `core/design_system`, FCM/deeplink/analytics/motion shells) — **không** claim production Firebase. Owner **1A** giữ `DEC-PROD-007`; **2A** adapters + `TEST_ONLY` env — **không** coi là policy `OPEN-*` đã duyệt. Test xanh ≠ Done.
