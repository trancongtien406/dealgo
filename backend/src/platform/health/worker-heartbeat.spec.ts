import { ConfigService } from '@nestjs/config';
import { describe, expect, it, vi } from 'vitest';
import { loadEnv, type AppEnv } from '../config/env.js';
import { OpsAlertService } from '../observability/ops-alert.js';
import { HealthService } from './health.service.js';
import { outboxLagMs, workerStatus, type WorkerHeartbeatStore } from './worker-heartbeat.js';
import { WorkerWatchdog } from './worker-watchdog.js';
import { WorkerHeartbeatService } from '../../workers/worker-heartbeat.service.js';

const NOW = new Date('2026-10-26T03:00:00.000Z');
const ago = (ms: number) => new Date(NOW.getTime() - ms);
const config = (extra: Record<string, string> = {}) =>
  new ConfigService<AppEnv, true>(
    loadEnv({ NODE_ENV: 'test', WORKER_HEARTBEAT_STALE_MS: '60000', OUTBOX_LAG_ALERT_MS: '30000', ...extra }),
  );

function store(beatAgoMs: number | null, oldestPendingAgoMs: number | null): WorkerHeartbeatStore {
  return {
    beat: vi.fn(async () => undefined),
    latest: vi.fn(async () =>
      beatAgoMs === null ? null : { name: 'dealgo-workers', instance: 'h:1', startedAt: ago(beatAgoMs), beatAt: ago(beatAgoMs) },
    ),
    oldestPendingOutboxAt: vi.fn(async () => (oldestPendingAgoMs === null ? null : ago(oldestPendingAgoMs))),
  };
}

const health = (s: WorkerHeartbeatStore) =>
  new HealthService(config(), { ping: async () => true }, { ping: async () => true }, s);

describe('worker heartbeat + outbox lag (DEC-PROD-053)', () => {
  it('classifies heartbeats and lag', () => {
    expect(workerStatus(null, 60_000, NOW)).toBe('missing');
    expect(workerStatus({ name: 'w', instance: 'i', startedAt: NOW, beatAt: ago(10_000) }, 60_000, NOW)).toBe('up');
    expect(workerStatus({ name: 'w', instance: 'i', startedAt: NOW, beatAt: ago(70_000) }, 60_000, NOW)).toBe('stale');
    expect(outboxLagMs(null, NOW)).toBe(0);
    expect(outboxLagMs(ago(5_000), NOW)).toBe(5_000);
  });

  it('health reports the worker and degrades when it is stale or lagging', async () => {
    await expect(health(store(5_000, null)).worker(NOW)).resolves.toMatchObject({ status: 'up', outboxLagMs: 0 });
    const ready = await health(store(5_000, 45_000)).checkReady();
    expect(ready.status).toBe('degraded');
    expect(ready.worker?.outboxLagMs).toBeGreaterThan(30_000);
    expect((await health(store(null, null)).check()).status).toBe('degraded');
  });

  it('worker tick beats and alerts once per cooldown when lag exceeds the threshold', async () => {
    const s = store(0, 45_000);
    const beat = vi.spyOn(s, 'beat');
    const alerts = new OpsAlertService(config());
    const raise = vi.spyOn(alerts, 'raise');
    const service = new WorkerHeartbeatService(s, alerts, config());
    await expect(service.runOnce(NOW)).resolves.toEqual({ outboxLagMs: 45_000 });
    await service.runOnce(new Date(NOW.getTime() + 1_000));
    expect(beat).toHaveBeenCalledTimes(2);
    expect(raise).toHaveBeenCalledTimes(2);
    expect(await raise.mock.results[1]!.value).toBe(false);
  });

  it('posts alerts to OPS_ALERT_WEBHOOK_URL', async () => {
    const alerts = new OpsAlertService(config({ OPS_ALERT_WEBHOOK_URL: 'https://hooks.example/x' }));
    const fetchImpl = vi.fn(async () => new Response('ok'));
    alerts.fetchImpl = fetchImpl as never;
    await alerts.raise({ key: 'k', severity: 'critical', summary: 'boom' }, NOW.getTime());
    expect(fetchImpl).toHaveBeenCalledWith('https://hooks.example/x', expect.objectContaining({ method: 'POST' }));
    expect(JSON.parse((fetchImpl.mock.calls[0] as unknown as [string, RequestInit])[1].body as string)).toMatchObject({
      text: '[DealGo critical] boom',
    });
  });

  it('API watchdog raises worker.down for a stale worker', async () => {
    const alerts = new OpsAlertService(config());
    const raise = vi.spyOn(alerts, 'raise');
    await new WorkerWatchdog(health(store(120_000, null)), alerts, config()).checkOnce(NOW);
    expect(raise).toHaveBeenCalledWith(expect.objectContaining({ key: 'worker.down' }), NOW.getTime());
  });
});
