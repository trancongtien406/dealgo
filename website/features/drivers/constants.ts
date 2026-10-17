export const DRIVER_TABLE_COLUMNS = [
  { id: "code", label: "Mã TX" },
  { id: "driver", label: "Tài xế" },
  { id: "area", label: "Khu vực" },
  { id: "service", label: "Dịch vụ" },
  { id: "vehicle", label: "Phương tiện" },
  { id: "plate", label: "Biển số" },
  { id: "kyc", label: "Xác minh KYC" },
  { id: "activity", label: "Hoạt động" },
  { id: "rating", label: "Đánh giá" },
  { id: "trips", label: "Chuyến/đơn", align: "right" as const },
  { id: "actions", label: "Chi tiết" },
] as const;

export const DRIVER_COLUMN_COUNT = DRIVER_TABLE_COLUMNS.length;
