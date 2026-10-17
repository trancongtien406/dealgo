export const REFUND_TABLE_COLUMNS = [
  { id: "code", label: "Mã yêu cầu" },
  { id: "orderCode", label: "Mã đơn gốc" },
  { id: "customer", label: "Khách hàng" },
  { id: "service", label: "Dịch vụ" },
  { id: "amount", label: "Số tiền", align: "right" as const },
  { id: "reason", label: "Lý do" },
  { id: "status", label: "Trạng thái" },
  { id: "createdAt", label: "Thời gian" },
] as const;

export const REFUND_COLUMN_COUNT = REFUND_TABLE_COLUMNS.length;
