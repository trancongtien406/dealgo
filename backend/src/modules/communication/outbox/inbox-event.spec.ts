import { describe, expect, it, vi } from 'vitest';
import { MemoryInboxRepository } from '../inbox/inbox.repository.js';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';

type WriteInbox = (
  userIds: string[],
  eventKey: string,
  category: 'RIDE',
  title: string,
  body: string,
  data: Record<string, string>,
) => Promise<void>;

describe('OutboxRelayService inbox event', () => {
  it('bumps the recipient badge once per new inbox row', async () => {
    const fanout = { emitSnapshot: vi.fn(), emitInbox: vi.fn() };
    const relay = new OutboxRelayService(
      new MemoryOutboxRepository(),
      fanout as never,
      undefined,
      undefined,
      undefined,
      undefined,
      new MemoryInboxRepository(),
    );
    const write = (relay as unknown as { writeInbox: WriteInbox }).writeInbox.bind(relay);

    await write(['u1'], 'Ride:r1:status:ASSIGNED', 'RIDE', 'T', 'B', {});
    await write(['u1'], 'Ride:r1:status:ASSIGNED', 'RIDE', 'T', 'B', {});

    expect(fanout.emitInbox).toHaveBeenCalledTimes(1);
    expect(fanout.emitInbox).toHaveBeenCalledWith(['u1'], expect.objectContaining({ category: 'RIDE' }));
  });
});
