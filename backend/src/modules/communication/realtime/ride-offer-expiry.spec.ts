import { afterEach, describe, expect, it, vi } from 'vitest';
import { RideOfferEvents } from '../../ride/ride-offer-events.js';
import { RideOfferFanoutService } from './ride-offer-fanout.service.js';

const rideId = '22222222-2222-4222-8222-222222222222';
const at = new Date('2026-10-31T07:00:00Z');
const offer = (expiresAt: string, status = 'PENDING') => ({
  id: 'o1', driverId: 'd1', amountVnd: 50000, kind: 'ACCEPT' as const, status, expiresAt, editCount: 0,
});

describe('Ride offer TTL realtime', () => {
  afterEach(() => vi.useRealTimers());

  it('announces OFFER_EXPIRED to the customer room and the driver once the offer is past expiresAt', async () => {
    const fanout = { emitRideOffers: vi.fn(), emitRideRequest: vi.fn() };
    const rides = { customerOffersSnapshot: vi.fn().mockResolvedValue({ status: 'NEGOTIATING', offers: [offer('2026-10-31T07:00:20.000Z')], updatedAt: 'r' }) };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never);
    expect(await svc.announceOfferExpiry(rideId, 'o1', new Date('2026-10-31T07:00:19Z'))).toBe(false);
    expect(await svc.announceOfferExpiry(rideId, 'o1', new Date('2026-10-31T07:00:21Z'))).toBe(true);
    expect(fanout.emitRideOffers).toHaveBeenCalledWith(expect.objectContaining({ rideId, reason: 'OFFER_EXPIRED' }));
    expect(fanout.emitRideRequest).toHaveBeenCalledWith(['d1'], expect.objectContaining({
      reason: 'OFFER_EXPIRED', ride: expect.objectContaining({ id: rideId, offerId: 'o1', canReoffer: true }),
    }));
  });

  it('stays quiet when the offer was selected/withdrawn or the ride closed', async () => {
    const fanout = { emitRideOffers: vi.fn(), emitRideRequest: vi.fn() };
    const rides = { customerOffersSnapshot: vi.fn()
      .mockResolvedValueOnce({ status: 'NEGOTIATING', offers: [offer('2026-10-31T07:00:20.000Z', 'SELECTED')], updatedAt: 'r' })
      .mockResolvedValueOnce({ status: 'ASSIGNED', offers: [offer('2026-10-31T07:00:20.000Z')], updatedAt: 'r' }) };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never);
    const later = new Date('2026-10-31T07:01:00Z');
    expect(await svc.announceOfferExpiry(rideId, 'o1', later)).toBe(false);
    expect(await svc.announceOfferExpiry(rideId, 'o1', later)).toBe(false);
    expect(fanout.emitRideRequest).not.toHaveBeenCalled();
  });

  it('arms a timer at expiresAt when an OFFER is fanned out', async () => {
    vi.useFakeTimers({ now: at });
    const fanout = { emitRideOffers: vi.fn(), emitRideRequest: vi.fn() };
    const rides = { customerOffersSnapshot: vi.fn().mockResolvedValue({ status: 'NEGOTIATING', offers: [offer('2026-10-31T07:00:20.000Z')], updatedAt: 'r' }), requestAudience: vi.fn() };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never);
    svc.armTimersInTest = true;
    await svc.handle({ rideId, reason: 'OFFER', at });
    expect(fanout.emitRideRequest).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(19_000);
    expect(fanout.emitRideRequest).not.toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(1_500);
    expect(fanout.emitRideRequest).toHaveBeenCalledWith(['d1'], expect.objectContaining({ reason: 'OFFER_EXPIRED' }));
    svc.onModuleDestroy();
  });
});
