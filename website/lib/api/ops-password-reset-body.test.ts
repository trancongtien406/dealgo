import { describe, expect, it } from "vitest";
import {
  canResetStaffPassword,
  checkOpsPasswordReset,
  opsPasswordResetErrorMessage,
} from "./ops-password-reset-body";

describe("checkOpsPasswordReset", () => {
  it("accepts a long password and trims the reason", () => {
    expect(
      checkOpsPasswordReset({
        newPassword: "a-long-password-1",
        confirmPassword: "a-long-password-1",
        reason: "  forgot  ",
      }),
    ).toEqual({ ok: true, value: { newPassword: "a-long-password-1", reason: "forgot" } });
  });

  it("rejects short passwords, mismatches and short reasons", () => {
    expect(checkOpsPasswordReset({ newPassword: "short", reason: "forgot" }).ok).toBe(false);
    expect(
      checkOpsPasswordReset({
        newPassword: "a-long-password-1",
        confirmPassword: "a-long-password-2",
        reason: "forgot",
      }),
    ).toEqual({ ok: false, message: "Mật khẩu nhập lại không khớp." });
    expect(checkOpsPasswordReset({ newPassword: "a-long-password-1", reason: " x " }).ok).toBe(false);
    expect(checkOpsPasswordReset({ newPassword: 42, reason: "forgot" }).ok).toBe(false);
  });
});

describe("canResetStaffPassword", () => {
  const me = { id: "me", superAdmin: true };
  it("allows a super-admin on another ADMIN row only", () => {
    expect(canResetStaffPassword(me, { id: "x", roleCode: "ADMIN" })).toBe(true);
    expect(canResetStaffPassword(me, { id: "me", roleCode: "ADMIN" })).toBe(false);
    expect(canResetStaffPassword(me, { id: "x", roleCode: "OPS" })).toBe(false);
    expect(canResetStaffPassword({ id: "me", superAdmin: false }, { id: "x", roleCode: "ADMIN" })).toBe(false);
    expect(canResetStaffPassword(null, { id: "x", roleCode: "ADMIN" })).toBe(false);
  });
});

describe("opsPasswordResetErrorMessage", () => {
  it("maps server codes to Vietnamese", () => {
    expect(opsPasswordResetErrorMessage("OPS_RESET_SELF")).toContain("chính mình");
    expect(opsPasswordResetErrorMessage("OTHER")).toBeNull();
  });
});
