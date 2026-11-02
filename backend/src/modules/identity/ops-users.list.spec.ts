import { beforeEach, describe, expect, it } from 'vitest';
import { MemoryDriverPresenceRepository } from './driver-presence.repository.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { OpsUsersService } from './ops-users.service.js';

describe('OpsUsersService.listStaff filters', () => {
  let service: OpsUsersService;
  let identity: MemoryIdentityRepository;
  let activeOpsId: string;
  let suspendedOpsId: string;
  let adminId: string;

  beforeEach(async () => {
    identity = new MemoryIdentityRepository();

    const activeOps = await identity.createUser({
      displayName: 'Active Ops',
      phone: null,
      email: 'active-ops@dealgo.test',
    });
    activeOpsId = activeOps.id;
    await identity.insertGrant(activeOpsId, 'OPS', 'ACTIVE');

    const suspendedOps = await identity.createUser({
      displayName: 'Suspended Ops',
      phone: null,
      email: 'suspended-ops@dealgo.test',
    });
    suspendedOpsId = suspendedOps.id;
    await identity.insertGrant(suspendedOpsId, 'OPS', 'SUSPENDED');

    const admin = await identity.createUser({
      displayName: 'Admin Staff',
      phone: null,
      email: 'admin-staff@dealgo.test',
    });
    adminId = admin.id;
    await identity.insertGrant(adminId, 'OPS', 'ACTIVE');
    await identity.saveOpsCredential(adminId, 'hash');

    service = new OpsUsersService(
      identity,
      new MemoryDriverPresenceRepository(),
      { db: () => null } as never,
    );
  });

  it('filters staff by ACTIVE and excludes SUSPENDED users', async () => {
    const page = await service.listStaff(1, 50, { status: 'ACTIVE' });

    const ids = page.items.map((item) => item.id);
    expect(ids).toContain(activeOpsId);
    expect(ids).toContain(adminId);
    expect(ids).not.toContain(suspendedOpsId);
    expect(
      page.items.every((item) =>
        item.grants.some((g) => g.role === 'OPS' && g.status === 'ACTIVE'),
      ),
    ).toBe(true);
  });

  it('filters ADMIN to credential holders and OPS to credential-absent operators', async () => {
    const admins = await service.listStaff(1, 50, { role: 'ADMIN' });
    expect(admins.items.map((item) => item.id)).toEqual([adminId]);
    expect(admins.items.every((item) => item.role === 'ADMIN')).toBe(true);

    const opsOnly = await service.listStaff(1, 50, { role: 'OPS' });
    const opsIds = opsOnly.items.map((item) => item.id);
    expect(opsIds).toContain(activeOpsId);
    expect(opsIds).toContain(suspendedOpsId);
    expect(opsIds).not.toContain(adminId);
    expect(opsOnly.items.every((item) => item.role === 'OPS')).toBe(true);

    const supportAlias = await service.listStaff(1, 50, { role: 'SUPPORT' });
    expect(supportAlias.items.map((item) => item.id).sort()).toEqual(
      opsIds.sort(),
    );
  });

  it('lists customers with contactPhone fallback and without OPS role/scope leak', async () => {
    const customer = await identity.createUser({
      displayName: 'Khách Hàng A',
      phone: null,
      contactPhone: '+84912345678',
      email: 'khachhang@dealgo.test',
    });
    await identity.insertGrant(customer.id, 'CUSTOMER', 'ACTIVE');

    const result = await service.listCustomers(1, 10);
    const item = result.items.find((c) => c.id === customer.id);
    expect(item).toBeDefined();
    expect(item?.phone).toBe('+84912345678');
    expect(item?.phoneMasked).toBe('+8491 *** 678');
    expect(item?.role).toBeUndefined();
    expect(item?.scope).toBeUndefined();
  });
});
