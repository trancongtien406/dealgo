import { describe, expect, it, vi } from 'vitest';
import { CAMPAIGN_BATCH_SIZE, OutboxRelayService } from '../outbox/outbox-relay.service.js';
import { MemoryOutboxRepository } from '../outbox/outbox.repository.js';
import { MemoryInboxRepository } from './inbox.repository.js';
import { InboxService } from './inbox.service.js';

describe('InboxService', () => {
  async function seeded() {
    const repo = new MemoryInboxRepository();
    await repo.createMany([
      { userId: 'u1', category: 'FOOD', title: 'A', body: 'a', sourceEventKey: 'e1' },
      { userId: 'u1', category: 'RIDE', title: 'B', body: 'b', sourceEventKey: 'e2' },
      { userId: 'u2', category: 'RIDE', title: 'C', body: 'c', sourceEventKey: 'e2' },
    ]);
    return { repo, service: new InboxService(repo) };
  }

  it('lists only the owner rows, newest first, with an unread count', async () => {
    const { service } = await seeded();
    const page = await service.list('u1', { page: 1, limit: 10 });
    expect(page.items.map((i) => i.title)).toEqual(['B', 'A']);
    expect(page.unreadCount).toBe(2);
    expect(page.items.every((i) => i.read === false)).toBe(true);
  });

  it('filters by category and unread state', async () => {
    const { service } = await seeded();
    const ride = await service.list('u1', { category: 'RIDE' });
    expect(ride.items.map((i) => i.title)).toEqual(['B']);
    const first = (await service.list('u1')).items[0];
    await service.markRead('u1', first.id);
    const unread = await service.list('u1', { unreadOnly: true });
    expect(unread.items.map((i) => i.title)).toEqual(['A']);
    expect(unread.unreadCount).toBe(1);
  });

  it("returns 404 for another user's notification", async () => {
    const { service } = await seeded();
    const other = (await service.list('u2')).items[0];
    await expect(service.markRead('u1', other.id)).rejects.toMatchObject({ status: 404 });
  });

  it('marks everything read and skips duplicate event keys', async () => {
    const { repo, service } = await seeded();
    expect(
      await repo.createMany([
        { userId: 'u1', category: 'FOOD', title: 'A', body: 'a', sourceEventKey: 'e1' },
      ]),
    ).toBe(0);
    await expect(service.markAllRead('u1')).resolves.toEqual({ updated: 2 });
    expect((await service.list('u1')).unreadCount).toBe(0);
  });
});

describe('OutboxRelayService inbox fan-out', () => {
  it('writes one localized inbox row per participant, idempotent on retry', async () => {
    const outbox = new MemoryOutboxRepository();
    const row = {
      id: 'msg-1',
      eventKey: 'FoodOrder:o1:status:PICKED_UP',
      aggregateType: 'FoodOrder',
      aggregateId: 'o1',
      eventType: 'FoodOrder.status.PICKED_UP',
      payload: { status: 'PICKED_UP' },
      createdAt: new Date('2026-10-19T00:00:00.000Z'),
      attempts: 0,
    };
    outbox.seed(row);
    const inbox = new MemoryInboxRepository();
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const food = { participantUserIds: vi.fn().mockResolvedValue(['customer-1', 'driver-1']) };
    const relay = new OutboxRelayService(
      outbox,
      { emitSnapshot: vi.fn() } as never,
      push as never,
      undefined,
      food as never,
      undefined,
      inbox,
    );
    await relay.relayOnce(10, new Date('2026-10-19T00:01:00.000Z'));
    const page = await inbox.list('customer-1', { page: 1, limit: 10 });
    expect(page.items).toHaveLength(1);
    expect(page.items[0]).toMatchObject({
      category: 'FOOD',
      title: 'Tài xế đã lấy món',
      data: { aggregateType: 'FoodOrder', aggregateId: 'o1', status: 'PICKED_UP' },
    });
    expect(push.send).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 'customer-1', title: 'Tài xế đã lấy món' }),
    );
    // A retried relay of the same event must not duplicate the row.
    outbox.seed({ ...row, id: 'msg-1-retry' });
    await relay.relayOnce(10, new Date('2026-10-19T00:02:00.000Z'));
    expect((await inbox.list('customer-1', { page: 1, limit: 10 })).total).toBe(1);
  });

  it('puts a campaign in every targeted inbox in batches but pushes only to token holders', async () => {
    const outbox = new MemoryOutboxRepository();
    outbox.seed({
      id: 'camp-1',
      eventKey: 'NotificationCampaign:c1:send',
      aggregateType: 'NotificationCampaign',
      aggregateId: 'c1',
      eventType: 'NotificationCampaign.send',
      payload: { title: 'Ưu đãi', body: 'Giảm 20%', audience: 'CUSTOMER', code: 'DEAL20' },
      createdAt: new Date('2026-10-19T00:00:00.000Z'),
      attempts: 0,
    });
    const users = Array.from({ length: 1200 }, (_, i) => `u-${String(i).padStart(5, '0')}`);
    const withTokens = new Set(users.filter((_, i) => i % 100 === 0));
    const findUsers = vi.fn(
      async (args: { take: number; cursor?: { id: string }; skip?: number }) => {
        const start = args.cursor ? users.indexOf(args.cursor.id) + (args.skip ?? 0) : 0;
        return users.slice(start, start + args.take).map((id) => ({ id }));
      },
    );
    const db = {
      user: { findMany: findUsers },
      pushDeviceToken: {
        findMany: vi.fn(async (args: { where: { userId: { in: string[] } } }) =>
          args.where.userId.in.filter((id) => withTokens.has(id)).map((userId) => ({ userId })),
        ),
      },
    };
    const inbox = new MemoryInboxRepository();
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const relay = new OutboxRelayService(
      outbox,
      undefined,
      push as never,
      undefined,
      undefined,
      { db: () => db } as never,
      inbox,
    );
    await relay.relayOnce(10, new Date('2026-10-19T00:01:00.000Z'));

    expect(findUsers).toHaveBeenCalledTimes(Math.ceil(1200 / CAMPAIGN_BATCH_SIZE));
    expect(findUsers.mock.calls[0]![0]).toMatchObject({
      where: { roleGrants: { some: { role: 'CUSTOMER', status: 'ACTIVE' } } },
    });
    for (const userId of ['u-00000', 'u-00777', 'u-01199']) {
      const page = await inbox.list(userId, { page: 1, limit: 10 });
      expect(page.items[0]).toMatchObject({ category: 'PROMOTION', title: 'Ưu đãi' });
    }
    expect(push.send).toHaveBeenCalledTimes(withTokens.size);
  });
});
