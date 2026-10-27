import { describe, expect, it, vi } from 'vitest';
import { FoodService } from './food.service.js';

const pickup = { lat: 16.0544, lng: 108.2022, label: 'Quán' };
const dropoff = { lat: 16.06, lng: 108.21, label: 'Nhà' };

function service(routeImpl: () => Promise<unknown>, rows: Array<Record<string, unknown>>) {
  const svc = Object.create(FoodService.prototype) as FoodService;
  Object.assign(svc, {
    eligibility: { requireEligibleDriver: vi.fn().mockResolvedValue(undefined) },
    presence: {
      isDispatchEligible: vi.fn().mockResolvedValue(true),
      dispatchOrigin: vi.fn().mockResolvedValue(null),
    },
    earnings: { assertUnderDebtLimit: vi.fn().mockResolvedValue(undefined) },
    config: { get: () => 20 },
    settings: {
      getNumber: vi.fn().mockResolvedValue(5),
      getBoolean: vi.fn().mockResolvedValue(false),
    },
    food: { listReady: vi.fn().mockResolvedValue(rows) },
    routing: { route: vi.fn(routeImpl), provider: () => 'mapbox' },
  });
  return svc;
}

const row = (id: string, withPickup: boolean) => ({
  id,
  storeId: 's1',
  status: 'READY',
  storeName: 'Quán',
  storeAddress: null,
  deliveryFareVnd: 15_000,
  subtotalVnd: 50_000,
  totalVnd: 65_000,
  dropoff,
  store: withPickup ? pickup : null,
  pickup: withPickup ? pickup : null,
  lineCount: 1,
});

const actor = { userId: 'driver-1' } as never;

describe('FoodService.listReady road route (DEC-PROD-045)', () => {
  it('attaches road coords pickup→dropoff from RoutingService', async () => {
    const svc = service(
      async () => ({
        available: true,
        provider: 'mapbox',
        routes: [
          {
            distanceM: 1200,
            durationSec: 240,
            coords: [
              [pickup.lat, pickup.lng],
              [16.057, 108.205],
              [dropoff.lat, dropoff.lng],
            ],
          },
        ],
      }),
      [row('o1', true)],
    );
    const [job] = await svc.listReady(actor);
    expect(job.route.available).toBe(true);
    expect(job.route.coords.length).toBe(3);
  });

  it('returns available=false (no straight fallback) without pickup or on routing failure', async () => {
    const svc = service(async () => {
      throw new Error('down');
    }, [row('o1', true), row('o2', false)]);
    const jobs = await svc.listReady(actor);
    for (const job of jobs) {
      expect(job.route.available).toBe(false);
      expect(job.route.coords).toEqual([]);
    }
  });
});
