export const STORE_APPROVAL_TABLE_COLUMNS = [
  { id: "store", label: "Cửa hàng" },
  { id: "owner", label: "Chủ sở hữu" },
  { id: "submittedAt", label: "Ngày gửi" },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Chọn" },
] as const;

export const STORE_APPROVAL_COLUMN_COUNT = STORE_APPROVAL_TABLE_COLUMNS.length;
