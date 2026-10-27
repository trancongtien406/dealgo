import { describe, expect, it, vi } from 'vitest';
import { RideOfferEvents } from '../../ride/ride-offer-events.js';
import { onlyOwnOffers } from '../../ride/ride.service.js';
import { parseSnapshotRoom, roomForRideOffers } from './realtime.constants.js';
import { RideOfferFanoutService } from './ride-offer-fanout.service.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { SocketAccessService } from './socket-access.service.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const offers = [
  { id: 'o1', driverId: 'd1', amountVnd: 50000, kind: 'ACCEPT' as const, status: 'PENDING' as const, expiresAt: 'x', editCount: 0 },
  { id: 'o2', driverId: 'd2', amountVnd: 55000, kind: 'COUNTER' as const, status: 'PENDING' as const, expiresAt: 'x', editCount: 0 },
];

describe('RideOfferFanoutService', () => {
  it('pushes the full offer list only to the customer offers room', async () => {
    const emit = vi.fn();
    const to = vi.fn().mockReturnValue({ emit });
    const fanout = new SnapshotFanoutService();
    fanout.bindServer({ to } as never);
    const rides = { customerOffersSnapshot: vi.fn().mockResolvedValue({ status: 'NEGOTIATING', offers, updatedAt: 'rev1' }) };
    const events = new RideOfferEvents();
    const svc = new RideOfferFanoutService(events, rides as never, fanout);
    svc.onModuleInit();
    events.publish({ rideId, reason: 'OFFER', at: new Date('2026-10-24T03:00:00Z') });
    await vi.waitFor(() => expect(emit).toHaveBeenCalled());
    expect(to).toHaveBeenCalledWith(`ride-offers:${rideId}`);
    expect(emit).toHaveBeenCalledWith('rideOffers', expect.objectContaining({ rideId, reason: 'OFFER', offers, revision: 'rev1' }));
    svc.onModuleDestroy();
  });

  it('skips silently when the ride vanished', async () => {
    const fanout = { emitRideOffers: vi.fn() };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), { customerOffersSnapshot: vi.fn().mockResolvedValue(null) } as never, fanout as never);
    await svc.handle({ rideId, reason: 'EXPIRED', at: new Date() });
    expect(fanout.emitRideOffers).not.toHaveBeenCalled();
  });
});

describe('RideOfferFanoutService.broadcastRequest', () => {
  it('sends the request to each nearby driver user room for CREATED/RAISED/DRIVER_CANCELLED/TIMEOUT', async () => {
    const emit = vi.fn();
    const to = vi.fn().mockReturnValue({ emit });
    const fanout = new SnapshotFanoutService();
    fanout.bindServer({ to } as never);
    const ride = { id: rideId, offeredFareVnd: 40000 };
    const rides = { requestAudience: vi.fn().mockResolvedValue({ ride, driverIds: ['d1', 'd2'] }) };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout);
    for (const reason of ['CREATED', 'RAISED', 'DRIVER_CANCELLED', 'TIMEOUT'] as const) {
      await svc.broadcastRequest({ rideId, reason, at: new Date('2026-10-24T03:00:00Z') });
    }
    expect(rides.requestAudience).toHaveBeenCalledTimes(4);
    expect(to).toHaveBeenCalledWith(['user:d1', 'user:d2']);
    expect(emit).toHaveBeenCalledWith('rideRequest', expect.objectContaining({ reason: 'RAISED', ride }));
  });

  it('does not broadcast offers, selection or cancel, and tolerates an empty audience', async () => {
    const rides = { requestAudience: vi.fn().mockResolvedValue({ ride: {}, driverIds: [] }) };
    const fanout = { emitRideRequest: vi.fn() };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never);
    for (const reason of ['OFFER', 'SELECTED', 'CANCELLED', 'DECLINED', 'WITHDRAWN'] as const) {
      await svc.broadcastRequest({ rideId, reason, at: new Date() });
    }
    expect(rides.requestAudience).not.toHaveBeenCalled();
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at: new Date() });
    expect(fanout.emitRideRequest).not.toHaveBeenCalled();
  });
});

describe('offer visibility', () => {
  it('ride-offers room is customer-only (same check as location room)', async () => {
    const rides = { canSubscribe: vi.fn().mockResolvedValue(true), canSubscribeLocation: vi.fn(async (u: string) => u === 'customer') };
    const access = new SocketAccessService({} as never, {} as never, rides as never, {} as never);
    const room = parseSnapshotRoom(roomForRideOffers(rideId))!;
    expect(room.kind).toBe('ride-offers');
    await expect(access.canJoinRoom('customer', room)).resolves.toBe(true);
    await expect(access.canJoinRoom('d1', room)).resolves.toBe(false);
  });

  it('drivers only see their own offer', () => {
    expect(onlyOwnOffers({ offers }, 'd1').offers.map((o) => o.id)).toEqual(['o1']);
    expect(onlyOwnOffers({ offers }, 'stranger').offers).toEqual([]);
  });
});

