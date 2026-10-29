import { describe, expect, it } from 'vitest';
import { MemoryDriverPresenceRepository } from './driver-presence.repository.js';
import { DriverPresenceService } from './driver-presence.service.js';

/** Feed origin must accept every driver the job push reaches (same 30-min window). */
describe('DriverPresenceService.dispatchOrigin vs push audience', () => {
  const now = new Date('2026-10-29T10:52:40Z');
  const at = (minAgo: number) => new Date(now.getTime() - minAgo * 60_000);

  async function setup() {
    const repo = new MemoryDriverPresenceRepository();
    for (const [id, online, minAgo] of [
      ['fresh', true, 1],
      ['background', true, 20],
      ['gone', true, 45],
      ['offline', false, 5],
    ] as const) {
      await repo.upsert(id, { online });
      await repo.updateLocation(id, { lat: 16.0196, lng: 108.1966, at: at(minAgo) });
      await repo.upsert(id, { online });
    }
    return new DriverPresenceService(repo, {} as never);
  }

  it('lists from the last fix for a backgrounded driver who was pushed (no 409)', async () => {
    const svc = await setup();
    const pushed = (await svc.onlineNearForPush('RIDE', { lat: 16.0196, lng: 108.1966 }, 5, now)).map((r) => r.userId);
    for (const id of pushed) {
      await expect(svc.dispatchOrigin(id, {}, now, true)).resolves.toEqual({ lat: 16.0196, lng: 108.1966 });
    }
    expect(pushed.sort()).toEqual(['background', 'fresh']);
  });

  it('still answers DRIVER_LOCATION_STALE past the push window or when offline', async () => {
    const svc = await setup();
    await expect(svc.dispatchOrigin('gone', {}, now, true)).rejects.toMatchObject({ status: 409 });
    await expect(svc.dispatchOrigin('offline', {}, now, true)).rejects.toMatchObject({ status: 409 });
    await expect(svc.dispatchOrigin('nobody', {}, now, true)).rejects.toMatchObject({ status: 409 });
  });
});
