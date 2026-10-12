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

## Cursor Cloud specific instructions

- Không có `.fvmrc`. Flutter được ghim **3.47.7** (Dart 3.13.5) vì `mobile/pubspec.yaml` yêu cầu `sdk: ^3.13.2`. SDK ở `/opt/flutter`; `flutter` và `dart` có trên `PATH`.
- Android SDK ở `/opt/android-sdk` (`ANDROID_HOME`). JDK 21 ở `/usr/lib/jvm/java-21-openjdk-amd64` (`JAVA_HOME`). AGP 9.1 cần JDK tối thiểu 17; app biên dịch `JavaVersion.VERSION_17`. Các gói đã cài: platform `android-36`, Build-Tools `36.0.0`, NDK `28.2.13676358`, Platform-Tools, Emulator, cmdline-tools `15859902`. Login shell đọc `/etc/profile.d/dealgo-android.sh`.
- Kiểm tra mobile: `flutter doctor -v`, `flutter pub get`, `flutter analyze`, `flutter test` trong `mobile/`. APK debug: `flutter build apk --debug`. `mobile/android/gradle.properties` đặt heap Gradle `-Xmx8G`.
- Nếu `/dev/kvm` có mặt, script cài thêm user vào group sở hữu thiết bị. `emulator -accel-check` chỉ có ý nghĩa khi thiết bị đó tồn tại. Không tự boot emulator.
- `flutter doctor` có thể báo thiếu ninja và GTK cho Linux desktop. Android toolchain không dùng các gói đó.
- Admin Web (`website/`) cổng **3000**. API (`backend/`) cổng **3001** vì cả hai scaffold mặc định cổng 3000. `GET /` trả về `DealGo API`.
- Không có database hay secret. Cài dependency bằng `npm ci` trong `backend/` và `website/`.