describe('RideOfferFanoutService.pushRequest', () => {
  const ride = {
    id: rideId,
    offeredFareVnd: 45000,
    expiresAt: '2026-10-24T03:02:00Z',
    pickup: { label: 'Hải Châu' },
    dropoff: { label: 'Sân bay' },
  };
  const at = new Date('2026-10-24T03:00:00Z');

  it('pushes each nearby driver once, collapsible, expiring with the request', async () => {
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push);
    expect(await svc.pushRequest(['d1', 'd2'], ride, at)).toBe(2);
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'd1',
        collapseKey: `ride-request-${rideId}`,
        ttlSeconds: 120,
        urgent: true,
        data: expect.objectContaining({ eventType: 'Ride.request.nearby', path: '/driver/jobs', aggregateId: rideId }),
      }),
    );
    // A fare raise 10s later does not re-buzz the same drivers; a new driver still gets it.
    expect(await svc.pushRequest(['d1', 'd3'], ride, new Date(at.getTime() + 10_000))).toBe(1);
    expect(push.send).toHaveBeenLastCalledWith(expect.objectContaining({ userId: 'd3' }));
    // After the dedupe window it may notify again.
    expect(await svc.pushRequest(['d1'], ride, new Date(at.getTime() + 61_000))).toBe(1);
  });

  it('honours notification prefs, caps the audience and survives a failing device', async () => {
    const push = { send: vi.fn().mockRejectedValueOnce(new Error('boom')).mockResolvedValue(undefined) };
    const prefs = { filterRecipients: vi.fn(async (ids: string[]) => ids.filter((id) => id !== 'd2')) };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, prefs as never);
    const many = Array.from({ length: 40 }, (_, i) => `d${i + 1}`);
    const sent = await svc.pushRequest(many, ride, at);
    expect(prefs.filterRecipients).toHaveBeenCalledWith(many.slice(0, 30), 'RIDE');
    expect(push.send).toHaveBeenCalledTimes(29);
    expect(sent).toBe(28);
  });

  it('rings with the spoken "có cuốc mới" sound unless the admin or the driver turned it off', async () => {
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const prefs = {
      filterRecipients: vi.fn(async (ids: string[]) => ids),
      getNotificationPrefs: vi.fn(async (id: string) => ({ newJobSound: id !== 'd2' })),
    };
    const settings = (customSound: boolean) => ({
      getBoolean: vi.fn(async (key: string) => (key === 'NEW_JOB_CUSTOM_SOUND_ENABLED' ? customSound : true)),
      getNumber: vi.fn().mockResolvedValue(30),
    });
    const svc = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, prefs as never, settings(true) as never);
    await svc.pushRequest(['d1', 'd2'], ride, at);
    expect(push.send.mock.calls.map((c) => [c[0].userId, c[0].alert])).toEqual([
      ['d1', { kind: 'NEW_RIDE', customSound: true }],
      ['d2', { kind: 'NEW_RIDE', customSound: false }],
    ]);
    push.send.mockClear();
    const adminOff = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, prefs as never, settings(false) as never);
    await adminOff.pushRequest(['d1'], ride, at);
    expect(push.send.mock.calls[0]![0].alert).toEqual({ kind: 'NEW_RIDE', customSound: false });
  });

  it('follows the admin switch and cap (RIDE_REQUEST_PUSH_ENABLED / _MAX_DRIVERS)', async () => {
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const settings = (enabled: boolean, max: number) => ({
      getBoolean: vi.fn().mockResolvedValue(enabled),
      getNumber: vi.fn().mockResolvedValue(max),
    });
    const off = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, undefined, settings(false, 30) as never);
    expect(await off.pushRequest(['d1'], ride, at)).toBe(0);
    const capped = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, undefined, settings(true, 1) as never);
    expect(await capped.pushRequest(['d1', 'd2'], ride, at)).toBe(1);
    const zero = new RideOfferFanoutService(new RideOfferEvents(), {} as never, {} as never, push, undefined, settings(true, 0) as never);
    expect(await zero.pushRequest(['d1'], ride, at)).toBe(0);
  });

  it('broadcastRequest also pushes the audience', async () => {
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const rides = { requestAudience: vi.fn().mockResolvedValue({ ride, driverIds: ['d1'] }) };
    const fanout = { emitRideRequest: vi.fn() };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never, push);
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at });
    expect(push.send).toHaveBeenCalledTimes(1);
  });

  it('pushes drivers whose app is backgrounded or killed (no fresh fix) without a socket emit', async () => {
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const rides = {
      requestAudience: vi.fn().mockResolvedValue({ ride, driverIds: [], pushDriverIds: ['asleep'] }),
    };
    const fanout = { emitRideRequest: vi.fn() };
    const svc = new RideOfferFanoutService(new RideOfferEvents(), rides as never, fanout as never, push);
    await svc.broadcastRequest({ rideId, reason: 'CREATED', at });
    expect(fanout.emitRideRequest).not.toHaveBeenCalled();
    expect(push.send).toHaveBeenCalledWith(expect.objectContaining({ userId: 'asleep', urgent: true }));
  });
});
