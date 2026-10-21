import { describe, expect, it } from "vitest";
import { parseRbacMatrix, rbacRoleLabel, toRbacRows } from "./rbac-matrix";

describe("RBAC matrix from Nest (DEC-PROD-045)", () => {
  it("builds one row per permission with a mark per server role", () => {
    const matrix = parseRbacMatrix({
      roles: ["ADMIN", "SUPPORT"],
      permissions: ["customers.read", "customers.write", "settings.write"],
      grants: {
        ADMIN: ["customers.read", "customers.write", "settings.write"],
        SUPPORT: ["customers.read", "customers.write"],
      },
    });
    expect(toRbacRows(matrix)).toEqual([
      { permission: "customers.read", marks: [true, true] },
      { permission: "customers.write", marks: [true, true] },
      { permission: "settings.write", marks: [true, false] },
    ]);
  });

  it("tolerates malformed payloads and unknown roles", () => {
    expect(parseRbacMatrix(null)).toEqual({ roles: [], permissions: [], grants: {} });
    const odd = parseRbacMatrix({ roles: ["AUDITOR", 3], permissions: ["x"], grants: {} });
    expect(toRbacRows(odd)).toEqual([{ permission: "x", marks: [false] }]);
    expect(rbacRoleLabel("AUDITOR")).toBe("AUDITOR");
    expect(rbacRoleLabel("SUPPORT")).toBe("CSKH");
  });
});
