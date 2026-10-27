import { describe, expect, it } from 'vitest';
import { notificationsFor, partnerStatusNotification, rideOfferReceivedNotification, shortOrderCode } from './notification-audience.js';

const P = { customerId: 'c1', driverId: 'd1', merchantId: 'm1' };

describe('notification audience', () => {
  it('uses the same last-4 order code as the apps', () => {
    expect(shortOrderCode('7b1e-1234c45d81')).toBe('#5D81');
  });
  it('food PLACED notifies only the merchant (new order)', () => {
    const out = notificationsFor('FoodOrder', 'o-abcd1234', 'PLACED', P);
    expect(out).toEqual([expect.objectContaining({ userId: 'm1', title: 'Đơn mới #1234' })]);
  });
  it('food status changes reach the customer; cancel also reaches merchant and driver', () => {
    expect(notificationsFor('FoodOrder', 'o1', 'PREPARING', P).map((n) => n.userId)).toEqual(['c1']);
    expect(notificationsFor('FoodOrder', 'o1', 'CANCELLED', P).map((n) => n.userId)).toEqual(['c1', 'm1', 'd1']);
  });
  it('ride ASSIGNED tells the customer and the selected driver', () => {
    const out = notificationsFor('Ride', 'r1', 'ASSIGNED', { customerId: 'c1', driverId: 'd1' });
    expect(out.map((n) => n.userId)).toEqual(['c1', 'd1']);
    expect(out[1]!.title).toBe('Khách đã chọn bạn');
  });
  it('driver arriving / trip completed go to the customer', () => {
    expect(notificationsFor('Ride', 'r1', 'DRIVER_ARRIVED', P)[0]!.userId).toBe('c1');
    expect(notificationsFor('Ride', 'r1', 'COMPLETED', P).map((n) => n.userId)).toEqual(['c1']);
  });
  it('partner approved / rejected', () => {
    expect(partnerStatusNotification('u1', 'DRIVER', 'APPROVED')!.title).toBe('Hồ sơ đã được duyệt');
    expect(partnerStatusNotification('u1', 'DRIVER', 'PENDING')).toBeNull();
  });
  it('offer received goes to the customer', () => {
    expect(rideOfferReceivedNotification('c1', 'r1').userId).toBe('c1');
  });
});

describe('driver job hint', () => {
  it('ASSIGNED snapshot is also sent to the assigned driver user room', async () => {
    const { OutboxRelayService } = await import('../outbox/outbox-relay.service.js');
    const { MemoryOutboxRepository } = await import('../outbox/outbox.repository.js');
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'm1', eventKey: 'Ride:r9:status:ASSIGNED', aggregateType: 'Ride', aggregateId: 'r9',
      eventType: 'Ride.status.ASSIGNED', payload: { status: 'ASSIGNED' }, createdAt: new Date(), attempts: 0,
    });
    const fanout = { emitSnapshot: () => undefined, emitUserSnapshot: (u: string) => calls.push(u) };
    const calls: string[] = [];
    const push = { send: async () => undefined };
    const rides = { participantRoles: async () => ({ customerId: 'c1', driverId: 'd1' }), participantUserIds: async () => ['c1', 'd1'] };
    const relay = new OutboxRelayService(repo, fanout as never, push as never, rides as never);
    await relay.relayOnce(10, new Date());
    expect(calls).toEqual(['d1']);
  }, 30_000);
});
