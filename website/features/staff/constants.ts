export const STAFF_MODULE_TABS = [
  "Danh sách nhân sự",
  "Vai trò & quyền",
  "Phạm vi truy cập",
  "Lịch sử thay đổi",
] as const;

export const STAFF_TABLE_COLUMNS = [
  { id: "select", label: "Chọn", isSelection: true },
  { id: "staff", label: "Nhân sự" },
  { id: "role", label: "Vai trò" },
  { id: "scope", label: "Phạm vi" },
  { id: "status", label: "Trạng thái" },
  { id: "lastActive", label: "Hoạt động cuối" },
  { id: "actions", label: "Thao tác" },
] as const;

export const STAFF_COLUMN_COUNT = STAFF_TABLE_COLUMNS.length;

export const STAFF_PENDING_GRANTS_TABLE_COLUMNS = [
  { id: "user", label: "Người dùng" },
  { id: "role", label: "Vai trò yêu cầu" },
  { id: "contact", label: "Liên hệ" },
  { id: "createdAt", label: "Ngày tạo" },
  { id: "actions", label: "Thao tác" },
] as const;

export const STAFF_PENDING_GRANTS_COLUMN_COUNT =
  STAFF_PENDING_GRANTS_TABLE_COLUMNS.length;

export const STAFF_AUDIT_TABLE_COLUMNS = [
  { id: "time", label: "Thời gian" },
  { id: "actor", label: "Người thực hiện" },
  { id: "action", label: "Hành động" },
  { id: "target", label: "Đối tượng" },
  { id: "result", label: "Kết quả" },
] as const;

export const STAFF_AUDIT_COLUMN_COUNT = STAFF_AUDIT_TABLE_COLUMNS.length;
