# DealGo

Nền tảng **Ride** (xe hai bánh) và **Food** (giao đồ ăn) — monorepo gồm mobile, admin web, backend và hồ sơ sản phẩm.

## Cấu trúc

| Thư mục | Vai trò |
|---|---|
| `mobile/` | App Flutter đa vai trò: Customer / Merchant / Driver |
| `website/` | Admin Web (Next.js) — kênh vận hành nội bộ |
| `backend/` | API NestJS — nguồn sự thật cho quyền, giá, assignment, trạng thái |
| `docs/` | Hồ sơ sản phẩm và kỹ thuật |
| `design/` | Mockup màn hình và thư viện asset UI |
| `.ai-coding-team/` | Orchestrator + contracts cho AI coding agents |

Điểm vào cho agent: [`AGENTS.md`](./AGENTS.md). Governance: [`docs/00-governance/`](./docs/00-governance/).

## Chạy nhanh (scaffold)

```bash
# Mobile
cd mobile && flutter pub get && flutter run

# Admin Web
cd website && npm install && npm run dev

# Backend
cd backend && npm install && npm run start:dev
```

Stack chi tiết (ORM, Redis, state management, thanh toán…) chỉ áp dụng khi đã có quyết định `CONFIRMED` / ADR trong `docs/`.
