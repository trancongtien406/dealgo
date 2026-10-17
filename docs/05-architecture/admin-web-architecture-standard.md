# DealGo Admin Web & Full-Stack Architecture Standard

> Tài liệu chuẩn kiến trúc, quy tắc lập trình Senior và danh mục 38 màn hình vận hành DealGo Admin Web (`website/`) kết nối Backend NestJS (`backend/`).
> Tham chiếu quyết định: `DEC-PROD-001`, `DEC-PROD-002`, `ADR-005`.

---

## 1. Tổng quan hệ thống & Bối cảnh dự án

DealGo là nền tảng kết hợp **Ride** (xe hai bánh) và **Food** (giao đồ ăn), mở rộng thêm **Delivery** (giao hàng) và **Negotiation** (trả giá cuốc xe).
Hệ thống gồm 3 phân hệ chính:
1. **Mobile Client (`mobile/`)**: 1 ứng dụng Flutter đa vai trò (Customer, Merchant, Driver).
2. **Backend Services (`backend/`)**: NestJS 11 đóng vai trò là **Nguồn Sự Thật Duy Nhất (Single Source of Truth)** cho dữ liệu, quyền hạn, giá đã chốt, phân công, trạng thái và sổ cái giao dịch.
3. **Admin Web (`website/`)**: Next.js 16 (App Router), React 19, Tailwind CSS v4, TanStack Query v5, đóng vai trò là **BFF (Backend for Frontend)** và Bảng điều khiển tác nghiệp dành cho ban vận hành (Operations Team).

---

## 2. Quy tắc lập trình Senior (Senior Engineering Standards)

Để loại bỏ tình trạng code chắp vá, lệch chuẩn concept ("chỗ sửa chỗ không"), toàn bộ mã nguồn `website/` và `backend/` tuân thủ nghiêm ngặt 4 nguyên tắc sau:

### Nguyên tắc 1: Phân tách trách nhiệm & Cấu hình biến hàm đúng chỗ (Separation of Concerns)

Mỗi feature trong `website/features/<domain>/` bắt buộc phải có cấu trúc tệp rõ ràng, không dồn logic vào JSX:
```
features/<domain>/
├── types.ts          # Định nghĩa kiểu dữ liệu View, DTO, FilterParams
├── constants.ts      # Danh sách cột bảng, tabs, options filter, default pagination
├── api.ts            # Hàm fetch thuần túy (gọi BFF Route qua apiFetch)
├── hooks.ts          # React Query (useQuery, useMutation), URL search params (nuqs)
├── mappers.ts        # Hàm chuyển đổi dữ liệu, định dạng nhãn (label), màu sắc (tone)
└── components/       # Các UI components (board, detail, modal, table)
```

* **Vị trí khai báo biến/hàm**:
  - Không viết logic lọc, tính toán doanh thu hay format tiền tệ trực tiếp trong JSX. Toàn bộ phải nằm trong `useMemo` hoặc hàm helper ở `mappers.ts`.
  - Không đặt các hàm xử lý sự kiện phụ bên ngoài component nếu cần truy cập state; ngược lại, các hàm helper thuần túy (pure functions) phải chuyển ra ngoài hoặc đưa vào file tiện ích để tránh re-declare mỗi lần re-render.
  - Các hằng số bảng (`COLUMNS`, `COLUMN_COUNT`, `TABS`) bắt buộc đặt ở `constants.ts`, không hardcode số cột trong file component.

---

### Nguyên tắc 2: Cỗ máy trạng thái loại trừ lẫn nhau (Mutually Exclusive State Machine)

Giao diện vận hành **tuyệt đối không được hiển thị mâu thuẫn**:
* ❌ Không thể vừa thấy bảng rỗng vừa thấy báo lỗi mạng.
* ❌ Không thể vừa thấy skeleton loading vừa hiện dữ liệu cũ.
* ❌ Không được mất thanh điều hướng (Breadcrumb/Header) khi trang rơi vào trạng thái lỗi hay loading.

