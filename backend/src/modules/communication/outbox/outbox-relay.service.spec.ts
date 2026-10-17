import { describe, expect, it, vi } from 'vitest';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';

describe('OutboxRelayService', () => {
  it('marks pending rows processed and is idempotent on empty queue', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-1',
      eventKey: 'Ride:r1:status:ASSIGNED',
      aggregateType: 'Ride',
      aggregateId: 'r1',
      eventType: 'Ride.status.ASSIGNED',
      payload: { status: 'ASSIGNED' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    const fanout = { emitSnapshot: vi.fn() };
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const rides = { participantUserIds: vi.fn().mockResolvedValue(['customer-1']) };
    const relay = new OutboxRelayService(
      repo,
      fanout as never,
      push as never,
      rides as never,
    );
    const at = new Date('2026-10-14T00:01:00.000Z');

    await expect(relay.relayOnce(10, at)).resolves.toBe(1);
    await expect(relay.relayOnce(10, at)).resolves.toBe(0);
  });

  it('emits snapshot to fanout after marking processed', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-2',
      eventKey: 'FoodOrder:o1:status:READY',
      aggregateType: 'FoodOrder',
      aggregateId: 'o1',
      eventType: 'FoodOrder.status.READY',
      payload: { status: 'READY' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    const fanout = { emitSnapshot: vi.fn() };
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const food = { participantUserIds: vi.fn().mockResolvedValue(['customer-1']) };
    const relay = new OutboxRelayService(
      repo,
      fanout as never,
      push as never,
      undefined,
      food as never,
    );
    const at = new Date('2026-10-14T00:02:00.000Z');

    await expect(relay.relayOnce(10, at)).resolves.toBe(1);
    expect(fanout.emitSnapshot).toHaveBeenCalledWith({
      eventType: 'FoodOrder.status.READY',
      aggregateType: 'FoodOrder',
      aggregateId: 'o1',
      status: 'READY',
      revision: 'FoodOrder:o1:status:READY',
      occurredAt: at.toISOString(),
    });
  });

  it('sends push mock to known participants after snapshot', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-3',
      eventKey: 'Ride:r2:status:ASSIGNED',
      aggregateType: 'Ride',
      aggregateId: 'r2',
      eventType: 'Ride.status.ASSIGNED',
      payload: { status: 'ASSIGNED' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    const fanout = { emitSnapshot: vi.fn() };
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const rides = {
      participantUserIds: vi.fn().mockResolvedValue(['customer-1', 'driver-1']),
    };
    const relay = new OutboxRelayService(
      repo,
      fanout as never,
      push as never,
      rides as never,
    );
    const at = new Date('2026-10-14T00:03:00.000Z');

    await expect(relay.relayOnce(10, at)).resolves.toBe(1);
    expect(push.send).toHaveBeenCalledTimes(2);
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'customer-1',
        data: expect.objectContaining({ status: 'ASSIGNED', aggregateId: 'r2' }),
      }),
    );
  });

  it('fails fast and keeps row uncompleted when required provider is missing', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-missing-dep',
      eventKey: 'Ride:r-missing:status:ASSIGNED',
      aggregateType: 'Ride',
      aggregateId: 'r-missing',
      eventType: 'Ride.status.ASSIGNED',
      payload: { status: 'ASSIGNED' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    // Missing fanout and rides: must NOT mark processed!
    const relay = new OutboxRelayService(repo);
    const at = new Date('2026-10-14T00:04:00.000Z');

    await expect(relay.relayOnce(10, at)).resolves.toBe(0);

    const pending = await repo.listPending(10);
    expect(pending.length).toBe(1);
    expect(pending[0]?.id).toBe('msg-missing-dep');
  });

  it('keeps row pending when push dispatch throws an error (at-least-once retry)', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-fail',
      eventKey: 'Ride:r3:status:ASSIGNED',
      aggregateType: 'Ride',
      aggregateId: 'r3',
      eventType: 'Ride.status.ASSIGNED',
      payload: { status: 'ASSIGNED' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    const fanout = { emitSnapshot: vi.fn() };
    const push = {
      send: vi.fn().mockRejectedValue(new Error('Push network timeout')),
    };
    const rides = {
      participantUserIds: vi.fn().mockResolvedValue(['customer-1']),
    };
    const relay = new OutboxRelayService(
      repo,
      fanout as never,
      push as never,
      rides as never,
    );
    const at = new Date('2026-10-14T00:04:00.000Z');

    // processed count should be 0 because push failed
    await expect(relay.relayOnce(10, at)).resolves.toBe(0);

    // Row is still pending and has bumped attempts
    const pending = await repo.listPending(10);
    expect(pending.length).toBe(1);
    expect(pending[0]?.id).toBe('msg-fail');
    expect(pending[0]?.attempts).toBe(1);
  });

  it('atomically locks claimed rows so a second worker does not receive them', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'msg-lock-1',
      eventKey: 'Ride:r-lock:status:ASSIGNED',
      aggregateType: 'Ride',
      aggregateId: 'r-lock',
      eventType: 'Ride.status.ASSIGNED',
      payload: { status: 'ASSIGNED' },
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });

    const now = new Date('2026-10-14T00:05:00.000Z');
    const worker1Claim = await repo.claimPending(10, now, 60_000);
    expect(worker1Claim.length).toBe(1);
    expect(worker1Claim[0]?.id).toBe('msg-lock-1');

    // Worker 2 claiming at the same time receives 0 rows because msg-lock-1 is locked
    const worker2Claim = await repo.claimPending(10, now, 60_000);
    expect(worker2Claim.length).toBe(0);

    // After lock TTL expires, another worker can reclaim if not yet processed
    const later = new Date(now.getTime() + 61_000);
    const worker3Claim = await repo.claimPending(10, later, 60_000);
    expect(worker3Claim.length).toBe(1);
    expect(worker3Claim[0]?.id).toBe('msg-lock-1');
  });
});
