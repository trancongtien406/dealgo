import { describe, expect, it, vi } from 'vitest';
import { DriverLocationEvents } from '../../identity/driver-location-events.js';
import { DriverLocationFanoutService } from './driver-location-fanout.service.js';
import { parseSnapshotRoom } from './realtime.constants.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { SocketAccessService } from './socket-access.service.js';

const rideId = '11111111-1111-4111-8111-111111111111';
const foodId = '22222222-2222-4222-8222-222222222222';

function setup(rideIds: string[] = [rideId], orderIds: string[] = []) {
  const emit = vi.fn();
  const to = vi.fn(() => ({ emit }));
  const fanout = new SnapshotFanoutService();
  fanout.bindServer({ to } as never);
  const rides = { trackingRideIdsForDriver: vi.fn().mockResolvedValue(rideIds) };
  const food = { trackingOrderIdsForDriver: vi.fn().mockResolvedValue(orderIds) };
  const events = new DriverLocationEvents();
  const svc = new DriverLocationFanoutService(events, rides as never, food as never, fanout);
  return { svc, events, to, emit, rides };
}

describe('DriverLocationFanoutService', () => {
  it('emits driverLocation only to the customer location room of tracked jobs', async () => {
    const { svc, to, emit } = setup([rideId], [foodId]);
    await svc.handle({ driverId: 'd1', lat: 16.05, lng: 108.2, at: new Date('2026-10-24T00:00:00Z') });
    expect(to).toHaveBeenCalledWith(`ride-location:${rideId}`);
    expect(to).toHaveBeenCalledWith(`food-location:${foodId}`);
    expect(to).not.toHaveBeenCalledWith(`ride:${rideId}`);
    expect(emit).toHaveBeenCalledWith('driverLocation', {
      aggregateType: 'Ride', aggregateId: rideId, lat: 16.05, lng: 108.2, at: '2026-10-24T00:00:00.000Z',
    });
  });

  it('throttles fixes from the same driver under 2s', async () => {
    const { svc, emit } = setup();
    await svc.handle({ driverId: 'd1', lat: 1, lng: 1, at: new Date(1_000_000) });
    await svc.handle({ driverId: 'd1', lat: 2, lng: 2, at: new Date(1_001_000) });
    await svc.handle({ driverId: 'd1', lat: 3, lng: 3, at: new Date(1_002_500) });
    expect(emit).toHaveBeenCalledTimes(2);
  });

  it('emits nothing when the driver has no tracked job', async () => {
    const { svc, emit } = setup([], []);
    await svc.handle({ driverId: 'd1', lat: 1, lng: 1, at: new Date() });
    expect(emit).not.toHaveBeenCalled();
  });

  it('subscribes to the in-process bus on init', async () => {
    const { svc, events, rides } = setup();
    svc.onModuleInit();
    events.publish({ driverId: 'd9', lat: 1, lng: 1, at: new Date() });
    await new Promise((r) => setTimeout(r, 0));
    expect(rides.trackingRideIdsForDriver).toHaveBeenCalledWith('d9');
    svc.onModuleDestroy();
  });
});

describe('location room authz', () => {
  it('parses location rooms and routes to customer-only checks', async () => {
    const rides = { canSubscribeLocation: vi.fn().mockResolvedValue(false), canSubscribe: vi.fn() };
    const food = { canSubscribeLocation: vi.fn().mockResolvedValue(true), canSubscribe: vi.fn() };
    const access = new SocketAccessService({} as never, {} as never, rides as never, food as never);
    const r = parseSnapshotRoom(`ride-location:${rideId}`)!;
    const f = parseSnapshotRoom(`food-location:${foodId}`)!;
    expect(r.kind).toBe('ride-location');
    await expect(access.canJoinRoom('other', r)).resolves.toBe(false);
    await expect(access.canJoinRoom('cust', f)).resolves.toBe(true);
    expect(rides.canSubscribe).not.toHaveBeenCalled();
    expect(food.canSubscribe).not.toHaveBeenCalled();
    expect(parseSnapshotRoom('ride-location:not-a-uuid')).toBeNull();
  });
});