#### Cấu trúc Single Return Pattern chuẩn:
```tsx
export function EntityBoard() {
  const { data, isPending, isError, error, refetch } = useEntityQuery(filters);
  const forbidden = isError && isForbiddenError(error);
  const items = data?.items ?? [];
  const total = data?.total ?? 0;

  return (
    <div className="min-w-0 space-y-5">
      {/* 1. Thông báo lỗi phụ (nếu có lỗi nền nhưng vẫn còn dữ liệu cũ) */}
      {isError && !forbidden ? (
        <AdminListErrorBanner message="Không thể đồng bộ dữ liệu mới nhất." onRetry={() => void refetch()} />
      ) : null}

      {/* 2. Breadcrumb điều hướng cố định trên cùng */}
      <AdminBreadcrumb items={[{ label: "Trang chủ", href: "/overview" }, { label: "Danh sách" }]} />

      {/* 3. Header trang (Tiêu đề, mô tả, nút công cụ) */}
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Tiêu đề trang</h1>
          <p className="mt-1 text-sm text-muted">Mô tả tác vụ vận hành.</p>
        </div>
        <div className="flex flex-wrap items-end gap-2">
          {/* Action buttons: Filter ngày, Refresh, Export CSV */}
        </div>
      </div>

      {/* 4. Thanh lọc dữ liệu */}
      <AdminFilterToolbar>
        {/* Các trường tìm kiếm & SearchSelect */}
      </AdminFilterToolbar>

      {/* 5. Cỗ máy trạng thái (Loại trừ lẫn nhau hoàn toàn) */}
      {forbidden ? (
        <AdminForbiddenState title="Không có quyền truy cập" description="..." />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner message="Lỗi kết nối máy chủ." onRetry={() => void refetch()} />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState icon="box" title="Không tìm thấy dữ liệu" action={<AdminResetFilterButton onClick={resetFilters} />} />
      ) : (
        <div className="space-y-4">
          <AdminTableContainer minWidth="min-w-[1080px]">
            <AdminTable ariaBusy={isPending} caption="...">
              <AdminTableHeader>...</AdminTableHeader>
              <AdminTableBody>
                {isPending ? (
                  <AdminTableBodyShimmer columns={COLUMN_COUNT} />
                ) : (
                  items.map(row => <AdminTableRow key={row.id}>...</AdminTableRow>)
                )}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
          <ListPager page={filters.page} pageSize={filters.limit} total={total} onPageChange={...} />
        </div>
      )}
    </div>
  );
}
```

---

### Nguyên tắc 3: Xử lý dữ liệu tại Server / Backend (Zero Client-Side Filtering & Pagination)

* **Không lọc hay phân trang bằng Javascript ở Client**:
  - Không tải toàn bộ 1,000 bản ghi về trình duyệt rồi dùng `array.filter(...)`, `array.sort(...)`, `array.slice(...)`.
  - Mọi thao tác: Tìm kiếm từ khóa (`q`), trạng thái (`status`), khoảng ngày (`from`, `to`), phân trang (`page`, `limit`), sắp xếp (`sort`) **bắt buộc** được chuyển thành query params gửi lên Next.js BFF (`/api/ops/...`).
* **Trách nhiệm Full-Stack Senior**:
  - Nếu API backend NestJS chưa có tham số tương ứng (ví dụ: thiếu lọc theo ngày `startDate`/`endDate`), **tiến hành viết bổ sung DTO, Controller và Service trong `backend/src/modules/*`** đúng chuẩn NestJS, không được chắp vá lọc tạm bợ ở web client.

---

### Nguyên tắc 4: Chuẩn hóa Table & Tránh lỗi 2 lớp viền (Double Border)

* `<AdminTableContainer>` đã có sẵn `rounded-2xl border border-border bg-white shadow-xs`. Tuyệt đối không bao bọc thêm `<section className="border border-border">` bên ngoài.
* Không thêm class lặp lại `text-ink` hay `whitespace-nowrap` vào từng `<AdminTableCell>` vì primitive đã cung cấp sẵn.

---

## 3. Danh mục 38 Màn hình Admin chia theo 4 Phase

### Phase 1: Vận hành cốt lõi (Core Operations) — 8 màn hình
| STT | Route | Thành phần giao diện | Trách nhiệm nghiệp vụ |
|---|---|---|---|
| 1 | `/rides` | `RidesList` | Quản lý, tra cứu, hủy & tái phân công chuyến xe |
| 2 | `/rides/[code]` | `RideDetail` | Chi tiết lộ trình, giá chốt, tài xế & nhật ký cuốc xe |
| 3 | `/food-orders` | `FoodOrdersList` | Quản lý đơn giao đồ ăn, trạng thái quán & tài xế |
| 4 | `/food-orders/[code]` | `FoodOrderDetail` | Chi tiết món, phụ phí, tiến độ bếp & giao nhận |
| 5 | `/deliveries` | `DeliveriesList` | Đơn vận chuyển hàng hóa, kích thước kiện & lộ trình |
| 6 | `/deliveries/[code]` | `DeliveryDetail` | Chi tiết kiện hàng, người nhận, ảnh xác thực giao |
| 7 | `/negotiations` | `NegotiationsList` | Phiên thương lượng giá cuốc giữa khách và tài xế |
| 8 | `/negotiations/[code]` | `NegotiationDetail` | Chi tiết lịch sử trả giá, mức sàn/trần & lý do chốt |

