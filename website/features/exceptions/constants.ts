export const EXCEPTION_TABLE_COLUMNS = [
  { id: "code", label: "Mã case" },
  { id: "title", label: "Tiêu đề" },
  { id: "domain", label: "Domain" },
  { id: "entityRef", label: "Thực thể" },
  { id: "status", label: "Trạng thái" },
  { id: "priority", label: "Ưu tiên" },
  { id: "openedAt", label: "Mở lúc" },
] as const;

export const EXCEPTION_COLUMN_COUNT = EXCEPTION_TABLE_COLUMNS.length;
