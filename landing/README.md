# DealGo Landing Page

Trang Web Marketing công khai (Public Landing Page) của nền tảng **DealGo** — giới thiệu dịch vụ Gọi xe hai bánh (**DealGo Ride**), Giao đồ ăn (**DealGo Food**), tính năng **Deal Giá độc quyền**, và tuyển dụng đối tác Tài xế / Quán ăn.

## Công nghệ & Kiến trúc

- **Framework**: Next.js 16 (Turbopack, App Router)
- **UI & Styling**: React 19, Tailwind CSS v4, Glassmorphism, Theme Tokens DealGo
- **Chế độ màu**: Hỗ trợ đầy đủ Dark Mode & Light Mode
- **Cổng chạy mặc định**: `http://localhost:3002` (tránh xung đột với Admin Web trên `3000` và API trên `3001`)

## Cài đặt & Khởi chạy

```bash
# Cài đặt thư viện
npm install

# Khởi chạy môi trường phát triển (cổng 3002)
npm run dev

# Kiểm tra kiểu dữ liệu TypeScript
npm run typecheck

# Build phiên bản sản xuất
npm run build
```

Mở trình duyệt truy cập: [http://localhost:3002](http://localhost:3002).
