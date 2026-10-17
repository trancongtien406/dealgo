export const CATALOG_SORT_OPTIONS = [
  { value: "STORES", label: "Nhiều cửa hàng nhất" },
  { value: "PRODUCTS", label: "Nhiều món nhất" },
  { value: "NAME", label: "Tên A → Z" },
];

export const CATALOG_STATUS_OPTIONS = [
  { value: "ACTIVE", label: "Đang hiển thị" },
  { value: "HIDDEN", label: "Đang ẩn" },
];

export const CATALOG_TABLE_COLUMNS = [
  { id: "index", label: "#" },
  { id: "code", label: "Mã" },
  { id: "name", label: "Tên & mã đường dẫn" },
  { id: "itemCount", label: "Món", align: "right" as const },
  { id: "storeCount", label: "Cửa hàng", align: "right" as const },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Thao tác" },
] as const;

export const CATALOG_COLUMN_COUNT = CATALOG_TABLE_COLUMNS.length;
