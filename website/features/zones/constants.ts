export const ZONE_SERVICE_FILTER_OPTIONS = [
  { value: "RIDE", label: "Chuyến xe" },
  { value: "FOOD", label: "Đồ ăn" },
  { value: "PLATFORM", label: "Toàn sàn" },
];

export const ZONE_STATUS_FILTER_OPTIONS = [
  { value: "ACTIVE", label: "Đang áp dụng" },
  { value: "DRAFT", label: "Bản nháp" },
];

export const ZONE_STATUS_TABS = [
  { value: "ACTIVE", label: "Đang phục vụ" },
  { value: "ALL", label: "Tất cả vùng" },
  { value: "PLANNED", label: "Kế hoạch" },
] as const;

export const ZONE_RULE_TABLE_COLUMNS = [
  { id: "code", label: "Mã cấu hình" },
  { id: "name", label: "Tên" },
  { id: "service", label: "Dịch vụ" },
  { id: "zone", label: "Phạm vi" },
  { id: "displayValue", label: "Giá trị", align: "right" as const },
  { id: "updatedAt", label: "Cập nhật" },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Thao tác" },
] as const;

export const ZONE_RULE_COLUMN_COUNT = ZONE_RULE_TABLE_COLUMNS.length;

export { DEFAULT_CENTER } from "@/lib/service-region-labels";
