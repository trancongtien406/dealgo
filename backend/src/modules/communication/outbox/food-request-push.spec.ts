import { describe, expect, it, vi } from 'vitest';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';
import type { OutboxPendingRow } from './outbox.repository.js';

const row = (status: string, eventType = `FoodOrder.status.${status}`): OutboxPendingRow => ({
  id: `m-${status}`,
  eventKey: `FoodOrder:o1:status:${status}`,
  aggregateType: 'FoodOrder',
  aggregateId: 'o1',
  eventType,
  payload: { status },
  createdAt: new Date('2026-10-26T12:00:00Z'),
  attempts: 0,
});

const audience = {
  driverIds: ['near', 'mid', 'far'],
  order: { id: 'o1', deliveryFareVnd: 18000, storeName: 'Bún Bò', dropoffLabel: '12 Lê Lợi' },
  ttlSeconds: 900,
};

function relay(opts: { enabled?: boolean; max?: number; allowed?: (ids: string[]) => string[] } = {}) {
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const food = { readyAudience: vi.fn().mockResolvedValue(audience) };
  const prefs = { filterRecipients: vi.fn(async (ids: string[]) => (opts.allowed ? opts.allowed(ids) : ids)) };
  const settings = {
    getBoolean: vi.fn().mockResolvedValue(opts.enabled ?? true),
    getNumber: vi.fn().mockResolvedValue(opts.max ?? 30),
  };
  const svc = new OutboxRelayService(
    new MemoryOutboxRepository(),
    undefined,
    push as never,
    undefined,
    food as never,
    undefined,
    undefined,
    prefs as never,
    settings as never,
  );
  return { svc, push, food, prefs };
}

describe('food request push (READY → nearby drivers)', () => {
  it('pushes nearby food drivers with a high-priority, collapsing push that opens the job list', async () => {
    const { svc, push, prefs } = relay();
    await expect(svc.pushFoodRequest(row('READY'))).resolves.toBe(3);
    expect(prefs.filterRecipients).toHaveBeenCalledWith(['near', 'mid', 'far'], 'FOOD');
    expect(push.send).toHaveBeenCalledWith({
      userId: 'near',
      title: 'Đơn giao đồ ăn mới gần bạn · 18.000đ',
      body: 'Bún Bò → 12 Lê Lợi',
      data: {
        aggregateType: 'FoodOrder',
        aggregateId: 'o1',
        status: 'READY',
        eventType: 'FoodOrder.request.nearby',
        role: 'DRIVER',
        path: '/driver/jobs',
      },
      collapseKey: 'food-request-o1',
      ttlSeconds: 900,
      urgent: true,
      alert: { kind: 'NEW_FOOD_JOB', customSound: true },
    });
  });

  it('falls back to the default sound when the driver turned "Âm báo có đơn mới" off', async () => {
    const { svc, push, prefs } = relay();
    (prefs as Record<string, unknown>).getNotificationPrefs = vi.fn(async (id: string) => ({ newJobSound: id !== 'mid' }));
    await svc.pushFoodRequest(row('READY'));
    const alerts = push.send.mock.calls.map((c) => [c[0].userId, c[0].alert]);
    expect(alerts).toEqual([
      ['near', { kind: 'NEW_FOOD_JOB', customSound: true }],
      ['mid', { kind: 'NEW_FOOD_JOB', customSound: false }],
      ['far', { kind: 'NEW_FOOD_JOB', customSound: true }],
    ]);
  });

  it('caps to the nearest drivers and honours the food toggle', async () => {
    const { svc, push } = relay({ max: 2, allowed: (ids) => ids.filter((id) => id !== 'mid') });
    await expect(svc.pushFoodRequest(row('READY'))).resolves.toBe(1);
    expect(push.send).toHaveBeenCalledTimes(1);
    expect(push.send.mock.calls[0]![0].userId).toBe('near');
  });

  it('does nothing when switched off, for other statuses or for store edits', async () => {
    const off = relay({ enabled: false });
    await expect(off.svc.pushFoodRequest(row('READY'))).resolves.toBe(0);
    const on = relay();
    await expect(on.svc.pushFoodRequest(row('PREPARING'))).resolves.toBe(0);
    await expect(on.svc.pushFoodRequest(row('READY', 'FoodOrder.change.PENDING'))).resolves.toBe(0);
    expect(on.food.readyAudience).not.toHaveBeenCalled();
    expect(off.push.send).not.toHaveBeenCalled();
  });

  it('is part of relayOnce and never fails the outbox row', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed(row('READY'));
    // Only the job push fails; the row must still be marked processed.
    const push = {
      send: vi.fn(async (n: { data: Record<string, string> }) => {
        if (n.data.eventType === 'FoodOrder.request.nearby') throw new Error('fcm down');
      }),
    };
    const food = {
      readyAudience: vi.fn().mockResolvedValue(audience),
      participantRoles: vi.fn().mockResolvedValue(null),
      participantUserIds: vi.fn().mockResolvedValue([]),
    };
    const fanout = { emitSnapshot: vi.fn() };
    const svc = new OutboxRelayService(repo, fanout as never, push as never, undefined, food as never);
    await expect(svc.relayOnce(10, new Date('2026-10-26T12:00:05Z'))).resolves.toBe(1);
    expect(food.readyAudience).toHaveBeenCalledWith('o1');
  });
});
