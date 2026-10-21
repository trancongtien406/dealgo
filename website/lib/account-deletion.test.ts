import { describe, expect, it } from "vitest";
import {
  accountDeletionLabel,
  accountDeletionSummary,
  canRestoreAccount,
  parseAccountDeletion,
} from "@/lib/account-deletion";
import {
  canChangeSuperAdmin,
  checkOpsReason,
  checkOpsSuperAdminChange,
  opsAccountActionErrorMessage,
} from "@/lib/api/ops-reason-body";

describe("account deletion helpers (S027)", () => {
  it("parses the Nest view and rejects junk", () => {
    expect(parseAccountDeletion(null)).toBeNull();
    expect(parseAccountDeletion({ status: "ACTIVE", deletedAt: "x" })).toBeNull();
    const scheduled = parseAccountDeletion({
      status: "SCHEDULED",
      deletedAt: "2026-10-19T03:00:00.000Z",
      purgeAfter: "2026-10-26T03:00:00.000Z",
      purgedAt: null,
    });
    expect(scheduled).toEqual({
      status: "SCHEDULED",
      deletedAt: "2026-10-19T03:00:00.000Z",
      purgeAfter: "2026-10-26T03:00:00.000Z",
      purgedAt: null,
    });
    expect(accountDeletionLabel(scheduled!)).toBe("Đang chờ xoá");
    expect(accountDeletionSummary(scheduled!)).toContain("Có thể khôi phục");
    expect(canRestoreAccount(scheduled)).toBe(true);
    const purged = { ...scheduled!, status: "PURGED" as const, purgedAt: "2026-10-26T04:00:00.000Z" };
    expect(accountDeletionLabel(purged)).toBe("Đã xoá tài khoản");
    expect(accountDeletionSummary(purged)).toContain("ẩn danh");
    expect(canRestoreAccount(purged)).toBe(false);
  });

  it("validates reasons and the super-admin body", () => {
    expect(checkOpsReason({ reason: "  ab " }).ok).toBe(false);
    expect(checkOpsReason({ reason: " Khách gọi hotline " })).toEqual({
      ok: true,
      value: { reason: "Khách gọi hotline" },
    });
    expect(checkOpsSuperAdminChange({ reason: "Phân quyền" }).ok).toBe(false);
    expect(checkOpsSuperAdminChange({ superAdmin: false, reason: "Phân quyền" })).toEqual({
      ok: true,
      value: { superAdmin: false, reason: "Phân quyền" },
    });
  });

  it("shows the super-admin action only to super-admins on Admin rows", () => {
    const me = { id: "a", superAdmin: true };
    expect(canChangeSuperAdmin(me, { id: "b", roleCode: "ADMIN" })).toBe(true);
    expect(canChangeSuperAdmin(me, { id: "a", roleCode: "ADMIN" })).toBe(true);
    expect(canChangeSuperAdmin(me, { id: "b", roleCode: "OPS" })).toBe(false);
    expect(canChangeSuperAdmin({ id: "a", superAdmin: false }, { id: "b", roleCode: "ADMIN" })).toBe(false);
    expect(opsAccountActionErrorMessage("OPS_LAST_SUPER_ADMIN")).toContain("ít nhất một");
    expect(opsAccountActionErrorMessage("SOMETHING")).toBeNull();
  });
});
