export const PROMOTION_TABLE_COLUMNS = [
  { id: "code", label: "Mã voucher" },
  { id: "name", label: "Chiến dịch & điều kiện" },
  { id: "service", label: "Dịch vụ" },
  { id: "window", label: "Hiệu lực" },
  { id: "status", label: "Trạng thái" },
  { id: "used", label: "Đã dùng / Giới hạn", align: "right" as const },
  { id: "budget", label: "Ngân sách", align: "right" as const },
  { id: "owner", label: "Tài trợ" },
  { id: "action", label: "Xem" },
] as const;

export const PROMOTION_COLUMN_COUNT = PROMOTION_TABLE_COLUMNS.length;
