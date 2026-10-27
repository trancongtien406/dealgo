import { describe, expect, it, vi } from 'vitest';
import { MemoryChatRepository } from './chat.repository.js';
import { ChatService } from './chat.service.js';

function make() {
  const fanout = { emitChatMessage: vi.fn() };
  const rides = {
    canSubscribe: vi.fn().mockResolvedValue(true),
    contactMeta: vi.fn().mockResolvedValue({ status: 'IN_TRIP', updatedAt: new Date() }),
    participantRoles: vi.fn().mockResolvedValue({ customerId: 'cust-1', driverId: 'drv-1' }),
  };
  const food = {
    canSubscribe: vi.fn().mockResolvedValue(true),
    contactMeta: vi.fn().mockResolvedValue({ status: 'PICKED_UP', updatedAt: new Date() }),
    participantRoles: vi.fn().mockResolvedValue({ customerId: 'cust-1', driverId: 'drv-1', merchantId: 'm-1' }),
  };
  const settings = { getNumber: vi.fn().mockResolvedValue(30) };
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const repo = new MemoryChatRepository();
  const svc = new ChatService(repo, rides as never, food as never, settings as never, push as never, undefined, fanout as never);
  return { svc, fanout, repo };
}

describe('chat realtime + paging', () => {
  it('emits the new message to both participants (private rooms), never the merchant', async () => {
    const { svc, fanout } = make();
    const sent = await svc.postForFood({ userId: 'drv-1' } as never, 'o1', 'tới rồi');
    expect(fanout.emitChatMessage).toHaveBeenCalledTimes(1);
    const [userIds, payload] = fanout.emitChatMessage.mock.calls[0];
    expect([...userIds].sort((a, b) => a.localeCompare(b))).toEqual(['cust-1', 'drv-1']);
    expect(payload).toMatchObject({ aggregateType: 'FoodOrder', aggregateId: 'o1', message: { id: sent.id, body: 'tới rồi' } });
  });

  it('call notes are announced too (missed-call row appears live)', async () => {
    const { svc, fanout } = make();
    await svc.recordCallNote('Ride', 'r1', 'cust-1', '📞 Cuộc gọi nhỡ');
    expect(fanout.emitChatMessage.mock.calls[0][1]).toMatchObject({ aggregateType: 'Ride', message: { body: '📞 Cuộc gọi nhỡ' } });
  });

  it('page 1 is the newest window, oldest → newest inside the page', async () => {
    const repo = new MemoryChatRepository();
    for (let i = 0; i < 7; i += 1) {
      await repo.postMessage({ kind: 'ride', rideId: 'r1' }, 'u', `m${i}`);
    }
    const first = await repo.listMessages({ kind: 'ride', rideId: 'r1' }, 1, 3);
    expect(first.items.map((m) => m.body)).toEqual(['m4', 'm5', 'm6']);
    const second = await repo.listMessages({ kind: 'ride', rideId: 'r1' }, 2, 3);
    expect(second.items.map((m) => m.body)).toEqual(['m1', 'm2', 'm3']);
    expect(first.total).toBe(7);
  });
});
