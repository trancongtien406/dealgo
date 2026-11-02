import { beforeEach, describe, expect, it } from 'vitest';
import { MemoryDriverPresenceRepository } from './driver-presence.repository.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { OpsUsersService } from './ops-users.service.js';

describe('OpsUsersService.getCustomerActivities', () => {
  let service: OpsUsersService;
  let identity: MemoryIdentityRepository;
  let customerId: string;

  beforeEach(async () => {
    identity = new MemoryIdentityRepository();
    const user = await identity.createUser({
      displayName: 'Test Customer',
      phone: '+84900000001',
      email: null,
    });
    customerId = user.id;
    await identity.insertGrant(customerId, 'CUSTOMER', 'ACTIVE');

    service = new OpsUsersService(
      identity,
      new MemoryDriverPresenceRepository(),
      { db: () => null } as never,
    );
  });

  it('returns empty activities when Prisma is unavailable (no fixture rows)', async () => {
    const page = await service.getCustomerActivities(customerId, {
      tab: 'ALL',
      page: 1,
      limit: 10,
    });
    expect(page.items).toEqual([]);
    expect(page.total).toBe(0);
  });

  it('keeps delivery/note tabs empty without inventing fixtures', async () => {
    const delivery = await service.getCustomerActivities(customerId, {
      tab: 'DELIVERY',
    });
    expect(delivery.items).toEqual([]);
    const notes = await service.getCustomerActivities(customerId, { tab: 'NOTE' });
    expect(notes.items).toEqual([]);
  });

  it('getDriver returns presence and safe fallback properties without crashing when DB is null', async () => {
    const user = await identity.createUser({
      displayName: 'Test Driver',
      phone: '+84900000002',
      email: 'driver@dealgo.vn',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');

    const detail = await service.getDriver(user.id);
    expect(detail.id).toBe(user.id);
    expect(detail.displayName).toBe('Test Driver');
    expect(detail.phone).toBe('+84900000002');
    expect(detail.presence).toBeNull();
    expect(detail.kycDetail).toBeNull();
  });

  it('getDriverActivities returns empty list safely when Prisma is null', async () => {
    const user = await identity.createUser({
      displayName: 'Test Driver 2',
      phone: '+84900000003',
      email: 'driver2@dealgo.vn',
    });
    await identity.insertGrant(user.id, 'DRIVER', 'ACTIVE');

    const result = await service.getDriverActivities(user.id, {
      tab: 'ALL',
      page: 1,
      limit: 10,
    });
    expect(result.items).toEqual([]);
    expect(result.total).toBe(0);
    expect(result.tab).toBe('ALL');
  });
});
