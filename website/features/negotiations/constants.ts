export const NEGOTIATION_TABLE_COLUMNS = [
  { id: "code", label: "Mã phiên" },
  { id: "customer", label: "Khách hàng" },
  { id: "route", label: "Tuyến đường" },
  { id: "budget", label: "Ngân sách", align: "right" as const },
  { id: "lowest", label: "Giá thấp nhất", align: "right" as const },
  { id: "bids", label: "Số báo giá", align: "right" as const },
  { id: "expires", label: "Hết hạn lúc" },
  { id: "status", label: "Trạng thái" },
  { id: "actions", label: "Thao tác" },
] as const;

export const NEGOTIATION_COLUMN_COUNT = NEGOTIATION_TABLE_COLUMNS.length;

export const NEGOTIATION_OFFER_TABLE_COLUMNS = [
  { id: "driverId", label: "Tài xế" },
  { id: "amountVnd", label: "Giá đề xuất", align: "right" as const },
  { id: "kind", label: "Loại" },
  { id: "status", label: "Trạng thái" },
] as const;

export const NEGOTIATION_OFFER_COLUMN_COUNT =
  NEGOTIATION_OFFER_TABLE_COLUMNS.length;
