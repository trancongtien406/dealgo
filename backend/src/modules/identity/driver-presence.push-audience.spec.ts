import { describe, expect, it } from 'vitest';
import { MemoryDriverPresenceRepository } from './driver-presence.repository.js';
import { DriverPresenceService } from './driver-presence.service.js';

describe('DriverPresenceService.onlineNearForPush', () => {
  it('keeps backgrounded drivers (last fix < 30 min) for push and flags who is fresh for the socket', async () => {
    const repo = new MemoryDriverPresenceRepository();
    const now = new Date('2026-10-26T12:30:00Z');
    const at = (minAgo: number) => new Date(now.getTime() - minAgo * 60_000);
    await repo.upsert('fresh', { online: true });
    await repo.updateLocation('fresh', { lat: 10.7725, lng: 106.698, at: at(1) });
    await repo.upsert('background', { online: true });
    await repo.updateLocation('background', { lat: 10.773, lng: 106.699, at: at(20) });
    await repo.upsert('gone', { online: true });
    await repo.updateLocation('gone', { lat: 10.773, lng: 106.699, at: at(45) });
    await repo.upsert('offline', { online: false });
    await repo.updateLocation('offline', { lat: 10.773, lng: 106.699, at: at(1) });
    await repo.upsert('offline', { online: false });
    const svc = new DriverPresenceService(repo, {} as never);

    const rows = await svc.onlineNearForPush('RIDE', { lat: 10.7725, lng: 106.698 }, 5, now);
    expect(rows.map((r) => [r.userId, r.fresh]).sort((a, b) => String(a[0]).localeCompare(String(b[0])))).toEqual([
      ['background', false],
      ['fresh', true],
    ]);
  });
});
