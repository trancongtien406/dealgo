export const DELIVERY_STATUS_TABS = [
  { label: "Tất cả", value: "" },
  { label: "Chờ tài xế", value: "PENDING" },
  { label: "Đã lấy hàng", value: "PICKED_UP" },
  { label: "Đang giao", value: "DELIVERING" },
  { label: "Hoàn thành", value: "DONE" },
  { label: "Hủy / lỗi", value: "CANCELLED" },
] as const;

export const DELIVERY_TABLE_COLUMNS = [
  { id: "code", label: "Mã đơn" },
  { id: "sender", label: "Người gửi" },
  { id: "route", label: "Tuyến đường" },
  { id: "cargo", label: "Loại hàng" },
  { id: "fee", label: "Phí giao", align: "right" as const },
  { id: "driver", label: "Tài xế" },
  { id: "status", label: "Trạng thái" },
  { id: "time", label: "Tạo lúc" },
  { id: "actions", label: "Thao tác", align: "center" as const },
] as const;

export const DELIVERY_COLUMN_COUNT = DELIVERY_TABLE_COLUMNS.length;
