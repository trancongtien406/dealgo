export const REPORTS_TIME_PRESETS = [
  { value: "today", label: "Hôm nay" },
  { value: "7d", label: "7 ngày qua" },
  { value: "30d", label: "30 ngày qua" },
  { value: "this_month", label: "Tháng này" },
] as const;

export const REPORTS_EXPORT_HEADERS = [
  "Dịch vụ",
  "Giá trị",
  "Tỷ trọng",
] as const;
