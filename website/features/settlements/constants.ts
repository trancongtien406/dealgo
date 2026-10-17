/** Minimal settlement workflow labels for the ops board sidebar. */
export const settlementSteps = [
  { title: "Thu thập giao dịch", done: true },
  { title: "Đối soát số liệu", done: true },
  { title: "Duyệt chênh lệch & khóa kỳ", done: false },
  { title: "Lập lệnh chi trả", done: false },
] as const;

export const SETTLEMENT_LINE_TABLE_COLUMNS = [
  { id: "kind", label: "Loại" },
  { id: "ref", label: "Mã tham chiếu" },
  { id: "at", label: "Thời gian" },
  { id: "revenue", label: "Doanh thu" },
  { id: "fee", label: "Phí" },
  { id: "provisional", label: "Tạm tính" },
  { id: "status", label: "Trạng thái" },
] as const;

export const SETTLEMENT_LINE_COLUMN_COUNT =
  SETTLEMENT_LINE_TABLE_COLUMNS.length;
