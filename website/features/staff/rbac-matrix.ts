/**
 * DEC-PROD-043/045 — the role → permission matrix itself is fetched from
 * `GET /v1/ops/staff/rbac-matrix` (Nest OPS_ROLE_PERMISSIONS); only display labels live here.
 */

export type RbacMatrix = {
  roles: string[];
  permissions: string[];
  grants: Record<string, string[]>;
};

export type RbacRow = { permission: string; marks: boolean[] };

const ROLE_LABELS: Record<string, string> = {
  ADMIN: "Admin",
  SUPPORT: "CSKH",
  OPERATIONS: "Vận hành",
  FINANCE: "Tài chính",
};

export function rbacRoleLabel(role: string): string {
  return ROLE_LABELS[role] ?? role;
}

/** One row per permission, one mark per role (in the server's role order). */
export function toRbacRows(matrix: RbacMatrix): RbacRow[] {
  return matrix.permissions.map((permission) => ({
    permission,
    marks: matrix.roles.map((role) => (matrix.grants[role] ?? []).includes(permission)),
  }));
}

/** Tolerant decode of the Nest payload; anything malformed becomes an empty matrix. */
export function parseRbacMatrix(raw: unknown): RbacMatrix {
  const obj = (raw && typeof raw === "object" ? raw : {}) as Record<string, unknown>;
  const strings = (value: unknown): string[] =>
    Array.isArray(value) ? value.filter((v): v is string => typeof v === "string") : [];
  const grantsRaw = (obj.grants && typeof obj.grants === "object" ? obj.grants : {}) as Record<
    string,
    unknown
  >;
  const roles = strings(obj.roles);
  return {
    roles,
    permissions: strings(obj.permissions),
    grants: Object.fromEntries(roles.map((role) => [role, strings(grantsRaw[role])])),
  };
}

export const rbacControls = [
  { label: "Super-admin", value: "Bypass mọi permission; giữ ít nhất 1", chip: true },
  { label: "Nguyên tắc quyền", value: "Ít quyền nhất theo role", chip: false },
  { label: "Gán role", value: "Chỉ super-admin; có audit", chip: false },
  { label: "Nhật ký", value: "OPS_STAFF_ROLE_ASSIGN", chip: false },
] as const;
