import { describe, expect, it } from 'vitest';
import { RideLedger, stopWaitFeeVnd, type CreateRideInput } from './ride-ledger.js';
import {
  loadMultiStopConfig,
  referenceWithStopsVnd,
  stopsRuleError,
  RIDE_STOPS_HARD_MAX,
} from './ride-multi-stop.js';

const t0 = new Date('2026-11-01T10:00:00.000Z');
const later = (minutes: number) => new Date(t0.getTime() + minutes * 60_000);
const stopA = { lat: 10.77, lng: 106.69, label: 'Stop A' };
const stopB = { lat: 10.78, lng: 106.68, label: 'Stop B' };

const base: CreateRideInput = {
  customerId: 'cust-1',
  idempotencyKey: 'idem-ms',
  pickup: { lat: 10.76, lng: 106.66, label: 'Pickup' },
  dropoff: { lat: 10.79, lng: 106.7, label: 'Dropoff' },
  offeredFareVnd: 60_000,
  referenceFareVnd: 60_000,
  vehicleClassCode: 'CAR_4',
  expiresAt: later(5),
  now: t0,
  stops: [stopA, stopB],
  stopPolicy: { feeVnd: 10_000, freeWaitMinutes: 5, waitFeeVndPerMinute: 1_000 },
};

function negotiating() {
  const ledger = new RideLedger();
  const ride = ledger.create(base).ride!;
  return { ledger, rideId: ride.id };
}

function inTrip() {
  const { ledger, rideId } = negotiating();
  const offered = ledger.offer({ rideId, driverId: 'drv-1', amountVnd: 60_000, expiresAt: later(5), now: t0 });
  const offerId = offered.ride!.offers[0]!.id;
  expect(ledger.select({ rideId, customerId: 'cust-1', offerId, idempotencyKey: 'sel', now: t0 }).error).toBeUndefined();
  for (const step of ['markEnRoute', 'markArrived', 'startTrip'] as const) {
    expect(ledger[step]({ rideId, driverId: 'drv-1', now: t0 }).error).toBeUndefined();
  }
  return { ledger, rideId };
}

describe('multi-stop ledger', () => {
  it('stores stops in order with the policy snapshot; single-destination rides keep zeros', () => {
    const { ledger, rideId } = negotiating();
    const ride = ledger.read(rideId, t0)!;
    expect(ride.stops.map((s) => [s.seq, s.label])).toEqual([
      [1, 'Stop A'],
      [2, 'Stop B'],
    ]);
    expect(ride.stopFeeVnd).toBe(10_000);
    expect(ride.routeVersion).toBe(0);

    const plain = new RideLedger().create({ ...base, stops: undefined, stopPolicy: undefined }).ride!;
    expect(plain.stops).toEqual([]);
    expect(plain.stopFeeVnd).toBe(0);
    expect(plain.stopWaitFeeVndPerMinute).toBe(0);
  });

  it('editing stops kills pending offers, bumps the route version and restarts the round', () => {
    const { ledger, rideId } = negotiating();
    ledger.offer({ rideId, driverId: 'drv-1', amountVnd: 60_000, expiresAt: later(5), now: t0 });
    ledger.offer({ rideId, driverId: 'drv-1', amountVnd: 65_000, expiresAt: later(5), now: t0 });
    const updated = ledger.updateStops({
      rideId,
      customerId: 'cust-1',
      stops: [stopB],
      dropoff: base.dropoff,
      referenceFareVnd: 55_000,
      offeredFareVnd: 58_000,
      stopFeeVnd: 10_000,
      expectedRouteVersion: 0,
      windowExpiresAt: later(10),
      now: later(1),
    });
    expect(updated.error).toBeUndefined();
    const ride = updated.ride!;
    expect(ride.routeVersion).toBe(1);
    expect(ride.stops.map((s) => s.label)).toEqual(['Stop B']);
    expect(ride.referenceFareVnd).toBe(55_000);
    expect(ride.offeredFareVnd).toBe(58_000);
    expect(ride.offers.every((o) => o.status === 'LOST')).toBe(true);
    expect(ride.offers.every((o) => (o.editCount ?? 0) === 0)).toBe(true);

    // A driver who saw version 0 is told the route changed; quoting v1 works.
    const stale = ledger.offer({ rideId, driverId: 'drv-2', amountVnd: 58_000, expiresAt: later(10), now: later(1), routeVersion: 0 });
    expect(stale.error).toBe('RIDE_ROUTE_CHANGED');
    const fresh = ledger.offer({ rideId, driverId: 'drv-2', amountVnd: 58_000, expiresAt: later(10), now: later(1), routeVersion: 1 });
    expect(fresh.error).toBeUndefined();
    // drv-1 may bid again in the new round.
    const again = ledger.offer({ rideId, driverId: 'drv-1', amountVnd: 58_000, expiresAt: later(10), now: later(1), routeVersion: 1 });
    expect(again.error).toBeUndefined();
  });

  it('rejects a stale optimistic version', () => {
    const { ledger, rideId } = negotiating();
    const res = ledger.updateStops({
      rideId,
      customerId: 'cust-1',
      stops: [],
      dropoff: base.dropoff,
      referenceFareVnd: 50_000,
      offeredFareVnd: 50_000,
      stopFeeVnd: 0,
      expectedRouteVersion: 3,
      windowExpiresAt: later(10),
      now: t0,
    });
    expect(res.error).toBe('RIDE_ROUTE_CHANGED');
  });

  it('locks stops once a driver is selected', () => {
    const { ledger, rideId } = inTrip();
    const res = ledger.updateStops({
      rideId,
      customerId: 'cust-1',
      stops: [],
      dropoff: base.dropoff,
      referenceFareVnd: 50_000,
      offeredFareVnd: 50_000,
      stopFeeVnd: 0,
      windowExpiresAt: later(10),
      now: t0,
    });
    expect(res.error).toBe('RIDE_STOPS_LOCKED');
  });

  it('driver handles stops in order, idempotently, and completes only after the last one', () => {
    const { ledger, rideId } = inTrip();
    const drv = { rideId, driverId: 'drv-1' };
    expect(ledger.arriveStop({ ...drv, seq: 2, now: later(1) }).error).toBe('RIDE_STOP_OUT_OF_ORDER');
    expect(ledger.departStop({ ...drv, seq: 1, now: later(1) }).error).toBe('RIDE_STOP_OUT_OF_ORDER');
    expect(ledger.arriveStop({ rideId, driverId: 'other', seq: 1, now: later(1) }).error).toBeDefined();
    expect(ledger.complete({ ...drv, now: later(2) }).error).toBe('RIDE_STOPS_PENDING');

    expect(ledger.arriveStop({ ...drv, seq: 1, now: later(2) }).error).toBeUndefined();
    const repeat = ledger.arriveStop({ ...drv, seq: 1, now: later(3) });
    expect(repeat.ride!.stops[0]!.arrivedAt).toEqual(later(2));
    expect(ledger.departStop({ ...drv, seq: 1, now: later(10) }).error).toBeUndefined(); // 8 min → 3 billable
    expect(ledger.arriveStop({ ...drv, seq: 2, now: later(12) }).error).toBeUndefined();
    expect(ledger.departStop({ ...drv, seq: 2, now: later(14) }).error).toBeUndefined(); // 2 min → free
    const done = ledger.complete({ ...drv, now: later(20) });
    expect(done.error).toBeUndefined();
    expect(done.ride!.status).toBe('COMPLETED');
    expect(done.ride!.waitFeeVnd).toBe(3_000);
  });

  it('stop events require IN_TRIP', () => {
    const { ledger, rideId } = negotiating();
    expect(ledger.arriveStop({ rideId, driverId: 'drv-1', seq: 1, now: t0 }).error).toBeDefined();
  });
});

