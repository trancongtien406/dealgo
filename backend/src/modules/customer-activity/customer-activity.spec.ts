import { describe, expect, it } from 'vitest';
import type { FoodService } from '../food-order/food.service.js';
import { RideLedger, type CreateRideInput } from '../ride/ride-ledger.js';
import type { RideService } from '../ride/ride.service.js';
import { CustomerActivityService } from './customer-activity.service.js';

type Live = { id: string; status: string } | null;

function make(ride: Live, order: Live) {
  const rides = { activeRideForCustomer: async () => ride } as unknown as RideService;
  const food = { activeOrderForCustomer: async () => order } as unknown as FoodService;
  return new CustomerActivityService(rides, food);
}

describe('CustomerActivityService.activeTrip (DEC-PROD-057)', () => {
  it('prefers a live ride over an open food order', async () => {
    const trip = await make({ id: 'r1', status: 'IN_TRIP' }, { id: 'o1', status: 'PREPARING' }).activeTrip('c1');
    expect(trip).toEqual({ trip: { kind: 'RIDE', id: 'r1', status: 'IN_TRIP' } });
  });

  it('falls back to the open food order', async () => {
    const trip = await make(null, { id: 'o1', status: 'PICKED_UP' }).activeTrip('c1');
    expect(trip).toEqual({ trip: { kind: 'FOOD_ORDER', id: 'o1', status: 'PICKED_UP' } });
  });

  it('returns null when nothing is live', async () => {
    expect(await make(null, null).activeTrip('c1')).toEqual({ trip: null });
  });
});

describe('RideLedger.listIdsForCustomerInStatuses', () => {
  const now = new Date('2026-10-16T10:00:00.000Z');
  const input: CreateRideInput = {
    customerId: 'cust-1',
    idempotencyKey: 'idem-1',
    pickup: { lat: 10.76, lng: 106.66, label: 'A' },
    dropoff: { lat: 10.77, lng: 106.7, label: 'B' },
    offeredFareVnd: 50_000,
    vehicleClassCode: 'MOTORBIKE',
    referenceFareVnd: 48_000,
    expiresAt: new Date('2026-10-16T10:15:00.000Z'),
    now,
  };

  it('returns only the customer’s rides in the requested statuses', () => {
    const ledger = new RideLedger();
    const created = ledger.create(input).ride;
    ledger.create({ ...input, customerId: 'cust-2', idempotencyKey: 'idem-2' });
    expect(ledger.listIdsForCustomerInStatuses('cust-1', ['NEGOTIATING'])).toEqual([created?.id]);
    expect(ledger.listIdsForCustomerInStatuses('cust-1', ['IN_TRIP'])).toEqual([]);
  });
});
