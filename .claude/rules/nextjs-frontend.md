# Admin Web (Next.js) — DealGo

Áp dụng khi làm việc trong `website/`. Chi tiết đầy đủ: `.cursor/rules/nextjs-frontend.mdc`.

- `website/` = Admin Web vận hành, không phải role thứ tư của Flutter.
- Stack hiện có: Next.js 16, React 19, Tailwind v4 — tôn trọng lockfile.
- Async request APIs (`params`, `searchParams`, `cookies`, `headers`) cần `await`.
- Không bịa API/role/enum; lấy contract từ backend/docs đã xác nhận.
- Không dùng emoji trong UI/log kỹ thuật trừ khi product yêu cầu.
