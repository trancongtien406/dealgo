import { describe, expect, it, vi } from 'vitest';
import { FoodService } from './food.service.js';

function service(order: Record<string, unknown> | null, rows: Array<{ userId: string; lat: number; lng: number }>) {
  const svc = Object.create(FoodService.prototype) as FoodService;
  const presence = { onlineNearForPush: vi.fn().mockResolvedValue(rows) };
  Object.assign(svc, {
    food: { findOrder: vi.fn().mockResolvedValue(order) },
    settings: {
      getNumber: vi.fn(async (key: string) => (key === 'DRIVER_SEARCH_RADIUS_KM' ? 5 : 15)),
    },
    presence,
    eligibility: {
      requireEligibleDriver: vi.fn(async (id: string) => {
        if (id === 'unverified') throw new Error('not eligible');
      }),
      // FOOD is motorbike-only: car / unknown-class drivers are skipped (fail closed).
      canDeliverFood: vi.fn(async (id: string) => id !== 'car' && id !== 'noclass'),
    },
  });
  return { svc, presence };
}

const ready = {
  id: 'o1',
  status: 'READY',
  assignedDriverId: null,
  customerId: 'cust',
  deliveryFareVnd: 18_000,
  storeName: 'Bún Bò',
  pickup: { lat: 10.7725, lng: 106.698, label: 'Quán' },
  dropoff: { lat: 10.78, lng: 106.7, label: '12 Lê Lợi' },
};

describe('FoodService.readyAudience', () => {
  it('lists eligible food drivers near the pickup, nearest first, skipping the customer and far ones', async () => {
    const { svc, presence } = service(ready, [
      { userId: 'mid', lat: 10.79, lng: 106.698 },
      { userId: 'near', lat: 10.773, lng: 106.698 },
      { userId: 'cust', lat: 10.7725, lng: 106.698 },
      { userId: 'unverified', lat: 10.7725, lng: 106.698 },
      { userId: 'far', lat: 10.9, lng: 106.698 },
      { userId: 'car', lat: 10.7726, lng: 106.698 },
      { userId: 'noclass', lat: 10.7726, lng: 106.698 },
    ]);
    await expect(svc.readyAudience('o1')).resolves.toEqual({
      driverIds: ['near', 'mid'],
      order: { id: 'o1', deliveryFareVnd: 18_000, storeName: 'Bún Bò', dropoffLabel: '12 Lê Lợi' },
      ttlSeconds: 900,
    });
    expect(presence.onlineNearForPush.mock.calls[0]!.slice(0, 3)).toEqual(['FOOD', ready.pickup, 5]);
  });

  it('returns null once claimed or when the order is not ready', async () => {
    await expect(service({ ...ready, assignedDriverId: 'd1' }, []).svc.readyAudience('o1')).resolves.toBeNull();
    await expect(service({ ...ready, status: 'PREPARING' }, []).svc.readyAudience('o1')).resolves.toBeNull();
    await expect(service(null, []).svc.readyAudience('o1')).resolves.toBeNull();
  });
});
