export const FOOD_ORDER_TABLE_COLUMNS = [
  { id: "code", label: "Mã đơn" },
  { id: "customer", label: "Khách hàng" },
  { id: "store", label: "Cửa hàng" },
  { id: "items", label: "Món đã đặt" },
  { id: "total", label: "Tổng tiền", align: "right" as const },
  { id: "driver", label: "Tài xế giao" },
  { id: "status", label: "Trạng thái" },
  { id: "time", label: "Thời gian" },
  { id: "actions", label: "Thao tác" },
] as const;

export const FOOD_ORDER_COLUMN_COUNT = FOOD_ORDER_TABLE_COLUMNS.length;
