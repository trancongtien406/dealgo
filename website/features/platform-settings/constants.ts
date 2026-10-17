export const PLATFORM_SETTING_CATEGORIES = [
  { id: "ALL", label: "Tất cả" },
  { id: "FARE", label: "Cước & Trả giá" },
  { id: "DISPATCH", label: "Điều phối & SLA" },
  { id: "ZONE_PAYMENT", label: "Vùng & Thanh toán" },
] as const;

export const PLATFORM_SETTING_SOURCES = [
  { id: "ALL", label: "Tất cả" },
  { id: "db", label: "DB override" },
  { id: "env", label: "Mặc định env" },
] as const;
