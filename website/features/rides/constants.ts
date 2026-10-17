export const RIDE_TABLE_COLUMNS = [
  { id: "select", label: "Chọn", isSelection: true },
  { id: "code", label: "Mã chuyến" },
  { id: "customer", label: "Khách hàng" },
  { id: "driver", label: "Tài xế" },
  { id: "pickup", label: "Điểm đón" },
  { id: "dropoff", label: "Điểm đến" },
  { id: "seats", label: "Loại xe" },
  { id: "price", label: "Giá", align: "right" as const },
  { id: "status", label: "Trạng thái" },
  { id: "time", label: "Thời gian" },
  { id: "actions", label: "Hành động" },
] as const;

export const RIDE_COLUMN_COUNT = RIDE_TABLE_COLUMNS.length;
