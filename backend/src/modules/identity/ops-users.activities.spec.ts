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
});
