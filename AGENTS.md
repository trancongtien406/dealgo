# DealGo — Hướng dẫn cho AI Coding Agents

> Điểm vào bắt buộc trước khi lập trình, review hoặc thiết kế trong repository này.
> Tài liệu sản phẩm chi tiết nằm ở `docs/`. Bộ điều phối agent nằm ở `.ai-coding-team/`.

## 1. Sản phẩm (đã xác nhận)

| ID | Quyết định | Trạng thái |
|---|---|---|
| `DEC-PROD-001` | MVP gồm **Ride** (xe hai bánh) và **Food** (giao đồ ăn) | `CONFIRMED` |
| `DEC-PROD-002` | **Một** app Flutter cho Customer / Merchant / Driver | `CONFIRMED` |
| `DEC-PROD-003` | Tham khảo luồng công khai Grab/GrabFood/ShopeeFood; **không** sao chép UI hay giả định logic nội bộ | `CONFIRMED` |
| `DEC-PROD-004` | Cần hồ sơ đủ để triển khai, kiểm thử và vận hành thực tế | `CONFIRMED` |

- **Admin Web** (`website/`) là kênh vận hành riêng, không phải role thứ tư trong app Flutter.
- **Server là nguồn sự thật** cho quyền, giá đã chốt, assignment, trạng thái và ledger. Client chỉ hiển thị/resync.

## 2. Cấu trúc repository

| Thư mục | Vai trò hiện tại |
|---|---|
| `mobile/` | Flutter app (scaffold; chưa khóa state management / DI bằng ADR) |
| `website/` | Admin Web — Next.js 16, React 19, Tailwind v4 |
| `backend/` | NestJS 11 scaffold — **chưa** có ORM/DB/queue đã phê duyệt |
| `docs/` | Hồ sơ sản phẩm/kỹ thuật — nguồn chuẩn cho scope và quyết định |
| `design/` | Mockup màn hình (`mockups/`) và thư viện asset UI (`assets/batch01`, `assets/batch02`) |
| `.ai-coding-team/` | Orchestrator, 7 specialist (canonical) + contracts |
| `.cursor/agents/`, `.cursor/rules/` | Bản nạp Cursor (stack rules gắn glob theo `website/`, `mobile/`, `backend/`) |
| `.claude/agents/`, `.claude/rules/` | Bản nạp Claude Code |

Stack rules dự án **không** phụ thuộc `~/.cursor/rules` global. Globs Cursor: comma + space, **không** dùng brace `{ts,tsx}`.

## 3. Thứ tự ưu tiên khi có xung đột

1. Chỉ thị hệ thống / giới hạn công cụ / chính sách an toàn
2. Yêu cầu người dùng trong phiên (đúng phạm vi được ủy quyền)
3. Quyết định `CONFIRMED` / ADR `ACCEPTED` trong `docs/`
4. Code và lockfile đang có trong repository
5. Rules dự án (`.cursor/rules/`, `.claude/rules/`)
6. Agent playbook (`.ai-coding-team/agents/*`)
7. Ví dụ minh họa trong agent (DealGo ride/food, VietnamTour…) — **chỉ là mẫu**, không phải contract nghiệp vụ

`TBD` / `OPEN-*` / `ASM-*` **không** được tự chốt thành chính sách tính tiền, phân quyền, thanh toán hoặc pháp lý.

## 4. Công nghệ — scaffold ≠ đã phê duyệt

Hiện có scaffold:

- Flutter trong `mobile/`
- Next.js trong `website/`
- NestJS trong `backend/`

**Chưa** được Charter/ADR khóa: Prisma, PostgreSQL, Redis, Kafka, Bloc/Provider, FCM, cổng thanh toán, v.v.

- Được đề xuất kèm trade-off và đánh dấu `PROPOSAL`.
- Không cài hàng loạt dependency “chuẩn production” chỉ vì rule stack đề cập.
- Khi ADR/`DEC` đã chốt stack, cập nhật rule + code theo quyết định đó.

## 5. AI Coding Team

- Main Agent = Orchestrator. Đọc `.ai-coding-team/agents/orchestrator.md` khi task cần triển khai / design / test / debug / review.
- Specialist Cursor: `.cursor/agents/` — `ui-designer`, `flutter-expert`, `frontend-developer`, `backend-developer`, `test-automator`, `code-reviewer`, `debugger`.
- Contracts: `.ai-coding-team/contracts/{ROUTING,WORK_ORDER,AGENT_RESULT,QUALITY_GATES}.md`.
- Phân công theo **nội dung công việc**, không theo tên thư mục.
- Không tuyên bố đã gọi subagent / đã PASS test nếu chưa thực thi thật.

## 6. Tài liệu bắt buộc phải đọc theo loại việc

| Loại việc | Đọc trước |
|---|---|
| Mọi task | `AGENTS.md` (file này), `docs/00-governance/README.md` |
| Scope / blocker | `docs/00-governance/decisions-and-assumptions.md`, `project-charter.md` |
| Product / AC | `docs/01-product/*` |
| UI/UX | `docs/01-product` + design handoff nếu có; gọi `ui-designer` khi còn quyết định UX |
| API / domain | `docs/` nhóm domain/workflow/API khi đã có; không bịa endpoint |

## 7. Cấm mặc định

- Tự tách 3 app mobile thay vì một app multi-role
- Biến ví dụ Grab thành rule DealGo
- Deploy production, force-push, migration phá dữ liệu, lộ secret
- Coi cache/push/socket client là nguồn sự thật thay backend
- Hardcode chính sách phí / hủy / thanh toán khi vẫn `OPEN-*`
