import { describe, expect, it, vi } from 'vitest';
import { RideOfferEvents } from '../../ride/ride-offer-events.js';
import { RideOfferFanoutService } from './ride-offer-fanout.service.js';
import { fcmMessage } from '../../../integrations/push/fcm-push-sender.js';

const rideId = '22222222-2222-4222-8222-222222222222';
const ride = { id: rideId, offeredFareVnd: 30000, expiresAt: '2026-10-29T10:05:00Z', pickup: { label: 'A' }, dropoff: { label: 'B' } };
const t0 = new Date('2026-10-29T10:00:00Z');
const at = (s: number) => new Date(t0.getTime() + s * 1000);

function setup(values: Record<string, number> = { RIDE_REQUEST_REPUSH_INTERVAL_SEC: 30, RIDE_REQUEST_REPUSH_MAX: 2 }) {
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const fanout = { emitRideRequest: vi.fn(), emitRideOffers: vi.fn() };
  const rides = {
    requestAudience: vi.fn().mockResolvedValue({ ride, driverIds: ['d1'], pushDriverIds: ['d1', 'd2'] }),
    customerOffersSnapshot: vi.fn(),
  };
  const settings = {
    getBoolean: vi.fn().mockResolvedValue(true),
    getNumber: vi.fn().mockResolvedValue(30),
    getOptionalNumber: vi.fn(async (k: string) => values[k]),
  };
  const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never, push as never, undefined, settings as never);
  return { svc, push, fanout, rides, settings };
}

describe('ride request re-push while open', () => {
  it('re-pushes after the admin interval, up to the max, then stops', async () => {
    const { svc, push } = setup();
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at: t0 });
    expect(push.send).toHaveBeenCalledTimes(2);
    await svc.repushOpenRequests(at(10)); // throttled
    expect(push.send).toHaveBeenCalledTimes(2);
    await svc.repushOpenRequests(at(31));
    expect(push.send).toHaveBeenCalledTimes(4);
    await svc.repushOpenRequests(at(62));
    expect(push.send).toHaveBeenCalledTimes(6);
    await svc.repushOpenRequests(at(93)); // max 2 reached
    expect(push.send).toHaveBeenCalledTimes(6);
  });

  it('interval 0 disables re-push', async () => {
    const { svc, push } = setup({ RIDE_REQUEST_REPUSH_INTERVAL_SEC: 0, RIDE_REQUEST_REPUSH_MAX: 3 });
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at: t0 });
    await svc.repushOpenRequests(at(120));
    expect(push.send).toHaveBeenCalledTimes(2);
  });

  it('closed request: no more pushes and every alerted driver gets a close hint', async () => {
    const { svc, push, fanout, rides } = setup();
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at: t0 });
    fanout.emitRideRequest.mockClear();
    rides.customerOffersSnapshot.mockResolvedValue({ status: 'CANCELLED', offers: [], updatedAt: 'r' });
    await svc.handle({ rideId, reason: 'CANCELLED', at: at(5) });
    expect(fanout.emitRideRequest).toHaveBeenCalledWith(
      expect.arrayContaining(['d1', 'd2']),
      expect.objectContaining({ reason: 'CLOSED_CANCELLED', ride: expect.objectContaining({ id: rideId }) }),
    );
    rides.requestAudience.mockResolvedValue(null);
    await svc.repushOpenRequests(at(40));
    expect(push.send).toHaveBeenCalledTimes(2);
  });

  it('request that vanished between ticks sends the close hint', async () => {
    const { svc, fanout, rides } = setup();
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at: t0 });
    rides.requestAudience.mockResolvedValue(null);
    fanout.emitRideRequest.mockClear();
    await svc.repushOpenRequests(at(31));
    expect(fanout.emitRideRequest).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({ reason: 'CLOSED_GONE' }));
  });
});

describe('APNs time-sensitive', () => {
  it('new-job alert pushes are time-sensitive; other pushes are not', () => {
    const base = { userId: 'd1', title: 't', body: 'b', data: {} };
    const job = fcmMessage('tok', { ...base, urgent: true, alert: { kind: 'NEW_RIDE', customSound: true } } as never) as any;
    expect(job.apns.payload.aps['interruption-level']).toBe('time-sensitive');
    const plain = fcmMessage('tok', base as never) as any;
    expect(plain.apns?.payload?.aps?.['interruption-level']).toBeUndefined();
  });
});
