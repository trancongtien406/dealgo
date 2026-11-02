import { describe, expect, it, vi } from 'vitest';
import { registerOutboxHandler } from './outbox-handlers.js';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';

const row = (id: string, aggregateType: string) => ({
  id,
  eventKey: `legal-email:${id}:start`,
  aggregateType,
  aggregateId: id,
  eventType: 'legal.policy.email',
  payload: { cursor: null },
  createdAt: new Date('2026-10-31T00:00:00.000Z'),
  attempts: 0,
});

describe('outbox feature handlers (t82u)', () => {
  it('routes a registered aggregate to its handler and marks it processed', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed(row('a1', 'TestFeature'));
    const handler = vi.fn().mockResolvedValue(undefined);
    registerOutboxHandler('TestFeature', handler);
    const relay = new OutboxRelayService(repo);
    await expect(relay.relayOnce(10, new Date('2026-10-31T00:01:00.000Z'))).resolves.toBe(1);
    expect(handler).toHaveBeenCalledOnce();
  });

  it('keeps a LegalPolicy row pending when no handler is loaded', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed(row('b1', 'LegalPolicy'));
    const relay = new OutboxRelayService(repo);
    await expect(relay.relayOnce(10, new Date('2026-10-31T00:01:00.000Z'))).resolves.toBe(0);
  });
});
