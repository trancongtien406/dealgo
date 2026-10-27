/**
 * DEC-PROD-043 — Ops RBAC: coarse staff roles map to permission strings.
 * `superAdmin` on OpsCredential bypasses every check.
 */
export const OPS_STAFF_ROLES = ['ADMIN', 'SUPPORT', 'OPERATIONS', 'FINANCE'] as const;
export type OpsStaffRoleName = (typeof OPS_STAFF_ROLES)[number];

export const OPS_PERMISSIONS = [
  'orders.read',
  'orders.intervene',
  'rides.read',
  'rides.intervene',
  'tickets.read',
  'tickets.write',
  'disputes.read',
  'disputes.write',
  'kyc.review',
  'kyb.review',
  'catalog.write',
  'customers.read',
  /** DEC-PROD-045: account changes made on a customer's behalf (e.g. restore during deletion grace). */
  'customers.write',
  'drivers.read',
  'drivers.write',
  'refunds.read',
  'refunds.write',
  'settlements.read',
  'settlements.write',
  'reports.read',
  'transactions.read',
  'promotions.write',
  'settings.write',
  'staff.read',
  'staff.write',
  'zones.write',
  'notifications.write',
  /** DEC-PROD-056: read decrypted ride/order chat for a stated reason (audited). */
  'chat.review',
  /** DEC-PROD-055: edit and publish public pages (privacy, terms, support…). */
  'content.write',
] as const;

export type OpsPermission = (typeof OPS_PERMISSIONS)[number];

const ALL: OpsPermission[] = [...OPS_PERMISSIONS];

/** Sensible defaults (matrix on Staff → Vai trò & quyền). */
export const OPS_ROLE_PERMISSIONS: Record<OpsStaffRoleName, readonly OpsPermission[]> = {
  ADMIN: ALL,
  SUPPORT: [
    'orders.read',
    'rides.read',
    'tickets.read',
    'tickets.write',
    'disputes.read',
    'disputes.write',
    'customers.read',
    'customers.write',
    'drivers.read',
    'staff.read',
    'chat.review',
  ],

  OPERATIONS: [
    'orders.read',
    'orders.intervene',
    'rides.read',
    'rides.intervene',
    'tickets.read',
    'kyc.review',
    'kyb.review',
    'catalog.write',
    'customers.read',
    'drivers.read',
    'drivers.write',
    'zones.write',
    'notifications.write',
    'promotions.write',
    'staff.read',
  ],
  FINANCE: [
    'orders.read',
    'rides.read',
    'refunds.read',
    'refunds.write',
    'settlements.read',
    'settlements.write',
    'reports.read',
    'transactions.read',
    'staff.read',
  ],
};

export function permissionsForRole(role: OpsStaffRoleName): readonly OpsPermission[] {
  return OPS_ROLE_PERMISSIONS[role] ?? OPS_ROLE_PERMISSIONS.SUPPORT;
}

export function roleHasPermission(role: OpsStaffRoleName, permission: OpsPermission): boolean {
  return permissionsForRole(role).includes(permission);
}

export function isOpsStaffRole(value: string): value is OpsStaffRoleName {
  return (OPS_STAFF_ROLES as readonly string[]).includes(value);
}
