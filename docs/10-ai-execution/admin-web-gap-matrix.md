---
doc_id: DG-AI-004
title: "DealGo — Admin Web gap matrix"
version: "1.0.0"
status: "ACTIVE"
owner: "Tech Lead"
last_updated: "2026-10-26"
---

# Admin Web gap matrix

> Lint / `tsc` xanh không phải là Done. Done = màn hình đọc và ghi dữ liệu thật qua BFF → Nest, có trạng thái loading / lỗi / rỗng, và quyền đúng theo RBAC ops.

Tài liệu mô tả hiện trạng của `website/` (Next.js). Code là nguồn chuẩn.

## Kiến trúc

- Trình duyệt chỉ gọi Route Handlers cùng origin `website/app/api/ops/*`; BFF gọi Nest phía server (`DEALGO_API_BASE_URL`). Mutation kiểm same-origin.
- Phiên ops: cookie; `requireOpsSession` kiểm token với Nest, cache kết quả thành công trong process theo `OPS_SESSION_PROBE_TTL_MS` (mặc định 15 000 ms, giới hạn 5 000–30 000).
- Mã nguồn theo feature (`website/features/*`), dữ liệu qua TanStack Query, tham số lọc trên URL (nuqs).
- Không còn chế độ dữ liệu giả: mọi bảng đọc API thật.
- Lọc theo ngày ở Giao dịch (`/transactions`), Giao hàng (`/deliveries`), Đối soát (`/settlements`) và Kiểm duyệt món (`/catalog/moderation`) chạy ở server. Nút thời gian ở đầu trang (Hôm nay, 7 ngày, tháng này, khoảng tuỳ chọn, Tất cả) và ô "Thời gian" của Giao dịch dùng chung một giá trị. Giá trị nằm trên URL (`from`/`to`, `YYYY-MM-DD`) ở Giao dịch, Giao hàng và Kiểm duyệt món; Đối soát giữ trong state của trang. BFF chỉ chuyển tiếp ngày hợp lệ và tự đảo khi `from` > `to` (`lib/api/ops-date-range.ts`). Nest coi `from`/`to` là ngày làm việc giờ Việt Nam, tính cả hai đầu: Giao dịch lọc theo `PaymentIntent.createdAt`, Giao hàng theo thời điểm đặt đơn, Kiểm duyệt món theo `FoodItem.createdAt` (thời điểm gửi duyệt), Đối soát theo ngày làm việc của lô. `from` > `to` hoặc ngày sai định dạng → 400 `DATE_RANGE_INVALID`. Mặc định là Tất cả thời gian. Cột Thời gian của Giao hàng và cột Gửi duyệt hiển thị giờ Việt Nam.
- CSP `connect-src` dựng trong `next.config.ts` từ `'self'` + origin `NEXT_PUBLIC_API_BASE_URL`; `localhost` / `ws:` chỉ có ở dev.

## Màn hình và nguồn dữ liệu

| Nhóm | Route | Nguồn Nest |
|---|---|---|
| Tổng quan, giám sát, báo cáo | `/overview`, `/monitor`, `/reports` | `/v1/ops/overview` (Báo cáo dùng lại cùng dữ liệu), `/v1/ops/monitor/snapshot` |
| Chuyến xe, trả giá | `/rides`, `/rides/[code]`, `/negotiations` | `/v1/ops/rides` (+ ledger, huỷ, gán lại) |
| Đơn đồ ăn, giao hàng | `/food-orders`, `/deliveries` | `/v1/ops/food-orders` (+ ledger, huỷ, gán lại) |
| Ngoại lệ | `/exceptions` | `/v1/ops/exceptions` (danh sách; can thiệp ở trang chi tiết chuyến/đơn) |
| Khách hàng | `/customers`, `/customers/[code]` | `/v1/ops/customers` |
| Tài xế, KYC | `/drivers`, `/drivers/[code]`, `/drivers/kyc` | `/v1/ops/drivers`, đơn đối tác; thẻ công nợ phí nền tảng |
| Quán, KYB, thực đơn | `/stores`, `/stores/[code]`, `/stores/approvals`, `/catalog`, `/catalog/moderation` | `/v1/ops/food-stores`, kiểm duyệt món; sao kê và ghi nhận "đã trả quán" |
| Tiền | `/transactions`, `/settlements`, `/refunds` | `PaymentIntent`, đối soát, yêu cầu hoàn tiền |
| Khiếu nại, hỗ trợ | `/disputes`, `/support-tickets` | `/v1/ops/disputes`, phiếu hỗ trợ; xem chat có lý do (`chat.review`) |
| Khuyến mãi, thông báo | `/promotions`, `/notifications` | `/v1/ops/promotions`, chiến dịch thông báo |
| Khu vực & giá | `/zones` | `/v1/ops/zones` |
| Nhân sự, audit | `/staff`, `/audit-logs` | nhân sự + ma trận RBAC, nhật ký audit |
| Cài đặt | `/settings/platform` (Tham số), `/settings/auth-methods`, `/settings/vehicle-classes`, `/settings/faqs`, `/settings/content` | cài đặt nền tảng, phương thức đăng nhập, hạng xe, FAQ, trang công khai |
| Công khai | `/support`, `/privacy`, `/terms`, `/chia-se-chuyen/[token]` | form hỗ trợ → `POST /v1/public/support/tickets`; trang nội dung; theo dõi chuyến được chia sẻ |

## Khoảng trống

| Khoảng trống | Ghi chú |
|---|---|
| Doanh thu / hoa hồng ở Tổng quan | Nest trả `revenueVnd` / `commissionVnd` = `null`; số hoa hồng xem ở Đối soát |
| Báo cáo | `/reports` hiển thị số liệu Tổng quan, bộ lọc thời gian chưa được gửi lên API |
| Hoàn tiền | Chỉ ghi nhận bản ghi + bút toán sandbox; chưa chuyển tiền thật |
| Audit hạng xe | Sửa hạng xe không ghi nhật ký audit |
| Bộ lọc thời gian các danh sách khác | Nút thời gian ở Chuyến xe, Trả giá, Khuyến mãi, Thông báo, Hoàn tiền, Khiếu nại, Khách hàng chưa gửi `from`/`to` lên API |
| Kiểm thử trình duyệt | Chỉ có vitest + typecheck + lint; chưa có E2E trình duyệt |
