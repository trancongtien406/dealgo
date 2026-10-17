export const PROMOTION_TABLE_COLUMNS = [
  { id: "code", label: "Mã chiến dịch" },
  { id: "name", label: "Chiến dịch & nội dung" },
  { id: "service", label: "Kênh" },
  { id: "window", label: "Hiệu lực" },
  { id: "status", label: "Trạng thái" },
  { id: "used", label: "Đã tiếp cận", align: "right" as const },
  { id: "owner", label: "Người tạo" },
  { id: "action", label: "Xem" },
] as const;

export const PROMOTION_COLUMN_COUNT = PROMOTION_TABLE_COLUMNS.length;
