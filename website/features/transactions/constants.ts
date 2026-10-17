export const TRANSACTION_TABLE_COLUMNS = [
  { id: "code", label: "Mã giao dịch" },
  { id: "time", label: "Thời gian" },
  { id: "service", label: "Dịch vụ" },
  { id: "orderCode", label: "Mã đơn / chuyến" },
  { id: "customer", label: "Khách hàng" },
  { id: "method", label: "Phương thức" },
  { id: "amount", label: "Số tiền", align: "right" as const },
  { id: "status", label: "Trạng thái" },
  { id: "area", label: "Khu vực" },
  { id: "actions", label: "Xem" },
] as const;

export const TRANSACTION_COLUMN_COUNT = TRANSACTION_TABLE_COLUMNS.length;