describe('stopWaitFeeVnd', () => {
  it('bills whole minutes over the free allowance per stop', () => {
    const stops = [
      { arrivedAt: t0, departedAt: later(7.9) }, // 7 whole minutes → 2 billable
      { arrivedAt: t0, departedAt: later(4) },
      { arrivedAt: null, departedAt: null },
    ];
    expect(stopWaitFeeVnd(stops, 5, 1_000)).toBe(2_000);
    expect(stopWaitFeeVnd(stops, 5, 0)).toBe(0);
    expect(stopWaitFeeVnd([], 5, 1_000)).toBe(0);
  });
});

describe('multi-stop config', () => {
  const settings = (values: Record<string, number | boolean>) => ({
    getBoolean: async (key: string) => Boolean(values[key]),
    getNumber: async (key: string) => Number(values[key] ?? 0),
  });

  it('is off by default and zero stops are always allowed', async () => {
    const config = await loadMultiStopConfig(settings({ RIDE_MAX_STOPS_CAR: 2 }) as never, 'CAR');
    expect(config.enabled).toBe(false);
    expect(config.maxStops).toBe(0);
    expect(stopsRuleError(0, config)).toBeNull();
    expect(stopsRuleError(1, config)).toBe('RIDE_STOPS_DISABLED');
  });

  it('reads per-service keys and enforces the max with a hard cap', async () => {
    const values = {
      RIDE_MULTI_STOP_BIKE_ENABLED: true,
      RIDE_MAX_STOPS_BIKE: 1,
      RIDE_STOP_FEE_BIKE_VND: 5_000,
      RIDE_MULTI_STOP_CAR_ENABLED: true,
      RIDE_MAX_STOPS_CAR: 99,
      RIDE_STOP_FEE_CAR_VND: 10_000,
      RIDE_STOP_FREE_WAIT_MINUTES: 5,
      RIDE_STOP_WAIT_FEE_VND_PER_MINUTE: 1_000,
    };
    const bike = await loadMultiStopConfig(settings(values) as never, 'BIKE');
    expect(bike).toMatchObject({ enabled: true, maxStops: 1, stopFeeVnd: 5_000 });
    expect(stopsRuleError(2, bike)).toBe('RIDE_TOO_MANY_STOPS');
    const car = await loadMultiStopConfig(settings(values) as never, 'CAR');
    expect(car.maxStops).toBe(RIDE_STOPS_HARD_MAX);
    expect(car.freeWaitMinutes).toBe(5);
  });

  it('adds the per-stop fee to the reference inside the class window', () => {
    expect(referenceWithStopsVnd(50_000, 0, 10_000, { minFareVnd: 10_000, maxFareVnd: 900_000 })).toBe(50_000);
    expect(referenceWithStopsVnd(50_000, 2, 10_000, { minFareVnd: 10_000, maxFareVnd: 900_000 })).toBe(70_000);
    expect(referenceWithStopsVnd(50_000, 2, 10_000, { minFareVnd: 10_000, maxFareVnd: 60_000 })).toBe(60_000);
  });
});
