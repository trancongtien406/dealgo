import { describe, expect, it, vi } from 'vitest';
import { RideLedger, type CreateRideInput } from '../../ride/ride-ledger.js';
import { pushPathFor } from '../notification/push-path.js';
import {
  rideUnassignedNotifications,
  rideUnassignedReasonText,
} from '../notification/notification-audience.js';
import { OutboxRelayService } from './outbox-relay.service.js';
import { MemoryOutboxRepository } from './outbox.repository.js';
import { RIDE_UNASSIGNED_EVENT, writeRideUnassignedOutbox, writeStatusOutbox } from './outbox.write.js';

const now = new Date('2026-10-27T01:00:00.000Z');
const future = new Date('2026-10-27T01:15:00.000Z');

function assignedLedger(): { ledger: RideLedger; rideId: string } {
  const input: CreateRideInput = {
    customerId: 'cust-1',
    idempotencyKey: 'idem-1',
    pickup: { lat: 10.76, lng: 106.66, label: 'A' },
    dropoff: { lat: 10.77, lng: 106.7, label: 'B' },
    offeredFareVnd: 50_000,
    vehicleClassCode: 'MOTORBIKE',
    referenceFareVnd: 48_000,
    expiresAt: future,
    now,
  };
  const ledger = new RideLedger();
  const ride = ledger.create(input).ride!;
  const offered = ledger.offer({ rideId: ride.id, driverId: 'drv-1', amountVnd: 50_000, expiresAt: future, now }).ride!;
  ledger.select({ rideId: ride.id, customerId: 'cust-1', offerId: offered.offers[0]!.id, idempotencyKey: 's1', now });
  return { ledger, rideId: ride.id };
}

describe('ride unassigned (assignment timeout → back to offers)', () => {
  it('the ledger records who lost the ride and why', () => {
    const { ledger, rideId } = assignedLedger();
    ledger.clearRecorded();
    const later = new Date(now.getTime() + 6 * 60_000);
    const out = ledger.systemTimeout({
      rideId,
      now: later,
      policy: { assignedTimeoutMinutes: 5, enRouteTimeoutMinutes: 0 },
      windowExpiresAt: new Date(later.getTime() + 10 * 60_000),
    });
    expect(out.ride?.status).toBe('NEGOTIATING');
    expect(ledger.changes().unassignments).toEqual([
      expect.objectContaining({ rideId, driverId: 'drv-1', actor: 'SYSTEM', reasonCode: 'ASSIGNED_TIMEOUT', fromStatus: 'ASSIGNED' }),
    ]);
  });

  it('writes one outbox row per drop and keeps re-assignments from colliding', async () => {
    const createMany = vi.fn().mockResolvedValue({ count: 1 });
    const tx = { outboxMessage: { createMany } };
    await writeRideUnassignedOutbox(tx, {
      rideId: 'r1', driverId: 'drv-1', actor: 'SYSTEM', reasonCode: 'ASSIGNED_TIMEOUT', fromStatus: 'ASSIGNED', at: now,
    });
    const row = createMany.mock.calls[0]![0].data[0];
    expect(row.eventType).toBe(RIDE_UNASSIGNED_EVENT);
    expect(row.eventKey).toBe(`Ride:r1:unassigned:drv-1:${now.getTime()}`);
    expect(row.payload).toMatchObject({ status: 'NEGOTIATING', droppedDriverId: 'drv-1', reasonCode: 'ASSIGNED_TIMEOUT' });

    await writeStatusOutbox(tx, { aggregateType: 'Ride', aggregateId: 'r1', status: 'ASSIGNED', eventKeySuffix: 'drv-2@1' });
    expect(createMany.mock.calls[1]![0].data[0].eventKey).toBe('Ride:r1:status:ASSIGNED:drv-2@1');
  });

  it('driver copy explains the reason; a self-drop only tells the customer', () => {
    expect(rideUnassignedReasonText('ASSIGNED_TIMEOUT')).toContain('chưa bắt đầu');
    const list = rideUnassignedNotifications('r-abcd', {
      customerId: 'cust-1', droppedDriverId: 'drv-1', actor: 'SYSTEM', reasonCode: 'ASSIGNED_TIMEOUT',
    });
    expect(list.map((n) => [n.userId, n.role])).toEqual([['drv-1', 'DRIVER'], ['cust-1', 'CUSTOMER']]);
    expect(list[1]!.title).toBe('Đang tìm tài xế khác');
    const self = rideUnassignedNotifications('r-abcd', {
      customerId: 'cust-1', droppedDriverId: 'drv-1', actor: 'DRIVER', reasonCode: 'DRIVER_DROP',
    });
    expect(self.map((n) => n.userId)).toEqual(['cust-1']);
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', status: 'NEGOTIATING' })).toBe('/driver/jobs');
  });

  it('relay pushes both sides and emits rideUnassigned to the dropped driver', async () => {
    const repo = new MemoryOutboxRepository();
    repo.seed({
      id: 'm1',
      eventKey: `Ride:r9:unassigned:drv-1:${now.getTime()}`,
      aggregateType: 'Ride',
      aggregateId: 'r9',
      eventType: RIDE_UNASSIGNED_EVENT,
      payload: { status: 'NEGOTIATING', droppedDriverId: 'drv-1', actor: 'SYSTEM', reasonCode: 'ASSIGNED_TIMEOUT', fromStatus: 'ASSIGNED' },
      createdAt: now,
      attempts: 0,
    });
    const fanout = { emitSnapshot: vi.fn(), emitUserSnapshot: vi.fn(), emitRideUnassigned: vi.fn() };
    const push = { send: vi.fn().mockResolvedValue(undefined) };
    const rides = { participantRoles: vi.fn().mockResolvedValue({ customerId: 'cust-1', driverId: null }) };
    const relay = new OutboxRelayService(repo, fanout as never, push as never, rides as never);
    await expect(relay.relayOnce(10, now)).resolves.toBe(1);
    expect(fanout.emitRideUnassigned).toHaveBeenCalledWith('drv-1', expect.objectContaining({ rideId: 'r9', reasonCode: 'ASSIGNED_TIMEOUT' }));
    expect(fanout.emitSnapshot).toHaveBeenCalledWith(expect.objectContaining({ aggregateId: 'r9', status: 'NEGOTIATING' }));
    expect(push.send).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'drv-1',
      data: expect.objectContaining({ role: 'DRIVER', path: '/driver/jobs', reasonCode: 'ASSIGNED_TIMEOUT' }),
    }));
    expect(push.send).toHaveBeenCalledWith(expect.objectContaining({
      userId: 'cust-1',
      data: expect.objectContaining({ role: 'CUSTOMER', path: '/customer/ride/offers/r9' }),
    }));
  });
});
