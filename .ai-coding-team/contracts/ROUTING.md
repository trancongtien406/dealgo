# ROUTING — Hợp đồng chọn Agent (v1.1)

> Orchestrator là **Main Agent**. Các specialist nằm trong `.cursor/agents/` hoặc `.claude/agents/` tùy host (nguồn chuẩn: `.ai-coding-team/agents/`). Quy tắc ở đây chỉ định cách chọn; hệ thống không tự giả định đã gọi agent.
>
> Trước khi định tuyến task DealGo: đọc `AGENTS.md` và quyết định `CONFIRMED` trong `docs/00-governance/`.

## Nguyên tắc ưu tiên

1. Ưu tiên tác vụ và kết quả người dùng yêu cầu hơn tên thư mục, ngôn ngữ lập trình hay route name.
2. Sửa nhỏ, ít rủi ro: Main hoặc **một** specialist; không triệu tập cả đội.
3. Cần quyết định thiết kế UI/UX? `ui-designer` → bàn giao đặc tả → `flutter-expert` hoặc `frontend-developer`.
4. Có thiết kế sẵn, cần code Flutter? `flutter-expert`. Cần code web? `frontend-developer`. Logic/API/DB? `backend-developer`.
5. Yêu cầu test/đối chiếu acceptance criteria? `test-automator`. Lỗi chưa rõ nguyên nhân? `debugger`.
6. Thay đổi business logic rủi ro vừa/cao, quyền người dùng, thanh toán hoặc dữ liệu quan trọng: `code-reviewer` độc lập sau implementation và testing.
7. Không gọi `ui-designer` vì code nằm trong `frontend/` hoặc `mobile/`. Không gọi `debugger` nếu yêu cầu chỉ là feature mới.
8. Không tự tạo DevOps/Security/DBA Agent thứ tám. Giao đúng specialist hiện có và tăng quality gates khi cần.
9. Không giả mạo delegation; nếu thiếu công cụ gọi agent, thực thi tuần tự và báo `INDEPENDENT_REVIEW_NOT_PERFORMED` nếu thích hợp.

## Ma trận tham khảo

| Loại task | Owner | Specialist phụ theo nhu cầu |
| --- | --- | --- |
| Sửa spacing/animation theo spec đã chốt | `flutter-expert` / `frontend-developer` | reviewer nếu risk cao |
| Thiết kế lại trang profile | `ui-designer` | Flutter/Web implement → tester |
| Viết endpoint + DB transaction | `backend-developer` | tester → reviewer |
| Sửa lỗi Flutter Bloc bị reset | `debugger` để RCA nếu chưa rõ | flutter-expert → tester |
| Thêm flow khách–shop–shipper | Orchestrator phân rã | UI/Backend/Flutter/Web → test → review |
| Audit một diff | `code-reviewer` | debugger nếu phát hiện root cause khó |
| Viết E2E Playwright | `test-automator` | frontend owner sửa lỗi phát hiện |

## Điều phối phụ thuộc và quyền sở hữu

- Xác định file/module owner cho từng task trước khi cho chạy song song. Hai agent không viết cùng vùng file trong cùng checkout.
- Việc có contract ổn định mới được chạy song song phần consumer/provider. Không có contract: chốt contract trước.
- Tránh mở quá 2–3 specialist cùng lúc trong MVP; có thể hạ xuống 1 khi codebase nhỏ hoặc context thiếu.
- Khi dùng worktree riêng: xác nhận cách mang thay đổi trở lại branch chính; không coi kết quả trong worktree là đã tích hợp.
- Reviewer mặc định read-only. Nếu môi trường chỉ giới hạn bằng prompt, nêu giới hạn này.

## State machine logic

`READY -> IMPLEMENTING -> IMPLEMENTED -> VERIFYING -> REVIEWING -> INTEGRATED -> DONE`

Nhánh lỗi: `VERIFYING/REVIEWING -> FIX_REQUIRED -> IMPLEMENTING`. Nhánh dừng: `BLOCKED`, `NEEDS_APPROVAL`, `FAILED`. Không nhảy thẳng từ IMPLEMENTED sang DONE khi chưa có evidence tương ứng AC.
