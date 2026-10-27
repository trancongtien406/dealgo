import { describe, expect, it, vi } from 'vitest';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';
import type { OutboxPendingRow } from './outbox.repository.js';

const row = (status: string, eventType = `FoodOrder.status.${status}`): OutboxPendingRow => ({
  id: `m-${status}`,
  eventKey: `FoodOrder:o1:status:${status}:${eventType}`,
  aggregateType: 'FoodOrder',
  aggregateId: 'o1',
  eventType,
  payload: { status },
  createdAt: new Date('2026-10-26T12:00:00Z'),
  attempts: 0,
});

function relay(newJobSound = true) {
  const repo = new MemoryOutboxRepository();
  const push = { send: vi.fn().mockResolvedValue(undefined) };
  const food = {
    readyAudience: vi.fn().mockResolvedValue(null),
    participantRoles: vi.fn().mockResolvedValue({ customerId: 'c1', merchantId: 'm1', driverId: null }),
    participantUserIds: vi.fn().mockResolvedValue(['c1', 'm1']),
  };
  const prefs = {
    filterRecipients: vi.fn(async (ids: string[]) => ids),
    getNotificationPrefs: vi.fn().mockResolvedValue({ newJobSound }),
  };
  const settings = { getBoolean: vi.fn().mockResolvedValue(true), getNumber: vi.fn().mockResolvedValue(30) };
  const fanout = { emitSnapshot: vi.fn() };
  const svc = new OutboxRelayService(
    repo,
    fanout as never,
    push as never,
    undefined,
    food as never,
    undefined,
    undefined,
    prefs as never,
    settings as never,
  );
  return { svc, repo, push };
}

const merchantPushes = (push: { send: ReturnType<typeof vi.fn> }) =>
  push.send.mock.calls.map((c) => c[0]).filter((n) => n.userId === 'm1');

describe('merchant new order sound (FoodOrder PLACED → store)', () => {
  it('rings the merchant with the spoken "quán có đơn mới" sound, urgent', async () => {
    const { svc, repo, push } = relay();
    repo.seed(row('PLACED'));
    await svc.relayOnce(10, new Date('2026-10-26T12:00:05Z'));
    const [n] = merchantPushes(push);
    expect(n).toMatchObject({ urgent: true, alert: { kind: 'MERCHANT_NEW_ORDER', customSound: true } });
    for (const other of push.send.mock.calls.map((c) => c[0]).filter((x) => x.userId !== 'm1')) {
      expect(other.alert).toBeUndefined();
    }
  });

  it('uses the default sound when the merchant turned the spoken alert off', async () => {
    const { svc, repo, push } = relay(false);
    repo.seed(row('PLACED'));
    await svc.relayOnce(10, new Date('2026-10-26T12:00:05Z'));
    expect(merchantPushes(push)[0]).toMatchObject({ alert: { kind: 'MERCHANT_NEW_ORDER', customSound: false } });
  });

  it('later statuses keep the normal notification sound', async () => {
    const { svc, repo, push } = relay();
    repo.seed(row('CANCELLED'));
    await svc.relayOnce(10, new Date('2026-10-26T12:00:05Z'));
    for (const n of merchantPushes(push)) expect(n.alert).toBeUndefined();
  });
});
