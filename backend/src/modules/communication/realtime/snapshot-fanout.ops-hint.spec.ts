import { describe, expect, it, vi } from 'vitest';
import { OPS_HINT_SERVER_EVENT, OpsEventBus } from '../../../platform/ops-events/ops-event-bus.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';

describe('SnapshotFanoutService ops hints', () => {
  it('publishes locally and to other nodes via serverSideEmit; relays inbound hints', () => {
    const bus = new OpsEventBus();
    const seen = vi.fn();
    bus.subscribe(seen);
    const handlers = new Map<string, (p: unknown) => void>();
    const server = {
      on: vi.fn((name: string, fn: (p: unknown) => void) => handlers.set(name, fn)),
      serverSideEmit: vi.fn(),
      to: vi.fn(() => ({ emit: vi.fn() })),
    };
    const fanout = new SnapshotFanoutService(bus);
    fanout.bindServer(server as never);
    fanout.signalOps({ type: 'monitor', reason: 'snapshot', at: 't' });
    expect(seen).toHaveBeenCalledTimes(1);
    expect(server.serverSideEmit).toHaveBeenCalledWith(OPS_HINT_SERVER_EVENT, expect.objectContaining({ type: 'monitor' }));
    handlers.get(OPS_HINT_SERVER_EVENT)?.({ type: 'monitor', reason: 'snapshot', at: 't2' });
    handlers.get(OPS_HINT_SERVER_EVENT)?.({ bogus: true });
    expect(seen).toHaveBeenCalledTimes(2);
  });

  it('tolerates the in-memory adapter (serverSideEmit throws) and a missing bus', () => {
    const fanout = new SnapshotFanoutService();
    fanout.bindServer({ serverSideEmit: () => { throw new Error('unsupported'); } } as never);
    expect(() => fanout.signalOps({ type: 'monitor', reason: 'x', at: 't' })).not.toThrow();
  });
});
