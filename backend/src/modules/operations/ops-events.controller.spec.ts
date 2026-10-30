import { EventEmitter } from 'node:events';
import { GUARDS_METADATA } from '@nestjs/common/constants.js';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { OpsEventBus } from '../../platform/ops-events/ops-event-bus.js';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import {
  OPS_EVENTS_HEARTBEAT_MS,
  OPS_MONITOR_COALESCE_MS,
  OpsEventsController,
  canReadSystemErrors,
} from './ops-events.controller.js';

function fakeRes() {
  const res = new EventEmitter() as EventEmitter & Record<string, unknown>;
  const chunks: string[] = [];
  Object.assign(res, {
    status: vi.fn(() => res),
    setHeader: vi.fn(),
    flushHeaders: vi.fn(),
    write: vi.fn((c: string) => chunks.push(c)),
  });
  return { res, chunks };
}

const repo = (cred: unknown) => ({ findOpsCredential: vi.fn(async () => cred) }) as unknown as IdentityRepository;
const at = '2026-10-30T00:00:00.000Z';

describe('OpsEventsController', () => {
  beforeEach(() => vi.useFakeTimers());
  afterEach(() => vi.useRealTimers());

  it('is guarded by OpsSessionGuard like the monitor REST', () => {
    expect(Reflect.getMetadata(GUARDS_METADATA, OpsEventsController)).toEqual([OpsSessionGuard]);
  });

  it('streams ready, coalesced monitor, systemErrors, heartbeat; cleans up on close', async () => {
    const bus = new OpsEventBus();
    const c = new OpsEventsController(bus, repo({ superAdmin: true }));
    const req = new EventEmitter() as never as Parameters<OpsEventsController['stream']>[0];
    (req as unknown as { actor: unknown }).actor = { userId: 'u1', channel: 'ops' };
    const { res, chunks } = fakeRes();
    await c.stream(req, res as never);
    expect(chunks[0]).toContain('event: ready');
    expect(chunks[0]).toContain('"systemErrors":true');
    for (let i = 0; i < 5; i += 1) bus.publish({ type: 'monitor', reason: 'snapshot', at });
    bus.publish({ type: 'systemErrors', reason: 'statusChanged', at });
    await vi.advanceTimersByTimeAsync(OPS_MONITOR_COALESCE_MS);
    expect(chunks.filter((x) => x.startsWith('event: monitor'))).toHaveLength(1);
    expect(chunks.filter((x) => x.startsWith('event: systemErrors'))).toHaveLength(1);
    await vi.advanceTimersByTimeAsync(OPS_EVENTS_HEARTBEAT_MS);
    expect(chunks.some((x) => x.startsWith(': ping'))).toBe(true);
    (req as unknown as EventEmitter).emit('close');
    expect(bus.subscriberCount).toBe(0);
    const n = chunks.length;
    bus.publish({ type: 'monitor', reason: 'snapshot', at });
    await vi.advanceTimersByTimeAsync(OPS_EVENTS_HEARTBEAT_MS * 2);
    expect(chunks.length).toBe(n);
    expect(vi.getTimerCount()).toBe(0);
  });

  it('withholds systemErrors from actors without errors.read', async () => {
    const bus = new OpsEventBus();
    const c = new OpsEventsController(bus, repo(null));
    const req = Object.assign(new EventEmitter(), { actor: { userId: 'u2', channel: 'ops' } });
    const { res, chunks } = fakeRes();
    await c.stream(req as never, res as never);
    expect(chunks[0]).toContain('"systemErrors":false');
    bus.publish({ type: 'systemErrors', reason: 'statusChanged', at });
    expect(chunks.some((x) => x.startsWith('event: systemErrors'))).toBe(false);
    res.emit('close');
    expect(bus.subscriberCount).toBe(0);
  });

  it('canReadSystemErrors mirrors OpsPermissionGuard', async () => {
    expect(await canReadSystemErrors(repo({ superAdmin: true }), 'u')).toBe(true);
    expect(await canReadSystemErrors(repo(null), 'u')).toBe(false);
  });
});
