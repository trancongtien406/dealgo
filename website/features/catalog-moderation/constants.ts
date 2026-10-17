export const CATALOG_MODERATION_TABLE_COLUMNS = [
  { id: "code", label: "Mã" },
  { id: "product", label: "Sản phẩm" },
  { id: "store", label: "Cửa hàng" },
  { id: "price", label: "Giá bán" },
  { id: "submittedAt", label: "Gửi duyệt" },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Thao tác" },
] as const;

export const CATALOG_MODERATION_COLUMN_COUNT =
  CATALOG_MODERATION_TABLE_COLUMNS.length;
