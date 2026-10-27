import { describe, expect, it, vi } from 'vitest';
import type { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../config/env.js';
import type { OpsAlertService } from '../observability/ops-alert.js';
import type { HealthService } from './health.service.js';
import { WorkerWatchdog } from './worker-watchdog.js';

function setup(report: Awaited<ReturnType<HealthService['worker']>>) {
  const health = { worker: vi.fn().mockResolvedValue(report) } as unknown as HealthService;
  const alerts = { raise: vi.fn().mockResolvedValue(true), resolve: vi.fn() };
  const config = { get: vi.fn().mockReturnValue('test') } as unknown as ConfigService<AppEnv, true>;
  return { watchdog: new WorkerWatchdog(health, alerts as unknown as OpsAlertService, config), alerts };
}

describe('WorkerWatchdog', () => {
  it('raises outbox.lag when lag exceeds the threshold', async () => {
    const { watchdog, alerts } = setup({
      status: 'up',
      lastBeatAt: new Date().toISOString(),
      outboxLagMs: 120_000,
      outboxLagAlertMs: 60_000,
    });
    await watchdog.checkOnce();
    expect(alerts.raise).toHaveBeenCalledWith(expect.objectContaining({ key: 'outbox.lag', severity: 'warning' }), expect.any(Number));
    expect(alerts.resolve).toHaveBeenCalledWith('worker.down');
  });

  it('raises worker.down and resolves outbox.lag when lag is fine', async () => {
    const { watchdog, alerts } = setup({ status: 'stale', lastBeatAt: null, outboxLagMs: 1_000, outboxLagAlertMs: 60_000 });
    await watchdog.checkOnce();
    expect(alerts.resolve).toHaveBeenCalledWith('outbox.lag');
    expect(alerts.raise).toHaveBeenCalledWith(expect.objectContaining({ key: 'worker.down', severity: 'critical' }), expect.any(Number));
  });

  it('does nothing when the heartbeat store is unavailable', async () => {
    const { watchdog, alerts } = setup(undefined);
    await watchdog.checkOnce();
    expect(alerts.raise).not.toHaveBeenCalled();
  });
});
