import { describe, expect, it } from 'vitest';
import {
  OPS_ROLE_PERMISSIONS,
  roleHasPermission,
  permissionsForRole,
} from './ops-permissions.js';

describe('ops RBAC defaults (DEC-PROD-043)', () => {
  it('ADMIN has every permission SUPPORT has, plus staff.write', () => {
    for (const p of OPS_ROLE_PERMISSIONS.SUPPORT) {
      expect(roleHasPermission('ADMIN', p)).toBe(true);
    }
    expect(roleHasPermission('ADMIN', 'staff.write')).toBe(true);
    expect(roleHasPermission('SUPPORT', 'staff.write')).toBe(false);
  });

  it('FINANCE can refunds/settlements; SUPPORT cannot', () => {
    expect(roleHasPermission('FINANCE', 'refunds.write')).toBe(true);
    expect(roleHasPermission('FINANCE', 'settlements.read')).toBe(true);
    expect(roleHasPermission('SUPPORT', 'refunds.write')).toBe(false);
  });

  it('OPERATIONS can intervene and review KYC', () => {
    expect(permissionsForRole('OPERATIONS')).toEqual(
      expect.arrayContaining(['orders.intervene', 'kyc.review', 'catalog.write']),
    );
  });
});
