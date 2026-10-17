import { describe, expect, it } from 'vitest';
import { RideLedger, type CreateRideInput } from './ride-ledger.js';

describe('RideLedger Domain Logic', () => {
  const now = new Date('2026-10-16T10:00:00.000Z');
  const future = new Date('2026-10-16T10:15:00.000Z');

  const baseInput: CreateRideInput = {
    customerId: 'cust-1',
    idempotencyKey: 'idem-1',
    pickup: { lat: 10.762622, lng: 106.660172, label: 'District 1, HCMC' },
    dropoff: { lat: 10.776889, lng: 106.700806, label: 'Ben Thanh, HCMC' },
    offeredFareVnd: 50_000,
    referenceFareVnd: 48_000,
    expiresAt: future,
    now,
  };

  describe('create', () => {
    it('creates a new ride in NEGOTIATING status', () => {
      const ledger = new RideLedger();
      const outcome = ledger.create(baseInput);

      expect(outcome.error).toBeUndefined();
      expect(outcome.ride).toBeDefined();
      expect(outcome.ride?.status).toBe('NEGOTIATING');
      expect(outcome.ride?.customerId).toBe('cust-1');
      expect(outcome.ride?.offeredFareVnd).toBe(50_000);
      expect(outcome.ride?.offers).toEqual([]);
    });

    it('returns existing ride when same customer and idempotencyKey are reused', () => {
      const ledger = new RideLedger();
      const first = ledger.create(baseInput);
      const second = ledger.create({ ...baseInput, offeredFareVnd: 999_999 });

      expect(first.ride?.id).toBe(second.ride?.id);
      expect(second.ride?.offeredFareVnd).toBe(50_000);
    });

    it('rejects creating when customer already has an active NEGOTIATING ride', () => {
      const ledger = new RideLedger();
      ledger.create(baseInput);

      const second = ledger.create({
        ...baseInput,
        idempotencyKey: 'idem-2',
      });

      expect(second.error).toBe('RIDE_ALREADY_OPEN');
      expect(second.ride).toBeUndefined();
    });

    it('allows creating when previous ride has expired', () => {
      const ledger = new RideLedger();
      ledger.create({
        ...baseInput,
        expiresAt: new Date(now.getTime() + 1000),
      });

      const later = new Date(now.getTime() + 2000);
      const second = ledger.create({
        ...baseInput,
        idempotencyKey: 'idem-2',
        now: later,
        expiresAt: new Date(later.getTime() + 60_000),
      });

      expect(second.error).toBeUndefined();
      expect(second.ride?.id).toBeDefined();
    });
  });

  describe('offer and negotiation', () => {
    it('allows driver to submit offer and prevents customer from offering own ride', () => {
      const ledger = new RideLedger();
      const created = ledger.create(baseInput);
      const rideId = created.ride!.id;

      const ownOffer = ledger.offer({
        rideId,
        driverId: 'cust-1',
        amountVnd: 55_000,
        kind: 'COUNTER',
        expiresAt: future,
        now,
      });
      expect(ownOffer.error).toBe('RIDE_SELF_OFFER');

      const driverOffer = ledger.offer({
        rideId,
        driverId: 'driver-1',
        amountVnd: 52_000,
        kind: 'COUNTER',
        expiresAt: future,
        now,
      });
      expect(driverOffer.error).toBeUndefined();
      expect(driverOffer.ride?.offers).toHaveLength(1);
      expect(driverOffer.ride?.offers[0].amountVnd).toBe(52_000);

      // Driver can update their pending offer amount
      const updatedOffer = ledger.offer({
        rideId,
        driverId: 'driver-1',
        amountVnd: 53_000,
        kind: 'COUNTER',
        expiresAt: future,
        now,
      });
      expect(updatedOffer.error).toBeUndefined();
      expect(updatedOffer.ride?.offers[0].amountVnd).toBe(53_000);

      // Rejects when max rounds exceeded
      const capped = ledger.offer({
        rideId,
        driverId: 'driver-2',
        amountVnd: 54_000,
        kind: 'COUNTER',
        expiresAt: future,
        maxRounds: 1,
        now,
      });
      expect(capped.error).toBe('RIDE_NEGOTIATION_ROUNDS_EXCEEDED');
    });

    it('rejects offer on non-existent or expired ride', () => {
      const ledger = new RideLedger();
      const res = ledger.offer({
        rideId: 'non-existent',
        driverId: 'driver-1',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      });
      expect(res.error).toBe('RIDE_NOT_FOUND');
    });
  });

  describe('select', () => {
    it('selects offer, transitions ride to ASSIGNED and marks other offers as LOST', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;

      ledger.offer({
        rideId: ride.id,
        driverId: 'driver-1',
        amountVnd: 52_000,
        kind: 'COUNTER',
        expiresAt: future,
        now,
      });
      const withOffer2 = ledger.offer({
        rideId: ride.id,
        driverId: 'driver-2',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      }).ride!;

      const offerToSelect = withOffer2.offers.find((o) => o.driverId === 'driver-1')!;

      const selectResult = ledger.select({
        rideId: ride.id,
        customerId: 'cust-1',
        offerId: offerToSelect.id,
        idempotencyKey: 'select-idem-1',
        now,
      });

      expect(selectResult.error).toBeUndefined();
      const assigned = selectResult.ride!;
      expect(assigned.status).toBe('ASSIGNED');
      expect(assigned.assignedDriverId).toBe('driver-1');
      expect(assigned.agreedFareVnd).toBe(52_000);

      const winningOffer = assigned.offers.find((o) => o.id === offerToSelect.id);
      const losingOffer = assigned.offers.find((o) => o.driverId === 'driver-2');
      expect(winningOffer?.status).toBe('SELECTED');
      expect(losingOffer?.status).toBe('LOST');
    });

    it('rejects selection by non-customer actor', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;
      const offer = ledger.offer({
        rideId: ride.id,
        driverId: 'driver-1',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      }).ride!.offers[0];

      const res = ledger.select({
        rideId: ride.id,
        customerId: 'intruder',
        offerId: offer.id,
        idempotencyKey: 'select-1',
        now,
      });
      expect(res.error).toBe('RIDE_NOT_FOUND');
    });
  });

  describe('driver lifecycle progression', () => {
    it('progresses through ASSIGNED -> DRIVER_EN_ROUTE -> DRIVER_ARRIVED -> IN_TRIP -> COMPLETED', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;
      const offer = ledger.offer({
        rideId: ride.id,
        driverId: 'driver-1',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      }).ride!.offers[0];

      ledger.select({
        rideId: ride.id,
        customerId: 'cust-1',
        offerId: offer.id,
        idempotencyKey: 'sel-1',
        now,
      });

      // Wrong driver cannot advance lifecycle
      const wrongDriver = ledger.markEnRoute({
        rideId: ride.id,
        driverId: 'stranger-driver',
        now,
      });
      expect(wrongDriver.error).toBe('RIDE_NOT_ASSIGNED_DRIVER');

      // 1. En Route
      const enRoute = ledger.markEnRoute({ rideId: ride.id, driverId: 'driver-1', now });
      expect(enRoute.error).toBeUndefined();
      expect(enRoute.ride?.status).toBe('DRIVER_EN_ROUTE');

      // Cannot skip to IN_TRIP directly
      const prematureTrip = ledger.startTrip({ rideId: ride.id, driverId: 'driver-1', now });
      expect(prematureTrip.error).toBe('RIDE_STATUS_CONFLICT');

      // 2. Arrived
      const arrived = ledger.markArrived({ rideId: ride.id, driverId: 'driver-1', now });
      expect(arrived.error).toBeUndefined();
      expect(arrived.ride?.status).toBe('DRIVER_ARRIVED');

      // 3. Start Trip
      const inTrip = ledger.startTrip({ rideId: ride.id, driverId: 'driver-1', now });
      expect(inTrip.error).toBeUndefined();
      expect(inTrip.ride?.status).toBe('IN_TRIP');

      // 4. Complete
      const completed = ledger.complete({ rideId: ride.id, driverId: 'driver-1', now });
      expect(completed.error).toBeUndefined();
      expect(completed.ride?.status).toBe('COMPLETED');
    });
  });

  describe('cancellation and ops intervention', () => {
    it('customer can cancel during NEGOTIATING and pre-trip', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;

      const cancelled = ledger.cancel({
        rideId: ride.id,
        customerId: 'cust-1',
        now,
      });
      expect(cancelled.error).toBeUndefined();
      expect(cancelled.ride?.status).toBe('CANCELLED');
    });

    it('customer cannot cancel during IN_TRIP', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;
      const offer = ledger.offer({
        rideId: ride.id,
        driverId: 'driver-1',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      }).ride!.offers[0];

      ledger.select({
        rideId: ride.id,
        customerId: 'cust-1',
        offerId: offer.id,
        idempotencyKey: 'sel-1',
        now,
      });
      ledger.markEnRoute({ rideId: ride.id, driverId: 'driver-1', now });
      ledger.markArrived({ rideId: ride.id, driverId: 'driver-1', now });
      ledger.startTrip({ rideId: ride.id, driverId: 'driver-1', now });

      const cancelAttempt = ledger.cancel({
        rideId: ride.id,
        customerId: 'cust-1',
        now,
      });
      expect(cancelAttempt.error).toBe('RIDE_NOT_CANCELLABLE');
    });

    it('opsReassign resets pre-trip ride back to NEGOTIATING', () => {
      const ledger = new RideLedger();
      const ride = ledger.create(baseInput).ride!;
      const offer = ledger.offer({
        rideId: ride.id,
        driverId: 'driver-1',
        amountVnd: 50_000,
        kind: 'ACCEPT',
        expiresAt: future,
        now,
      }).ride!.offers[0];

      ledger.select({
        rideId: ride.id,
        customerId: 'cust-1',
        offerId: offer.id,
        idempotencyKey: 'sel-1',
        now,
      });

      const reassigned = ledger.opsReassign({
        rideId: ride.id,
        now,
      });

      expect(reassigned.error).toBeUndefined();
      expect(reassigned.ride?.status).toBe('NEGOTIATING');
      expect(reassigned.ride?.assignedDriverId).toBeNull();
      expect(reassigned.ride?.agreedFareVnd).toBeNull();
    });
  });

  describe('expiry', () => {
    it('expireDue flags and marks expired rides', () => {
      const ledger = new RideLedger();
      ledger.create({
        ...baseInput,
        expiresAt: new Date(now.getTime() + 5000),
      });

      const expiredBefore = ledger.expireDue(now);
      expect(expiredBefore).toHaveLength(0);

      const expiredAfter = ledger.expireDue(new Date(now.getTime() + 10_000));
      expect(expiredAfter).toHaveLength(1);
    });
  });
});
