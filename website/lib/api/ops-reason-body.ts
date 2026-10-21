/** Nest OpsReasonDto / OpsStaffSuperAdminDto: reason 3–500 characters after trim. */
export const OPS_REASON_MIN = 3;
export const OPS_REASON_MAX = 500;

export type OpsReasonCheck =
  | { ok: true; value: { reason: string } }
  | { ok: false; message: string };

export function checkOpsReason(input: { reason?: unknown }): OpsReasonCheck {
  const reason = typeof input.reason === "string" ? input.reason.trim() : "";
  if (reason.length < OPS_REASON_MIN || reason.length > OPS_REASON_MAX) {
    return { ok: false, message: `Lý do cần ${OPS_REASON_MIN}–${OPS_REASON_MAX} ký tự.` };
  }
  return { ok: true, value: { reason } };
}

export type OpsSuperAdminCheck =
  | { ok: true; value: { superAdmin: boolean; reason: string } }
  | { ok: false; message: string };

export function checkOpsSuperAdminChange(input: {
  superAdmin?: unknown;
  reason?: unknown;
}): OpsSuperAdminCheck {
  if (typeof input.superAdmin !== "boolean") {
    return { ok: false, message: "Thiếu thao tác cấp hoặc thu hồi." };
  }
  const reason = checkOpsReason(input);
  if (!reason.ok) {
    return reason;
  }
  return { ok: true, value: { superAdmin: input.superAdmin, reason: reason.value.reason } };
}

export const OPS_STAFF_ROLES = ["ADMIN", "SUPPORT", "OPERATIONS", "FINANCE"] as const;
export type OpsStaffRoleCode = (typeof OPS_STAFF_ROLES)[number];

export type OpsStaffRoleCheck =
  | { ok: true; value: { staffRole: OpsStaffRoleCode; reason: string } }
  | { ok: false; message: string };

/** Nest OpsStaffRoleDto (DEC-PROD-043): staffRole in the fixed set + reason 3–500. */
export function checkOpsStaffRoleChange(input: {
  staffRole?: unknown;
  reason?: unknown;
}): OpsStaffRoleCheck {
  const role = typeof input.staffRole === "string" ? input.staffRole.trim().toUpperCase() : "";
  if (!(OPS_STAFF_ROLES as readonly string[]).includes(role)) {
    return { ok: false, message: "Vai trò không hợp lệ." };
  }
  const reason = checkOpsReason(input);
  if (!reason.ok) {
    return reason;
  }
  return { ok: true, value: { staffRole: role as OpsStaffRoleCode, reason: reason.value.reason } };
}

/** The button shows only for a super-admin viewing an Admin-password staff row. */
export function canChangeSuperAdmin(
  me: { id: string; superAdmin: boolean } | null | undefined,
  person: { id?: string; roleCode?: string },
): boolean {
  return Boolean(me?.superAdmin && person.id && person.roleCode === "ADMIN");
}

/** Vietnamese copy for the Nest error codes of these Admin actions (null = keep upstream text). */
export function opsAccountActionErrorMessage(code: string | undefined): string | null {
  switch (code) {
    case "OPS_SUPER_ADMIN_REQUIRED":
      return "Chỉ super-admin mới thực hiện được thao tác này.";
    case "OPS_LAST_SUPER_ADMIN":
      return "Phải còn ít nhất một super-admin. Hãy cấp quyền cho người khác trước khi thu hồi.";
    case "OPS_STAFF_NOT_FOUND":
      return "Không tìm thấy nhân sự vận hành.";
    case "OPS_STAFF_NOT_ACTIVE":
      return "Chỉ nhân sự đang hoạt động mới được cấp super-admin.";
    case "OPS_NO_PASSWORD_LOGIN":
      return "Tài khoản này không đăng nhập Admin bằng mật khẩu.";
    case "ACCOUNT_DELETION_NOT_SCHEDULED":
      return "Tài khoản không còn trong thời gian chờ xoá nên không khôi phục được.";
    case "DRIVER_FEE_NOTHING_OUTSTANDING":
      return "Tài xế không còn phí nền tảng chưa đối soát.";
    case "USER_NOT_FOUND":
      return "Không tìm thấy người dùng.";
    default:
      return null;
  }
}
