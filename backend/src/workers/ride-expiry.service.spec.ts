import { RideLedger } from '../modules/ride/ride-ledger.js';
import { MemoryRideRepository } from '../modules/ride/ride.repository.js';
import type { RideService } from '../modules/ride/ride.service.js';
import type { FoodService } from '../modules/food-order/food.service.js';
import { RideExpiryService } from './ride-expiry.service.js';

const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };

describe('RideExpiryService', () => {
  it('expires negotiating rides past expiresAt with a fake clock', async () => {
    const start = new Date('2026-10-14T12:00:00.000Z');
    const rides = new MemoryRideRepository();
    const created = await rides.create({
      customerId: '00000000-0000-4000-8000-000000000011',
      idempotencyKey: 'idem-expiry-worker',
      pickup,
      dropoff,
      offeredFareVnd: 40_000,
      vehicleClassCode: 'MOTORBIKE',
      referenceFareVnd: 40_000,
      expiresAt: new Date(start.getTime() + 60_000),
      now: start,
    });

    const rideService = {
      expireDue: async (now?: Date, limit?: number) => ({
        expiredIds: await rides.expireDue(now ?? new Date(), limit),
      }),
    } as Pick<RideService, 'expireDue'>;
    const service = new RideExpiryService(rideService as RideService);

    const later = new Date('2026-10-14T12:02:00.000Z');
    await expect(service.runOnce(later)).resolves.toBe(1);
    await expect(service.runOnce(later)).resolves.toBe(0);

    const stored = await rides.findById(created.id, later);
    expect(stored?.status).toBe('EXPIRED');
  });

  it('Also runs ride assignment timeouts and food timeouts', async () => {
    const calls: string[] = [];
    const rideService = {
      expireDue: async () => ({ expiredIds: [] }),
      timeoutDue: async () => {
        calls.push('ride.timeoutDue');
        return { returnedIds: ['r1'] };
      },
    } as unknown as RideService;
    const foodService = {
      timeoutDue: async (now: Date) => {
        calls.push(`food.timeoutDue:${now.toISOString()}`);
        return { orderIds: ['f1', 'f2'] };
      },
    } as unknown as FoodService;
    const at = new Date('2026-10-14T12:00:00.000Z');
    await expect(new RideExpiryService(rideService, foodService).runOnce(at)).resolves.toBe(0);
    expect(calls).toEqual(['ride.timeoutDue', `food.timeoutDue:${at.toISOString()}`]);
  });

  it('marks due negotiating rides expired in the ledger', () => {
    const ledger = new RideLedger();
    const now = new Date('2026-10-14T12:00:00.000Z');
    const created = ledger.create({
      customerId: '00000000-0000-4000-8000-000000000012',
      idempotencyKey: 'idem-ledger-expire',
      pickup,
      dropoff,
      offeredFareVnd: 40_000,
      vehicleClassCode: 'MOTORBIKE',
      referenceFareVnd: 40_000,
      expiresAt: new Date(now.getTime() + 30_000),
      now,
    });
    expect(created.ride?.status).toBe('NEGOTIATING');
    const dueAt = new Date(now.getTime() + 31_000);
    expect(ledger.expireDue(dueAt)).toEqual([created.ride!.id]);
    expect(ledger.read(created.ride!.id, dueAt)?.status).toBe('EXPIRED');
  });
});
