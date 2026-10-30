import { describe, expect, it, vi } from 'vitest';
import { OpsEventBus, isOpsEvent } from './ops-event-bus.js';

const ev = { type: 'monitor' as const, reason: 'snapshot', at: '2026-10-30T00:00:00.000Z' };

describe('OpsEventBus', () => {
  it('fans out to subscribers and stops after unsubscribe', () => {
    const bus = new OpsEventBus();
    const a = vi.fn();
    const off = bus.subscribe(a);
    bus.publish(ev);
    off();
    bus.publish(ev);
    expect(a).toHaveBeenCalledTimes(1);
    expect(bus.subscriberCount).toBe(0);
  });

  it('reports subscriber counts and isolates listener errors', () => {
    const bus = new OpsEventBus();
    const counts: number[] = [];
    bus.onSubscriberCount((n) => counts.push(n));
    const ok = vi.fn();
    const off1 = bus.subscribe(() => {
      throw new Error('boom');
    });
    const off2 = bus.subscribe(ok);
    bus.publish(ev);
    expect(ok).toHaveBeenCalledWith(ev);
    off1();
    off1();
    off2();
    expect(counts).toEqual([1, 2, 1, 0]);
  });

  it('validates cross-process payloads', () => {
    expect(isOpsEvent(ev)).toBe(true);
    expect(isOpsEvent({ type: 'other', reason: 'x', at: 'y' })).toBe(false);
    expect(isOpsEvent(null)).toBe(false);
  });
});
