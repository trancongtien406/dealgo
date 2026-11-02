import { describe, expect, it, vi } from 'vitest';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';
import { OUTBOX_MAX_ATTEMPTS, outboxBackoffMs } from './outbox.constants.js';

describe('outbox retry backoff + dead-letter (REL-001)', () => {
  it('backs off exponentially and dead-letters at the cap', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'bad-1',
      eventKey: 'LegalPolicy:p1:mail',
      aggregateType: 'LegalPolicy', // no handler registered in this test -> always fails
      aggregateId: 'p1',
      eventType: 'LegalPolicy.published',
      payload: {},
      createdAt: new Date('2026-10-14T00:00:00.000Z'),
      attempts: 0,
    });
    const relay = new OutboxRelayService(repo, { emitSnapshot: vi.fn() } as never, { send: vi.fn() } as never);
    let now = new Date('2026-10-14T00:01:00.000Z');

    await relay.relayOnce(10, now);
    const first = repo.inspect('bad-1')!;
    expect(first.attempts).toBe(1);
    expect(first.nextAttemptAt?.getTime()).toBe(now.getTime() + outboxBackoffMs(1));
    // Not claimable before the backoff elapses.
    expect(await repo.claimPending(10, new Date(now.getTime() + 1_000))).toHaveLength(0);

    for (let i = 1; i < OUTBOX_MAX_ATTEMPTS; i += 1) {
      now = new Date(repo.inspect('bad-1')!.nextAttemptAt!.getTime());
      await relay.relayOnce(10, now);
    }
    const last = repo.inspect('bad-1')!;
    expect(last.attempts).toBe(OUTBOX_MAX_ATTEMPTS);
    expect(last.deadLetteredAt).toEqual(now);
    expect(await repo.claimPending(10, new Date(now.getTime() + 86_400_000))).toHaveLength(0);
    expect(await repo.listPending(10)).toHaveLength(0);
  });

  it('caps the delay', () => {
    expect(outboxBackoffMs(1)).toBe(5_000);
    expect(outboxBackoffMs(2)).toBe(10_000);
    expect(outboxBackoffMs(50)).toBe(15 * 60_000);
  });
});
