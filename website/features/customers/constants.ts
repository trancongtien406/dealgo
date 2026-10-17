export const CUSTOMER_ACTIVITY_TABS = [
  "Hoạt động gần đây",
  "Chuyến xe",
  "Đơn ăn",
  "Giao hàng",
  "Thanh toán",
  "Ghi chú",
] as const;

export const CUSTOMER_STATUS_TABS = [
  { label: "Tất cả", value: "ALL" },
  { label: "Hoạt động", value: "ACTIVE" },
  { label: "Tạm khóa", value: "SUSPENDED" },
  { label: "Chờ xác minh", value: "PENDING" },
] as const;

export const CUSTOMER_TABLE_COLUMNS = [
  { id: "code", label: "Mã KH" },
  { id: "customer", label: "Khách hàng" },
  { id: "phone", label: "Số điện thoại" },
  { id: "area", label: "Khu vực" },
  { id: "rides", label: "Chuyến xe", align: "right" as const },
  { id: "food", label: "Đơn đồ ăn", align: "right" as const },
  { id: "delivery", label: "Giao hàng", align: "right" as const },
  { id: "spend", label: "Chi tiêu", align: "right" as const },
  { id: "status", label: "Trạng thái" },
  { id: "time", label: "Hoạt động cuối" },
  { id: "actions", label: "Hành động", align: "center" as const },
] as const;

export const CUSTOMER_COLUMN_COUNT = CUSTOMER_TABLE_COLUMNS.length;

export const CUSTOMER_ACTIVITY_TABLE_COLUMNS = [
  { id: "time", label: "Thời gian" },
  { id: "code", label: "Mã tham chiếu" },
  { id: "kind", label: "Loại hoạt động" },
  { id: "summary", label: "Nội dung" },
  { id: "value", label: "Giá trị hiển thị", align: "right" as const },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Chi tiết" },
] as const;

export const CUSTOMER_ACTIVITY_COLUMN_COUNT =
  CUSTOMER_ACTIVITY_TABLE_COLUMNS.length;
