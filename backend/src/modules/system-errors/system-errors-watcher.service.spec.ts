import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { OpsEventBus } from '../../platform/ops-events/ops-event-bus.js';
import { SystemErrorsWatcherService } from './system-errors-watcher.service.js';
import type { SystemErrorsService } from './system-errors.service.js';

describe('SystemErrorsWatcherService', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('checks only while a stream is open and publishes on count change', async () => {
    const counts = [3, 3, 5];
    const unresolvedCount = vi.fn(async () => ({ count: counts.shift() ?? 5 }));
    const bus = new OpsEventBus();
    const w = new SystemErrorsWatcherService({ unresolvedCount } as unknown as SystemErrorsService, bus, 1000);
    w.onModuleInit();
    expect(w.running).toBe(false);
    const seen = vi.fn();
    const off = bus.subscribe(seen);
    expect(w.running).toBe(true);
    await vi.advanceTimersByTimeAsync(2000);
    expect(unresolvedCount).toHaveBeenCalledTimes(3);
    const published = seen.mock.calls.map((c) => c[0]);
    expect(published).toEqual([expect.objectContaining({ type: 'systemErrors', reason: 'countChanged', count: 5 })]);
    off();
    expect(w.running).toBe(false);
    await vi.advanceTimersByTimeAsync(5000);
    expect(unresolvedCount).toHaveBeenCalledTimes(3);
    w.onModuleDestroy();
  });

  it('swallows Sentry failures', async () => {
    const w = new SystemErrorsWatcherService(
      { unresolvedCount: vi.fn().mockRejectedValue(new Error('down')) } as unknown as SystemErrorsService,
      new OpsEventBus(),
      1000,
    );
    await expect(w.check()).resolves.toBeUndefined();
  });
});
