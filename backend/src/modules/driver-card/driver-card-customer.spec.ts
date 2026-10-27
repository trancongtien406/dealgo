import { describe, expect, it } from 'vitest';
import { DriverCardService } from './driver-card.service.js';

/** The assigned driver sees who they are picking up; nobody else does. */
function service() {
  const users: Record<string, { displayName: string; avatarUrl: string | null }> = {
    c1: { displayName: '  Nguyễn Thị An  ', avatarUrl: null },
  };
  const identity = { findUserById: async (id: string) => users[id] ?? null };
  const rides = {
    ratingSubject: async (id: string) =>
      id === 'r1' ? { customerId: 'c1', driverId: 'd1' } : id === 'r2' ? { customerId: 'c1', driverId: null } : null,
  };
  const food = {
    ratingSubject: async (id: string) => (id === 'o1' ? { customerId: 'c1', driverId: 'd1' } : null),
  };
  return new DriverCardService(identity as never, {} as never, {} as never, rides as never, food as never);
}

describe('customer card for the assigned driver', () => {
  it('returns the customer name on a ride and a food order', async () => {
    await expect(service().rideCustomer('d1', 'r1')).resolves.toEqual({
      customerId: 'c1',
      displayName: 'Nguyễn Thị An',
      avatarUrl: null,
    });
    await expect(service().foodOrderCustomer('d1', 'o1')).resolves.toMatchObject({ displayName: 'Nguyễn Thị An' });
  });

  it('hides it from other drivers and before assignment', async () => {
    await expect(service().rideCustomer('d2', 'r1')).rejects.toMatchObject({ status: 404 });
    await expect(service().rideCustomer('d1', 'r2')).rejects.toMatchObject({ status: 404 });
    await expect(service().foodOrderCustomer('d2', 'o1')).rejects.toMatchObject({ status: 404 });
  });
});
