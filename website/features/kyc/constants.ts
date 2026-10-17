export const KYC_QUEUE_TABLE_COLUMNS = [
  { id: "driver", label: "Tài xế" },
  { id: "area", label: "Khu vực" },
  { id: "vehicle", label: "Phương tiện" },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Thao tác" },
] as const;

export const KYC_QUEUE_COLUMN_COUNT = KYC_QUEUE_TABLE_COLUMNS.length;
