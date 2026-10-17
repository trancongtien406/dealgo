export const STORE_TABLE_COLUMNS = [
  { id: "code", label: "Mã cửa hàng" },
  { id: "name", label: "Tên cửa hàng" },
  { id: "category", label: "Danh mục" },
  { id: "owner", label: "Đại diện" },
  { id: "area", label: "Khu vực" },
  { id: "menuCount", label: "Món catalog", align: "right" as const },
  { id: "rating", label: "Đánh giá" },
  { id: "status", label: "Trạng thái bán" },
  { id: "kyb", label: "Hồ sơ KYB" },
  { id: "actions", label: "Chi tiết" },
] as const;

export const STORE_COLUMN_COUNT = STORE_TABLE_COLUMNS.length;
