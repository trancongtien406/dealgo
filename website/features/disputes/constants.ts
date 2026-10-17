export const DISPUTE_TABLE_COLUMNS = [
  { id: "code", label: "Mã phiếu" },
  { id: "createdAt", label: "Ngày tạo" },
  { id: "type", label: "Loại khiếu nại" },
  { id: "relatedCode", label: "Liên quan" },
  { id: "reporter", label: "Người gửi" },
  { id: "summary", label: "Nội dung tóm tắt" },
  { id: "status", label: "Trạng thái" },
  { id: "priority", label: "Ưu tiên" },
  { id: "assignee", label: "Người xử lý" },
  { id: "action", label: "Xem" },
] as const;

export const DISPUTE_COLUMN_COUNT = DISPUTE_TABLE_COLUMNS.length;