### Phase 2: Mạng lưới Đối tác, Danh mục & Khách hàng — 11 màn hình
| STT | Route | Thành phần giao diện | Trách nhiệm nghiệp vụ |
|---|---|---|---|
| 9 | `/drivers` | `DriversList` | Danh bạ tài xế, trạng thái hoạt động & đánh giá |
| 10 | `/drivers/[code]` | `DriverDetail` | Hồ sơ cá nhân, phương tiện, ví tiền & vi phạm |
| 11 | `/drivers/kyc` | `KycQueueBoard` | Hàng đợi xác thực bằng lái, CCCD, cavet xe |
| 12 | `/drivers/kyc/[code]` | `KycCaseDetail` | Thẩm định hồ sơ, đối chiếu ảnh, duyệt hoặc từ chối KYC |
| 13 | `/stores` | `StoresList` | Danh sách quán ăn/nhà hàng trên sàn |
| 14 | `/stores/[code]` | `StoreDetail` | Hồ sơ kinh doanh, menu, giờ mở cửa & chiết khấu |
| 15 | `/stores/approvals` | `StoreApprovalsBoard` | Xét duyệt hồ sơ mở quán mới (KYB) |
| 16 | `/catalog` | `CatalogBoard` | Quản lý danh mục món ăn & sản phẩm toàn sàn |
| 17 | `/catalog/moderation` | `CatalogModerationBoard` | Kiểm duyệt món mới, hình ảnh & giá đăng ký |
| 18 | `/customers` | `CustomersList` | Danh sách người dùng, khách hàng ứng dụng |
| 19 | `/customers/[code]` | `CustomerDetail` | Lịch sử đặt xe, đặt đồ ăn, khiếu nại & trạng thái ví |

### Phase 3: Tài chính, Khiếu nại, Khuyến mãi & Ngoại lệ — 8 màn hình
| STT | Route | Thành phần giao diện | Trách nhiệm nghiệp vụ |
|---|---|---|---|
| 20 | `/transactions` | `TransactionsList` | Sổ cái dòng tiền, giao dịch COD, thanh toán ví/thẻ |
| 21 | `/settlements` | `SettlementsBoard` | Chu kỳ đối soát doanh thu, khấu trừ phí & chi trả |
| 22 | `/refunds` | `RefundsBoard` | Hàng đợi xem xét & phê duyệt hoàn tiền |
| 23 | `/disputes` | `DisputesList` | Danh sách tranh chấp giữa khách, quán và tài xế |
| 24 | `/disputes/[code]` | `DisputeDetail` | Hồ sơ chứng cứ, trao đổi 3 bên & phán quyết đền bù |
| 25 | `/exceptions` | `ExceptionsBoard` | Cảnh báo sai lệch hệ thống, cuốc xe/đơn hàng lỗi |
| 26 | `/promotions` | `PromotionsBoard` | Quản lý voucher, mã giảm giá, ngân sách khuyến mãi |
| 27 | `/notifications` | `NotificationsBoard` | Chiến dịch gửi thông báo push & tin tức in-app |

### Phase 4: Giám sát, Quản trị hệ thống & Cài đặt — 11 màn hình
| STT | Route | Thành phần giao diện | Trách nhiệm nghiệp vụ |
|---|---|---|---|
| 28 | `/overview` | `OverviewDashboard` | Bảng điều khiển KPI tổng quan thời gian thực |
| 29 | `/monitor` | `MonitorBoard` | Bản đồ nhiệt live, định vị tài xế & đơn hàng trực tiếp |
| 30 | `/reports` | `ReportsBoard` | Báo cáo phân tích sản lượng, tỷ trọng & tăng trưởng |
| 31 | `/audit-logs` | `AuditLogsBoard` | Nhật ký ghi nhận mọi thao tác nhạy cảm của Admin/Ops |
| 32 | `/staff` | `StaffBoard` | Quản lý tài khoản điều hành & ma trận phân quyền RBAC |
| 33 | `/zones` | `ZonesBoard` | Quản lý ranh giới địa lý (geofence), hệ số giá khu vực |
| 34 | `/settings` | `SettingsBoard` | Trung tâm liên kết các cài đặt toàn sàn |
| 35 | `/settings/platform` | `PlatformSettingsBoard` | Cấu hình tham số nghiệp vụ (phí sàn, bán kính bắt xe) |
| 36 | `/settings/content` | `ContentCmsBoard` | Soạn thảo điều khoản sử dụng, chính sách bảo mật |
| 37 | `/settings/faqs` | `FaqsBoard` | Quản lý câu hỏi thường gặp & phản hồi mẫu |
| 38 | `/settings/auth-methods`| `AuthMethodsBoard` | Cấu hình phương thức đăng nhập & bảo mật nhân viên |

---

## 4. Quy trình triển khai cuốn chiếu (Execution Workflow)

Mỗi Phase được tiến hành tuần tự theo 4 bước kiểm định khép kín:
1. **Audit & Refactor Code**: Rà soát từng màn hình theo 6 tiêu chuẩn ở Mục 2.
2. **Backend/BFF Sync**: Kiểm tra và viết bổ sung DTO/Controller Backend nếu thiếu trường lọc hoặc phân trang.
3. **Automated Verification**: Chạy `npm run lint`, `npm test`, và `npm run build` đảm bảo 100% routes biên dịch thành công, không có cảnh báo eslint.
4. **Handoff & Review**: Báo cáo rõ ràng kết quả phase trước khi chuyển sang phase tiếp theo.
