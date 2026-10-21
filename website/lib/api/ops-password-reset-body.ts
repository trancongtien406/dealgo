/** DEC-PROD-036 — Nest OpsStaffPasswordResetDto: newPassword 12–128, reason 3–500 after trim. */
export const OPS_RESET_PASSWORD_MIN = 12;
export const OPS_RESET_PASSWORD_MAX = 128;
export const OPS_RESET_REASON_MIN = 3;
export const OPS_RESET_REASON_MAX = 500;

export type OpsPasswordResetInput = { newPassword: string; reason: string };

export type OpsPasswordResetCheck =
  | { ok: true; value: OpsPasswordResetInput }
  | { ok: false; message: string };

export function checkOpsPasswordReset(input: {
  newPassword?: unknown;
  confirmPassword?: unknown;
  reason?: unknown;
}): OpsPasswordResetCheck {
  const password = typeof input.newPassword === "string" ? input.newPassword : "";
  const reason = typeof input.reason === "string" ? input.reason.trim() : "";
  if (
    password.length < OPS_RESET_PASSWORD_MIN ||
    password.length > OPS_RESET_PASSWORD_MAX
  ) {
    return {
      ok: false,
      message: `Mật khẩu mới cần ${OPS_RESET_PASSWORD_MIN}–${OPS_RESET_PASSWORD_MAX} ký tự.`,
    };
  }
  if (input.confirmPassword !== undefined && input.confirmPassword !== password) {
    return { ok: false, message: "Mật khẩu nhập lại không khớp." };
  }
  if (reason.length < OPS_RESET_REASON_MIN || reason.length > OPS_RESET_REASON_MAX) {
    return {
      ok: false,
      message: `Lý do cần ${OPS_RESET_REASON_MIN}–${OPS_RESET_REASON_MAX} ký tự.`,
    };
  }
  return { ok: true, value: { newPassword: password, reason } };
}

/** Only a super-admin, never on self, only for rows with an Admin password login. */
export function canResetStaffPassword(
  me: { id: string; superAdmin: boolean } | null | undefined,
  person: { id?: string; roleCode?: string },
): boolean {
  return Boolean(
    me?.superAdmin && person.id && person.id !== me.id && person.roleCode === "ADMIN",
  );
}

export function opsPasswordResetErrorMessage(code: string | undefined): string | null {
  switch (code) {
    case "OPS_SUPER_ADMIN_REQUIRED":
      return "Chỉ super-admin mới đặt lại được mật khẩu.";
    case "OPS_RESET_SELF":
      return "Không thể tự đặt lại mật khẩu của chính mình.";
    case "OPS_STAFF_NOT_FOUND":
      return "Không tìm thấy nhân sự vận hành.";
    case "OPS_NO_PASSWORD_LOGIN":
      return "Tài khoản này không đăng nhập Admin bằng mật khẩu.";
    default:
      return null;
  }
}
