# DealGo Phase 19.4 — 25 UI state variants

- `screens/`: 25 HTML + 25 PNG cho 18 route, không tăng 165 route hiện hành.
- `preview/gallery.html`: xem ảnh offline (mở sau khi giải nén ZIP).
- `preview/DealGo_Phase19_4_25_States.jpg`: bảng tổng hợp.
- `docs/screen_state_matrix.csv`: 25 variant với trigger, hành động, guardrail.
- `docs/screen_state_165_matrix.csv`: đề xuất bao phủ trạng thái cho 165 màn (chỉ 25 đã có ảnh mới).
- `docs/03_DESIGN_SYSTEM_FREEZE_CANDIDATE.md`: token freeze candidate, **chưa được duyệt production**.
- `flutter/dealgo_ui_states.dart`: widget/contract tham khảo, **chưa build bằng Flutter SDK**.

**Lưu ý:** Ảnh là mockup tĩnh, không phải UI production. Bộ 165 màn gốc chỉ là ảnh PNG, vì vậy Ph 19.4 bổ sung state variants chứ không thay hình của 165 route. C001 được bảo tồn nguyên bytes trong bộ ZIP đầy đủ. Dữ liệu giá, đơn hàng và COD là fixture mô phỏng.
