export const AUDIT_LOG_RESULT_OPTIONS = [
  { value: "ALL", label: "Tất cả kết quả" },
  { value: "SUCCESS", label: "Thành công" },
  { value: "PENDING_APPROVAL", label: "Chờ phê duyệt" },
  { value: "LOGGED", label: "Đã ghi nhận log" },
  { value: "REJECTED", label: "Từ chối" },
];

export const AUDIT_LOG_ENTITY_OPTIONS = [
  { value: "ALL", label: "Tất cả phân hệ" },
  { value: "PLATFORM_SETTING", label: "Cài đặt & Tham số" },
  { value: "DISPUTE", label: "Khiếu nại & Tranh chấp" },
  { value: "FOOD_ORDER", label: "Đơn đồ ăn" },
  { value: "RIDE", label: "Chuyến xe" },
  { value: "AUTH_METHOD_POLICY", label: "Phương thức xác thực" },
  { value: "OPS_FAQ", label: "Chính sách OPEN" },
];

export const AUDIT_LOG_TABLE_COLUMNS = [
  { id: "code", label: "Mã sự kiện" },
  { id: "time", label: "Thời gian" },
  { id: "actor", label: "Tác nhân" },
  { id: "action", label: "Hành động" },
  { id: "target", label: "Đối tượng" },
  { id: "reason", label: "Lý do & Căn cứ" },
  { id: "result", label: "Kết quả", align: "right" as const },
] as const;

export const AUDIT_LOG_COLUMN_COUNT = AUDIT_LOG_TABLE_COLUMNS.length;
