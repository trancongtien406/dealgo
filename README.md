# DealGo

Nền tảng **Ride** (xe máy, ô tô 4 chỗ, ô tô 7 chỗ; trả giá kiểu inDrive, không tự ghép) và **Food** (giao đồ ăn), gồm app mobile, Admin web, backend và hồ sơ sản phẩm.

## Cấu trúc

| Thư mục | Vai trò |
|---|---|
| `mobile/` | App Flutter một bản, ba vai trò: Customer / Driver / Merchant |
| `website/` | Admin web (Next.js) cho vận hành nội bộ, kèm trang công khai (hỗ trợ, điều khoản, chia sẻ chuyến) |
| `backend/` | API NestJS + worker BullMQ: nguồn sự thật cho quyền, giá, gán tài xế, trạng thái và sổ cái |
| `docs/` | Hồ sơ sản phẩm và kỹ thuật |
| `design/` | Mockup màn hình và asset UI |
| `performance/` | Kịch bản đo tải |
| `.ai-coding-team/` | Orchestrator và contract cho AI coding agent |

Điểm vào cho agent: [`AGENTS.md`](./AGENTS.md). Quyết định sản phẩm: [`docs/00-governance/`](./docs/00-governance/). Kiến trúc: [`docs/05-architecture/system-overview.md`](./docs/05-architecture/system-overview.md).

## Chạy local

```bash
# Postgres (cổng 5433) + Redis (6379)
docker compose up -d

# Backend: API cổng 3001 và worker
cd backend && npm install && npx prisma migrate deploy && npm run seed
npm run start:dev            # API
npm run start:worker:dev     # worker (terminal khác)

# Admin web: cổng 3000
cd website && npm install && npm run dev

# Mobile
cd mobile && flutter pub get && ./tool/run_dev.sh
```

Biến môi trường: [`docs/09-operations/secrets-and-env-catalog.md`](./docs/09-operations/secrets-and-env-catalog.md). Cổng dev thống nhất: Admin Web `3000`, API + Socket.IO `3001` (backend `PORT`, BFF `DEALGO_API_BASE_URL`, mobile `API_BASE_URL` đều mặc định `http://localhost:3001`). Android emulator dùng `API_BASE_URL=http://10.0.2.2:3001`.
