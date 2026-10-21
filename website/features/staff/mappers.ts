import type { StatusTone } from "@/lib/admin-format";
import type { StaffStatus } from "@/features/staff/types";

const labels: Record<StaffStatus, string> = {
  ACTIVE: "Hoạt động",
  INVITED: "Đã mời",
  SUSPENDED: "Tạm khóa",
};
const tones: Record<StaffStatus, StatusTone> = {
  ACTIVE: "success",
  INVITED: "food",
  SUSPENDED: "danger",
};

const roleLabels: Record<string, string> = {
  ADMIN: "Admin",
  OPS: "Ops (chưa gán)",
  SUPPORT: "CSKH",
  OPERATIONS: "Vận hành",
  FINANCE: "Tài chính",
  CUSTOMER: "Khách hàng",
  DRIVER: "Tài xế",
  MERCHANT: "Cửa hàng",
};

const scopeLabels: Record<string, string> = {
  NATIONAL: "Toàn quốc",
  CITY: "Theo thành phố",
  ZONE: "Theo vùng",
};

export function staffStatusLabel(status: StaffStatus) {
  return labels[status];
}
export function staffStatusTone(status: StaffStatus) {
  return tones[status];
}

export function staffRoleLabel(role: string) {
  const key = role.trim().toUpperCase();
  return roleLabels[key] ?? role;
}

export function staffScopeLabel(scope: string) {
  const key = scope.trim().toUpperCase();
  return scopeLabels[key] ?? scope;
}

export function isStaffAdminRole(role: string) {
  const key = role.trim().toUpperCase();
  return key === "ADMIN" || role.includes("Quản trị");
}
