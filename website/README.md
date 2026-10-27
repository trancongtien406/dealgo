# DealGo Admin Web

Kênh vận hành nội bộ (Next.js 16, React 19, Tailwind CSS v4): giám sát chuyến và đơn, can thiệp huỷ / gán lại, duyệt KYC/KYB, khiếu nại và hoàn tiền, đối soát, khuyến mãi, khu vực & giá, cài đặt nền tảng, nhân sự và audit. Có thêm các trang công khai `/support`, `/privacy`, `/terms`, `/chia-se-chuyen/[token]`.

Admin không phải một vai trò trong app Flutter.

## Chạy

```bash
npm install
npm run dev        # http://localhost:3000
```

Cần backend Nest đang chạy; BFF gọi `DEALGO_API_BASE_URL` (mặc định `http://localhost:3001`). Biến môi trường khác: [`../docs/09-operations/secrets-and-env-catalog.md`](../docs/09-operations/secrets-and-env-catalog.md).

## Kiểm tra

```bash
npm run lint
npm run typecheck
npm run test       # vitest
```

## Kiến trúc

- Trình duyệt chỉ gọi Route Handlers cùng origin trong `app/api/ops/*`; BFF gọi Nest phía server, mutation kiểm same-origin.
- Mã theo feature trong `features/*`, dữ liệu qua TanStack Query, bộ lọc trên URL.
- Hiện trạng và khoảng trống: [`../docs/10-ai-execution/admin-web-gap-matrix.md`](../docs/10-ai-execution/admin-web-gap-matrix.md).
