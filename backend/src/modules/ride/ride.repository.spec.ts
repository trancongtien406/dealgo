import { describe, expect, it } from 'vitest';
import { MemoryRideRepository } from './ride.repository.js';
import type { CreateRideInput } from './ride-ledger.js';

describe('MemoryRideRepository', () => {
  const now = new Date('2026-10-16T12:00:00.000Z');
  const future = new Date('2026-10-16T12:30:00.000Z');

  const makeInput = (customerId: string, idempotencyKey: string): CreateRideInput => ({
    customerId,
    idempotencyKey,
    pickup: { lat: 10.7769, lng: 106.7009, label: 'Ben Thanh, D1' },
    dropoff: { lat: 10.8231, lng: 106.6297, label: 'Airport, Tan Binh' },
    offeredFareVnd: 75_000,
    vehicleClassCode: 'MOTORBIKE',
    referenceFareVnd: 70_000,
    expiresAt: future,
    now,
  });

  it('creates and finds a ride by id', async () => {
    const repo = new MemoryRideRepository();
    const created = await repo.create(makeInput('cust-1', 'idem-1'));

    expect(created.id).toBeDefined();
    expect(created.status).toBe('NEGOTIATING');

    const found = await repo.findById(created.id, now);
    expect(found).not.toBeNull();
    expect(found?.id).toBe(created.id);
    expect(found?.customerId).toBe('cust-1');
  });

  it('lists open rides for dispatching drivers', async () => {
    const repo = new MemoryRideRepository();
    await repo.create(makeInput('cust-1', 'idem-1'));
    await repo.create(makeInput('cust-2', 'idem-2'));

    const openList = await repo.listOpen(now, 10);
    expect(openList).toHaveLength(2);
    expect(openList[0].status).toBe('NEGOTIATING');
  });

  it('persists a dismissal per ride and driver and filters only that driver', async () => {
    const repo = new MemoryRideRepository();
    const ride = await repo.create(makeInput('cust-1', 'idem-1'));

    await repo.dismissRequest(ride.id, 'driver-c', now);
    await repo.dismissRequest(ride.id, 'driver-c', now);

    await expect(repo.dismissedRequestIds('driver-c', [ride.id])).resolves.toEqual(
      new Set([ride.id]),
    );
    await expect(repo.dismissedRequestIds('driver-d', [ride.id])).resolves.toEqual(new Set());
    await expect(repo.undismissedDriverIds(ride.id, ['driver-c', 'driver-d'])).resolves.toEqual([
      'driver-d',
    ]);
  });

  it('paginates customer ride history', async () => {
    const repo = new MemoryRideRepository();
    await repo.create(makeInput('cust-1', 'idem-1'));

    const page1 = await repo.listForCustomer('cust-1', 1, 10, now);
    expect(page1.total).toBe(1);
    expect(page1.items).toHaveLength(1);

    const emptyCust = await repo.listForCustomer('other-cust', 1, 10, now);
    expect(emptyCust.total).toBe(0);
    expect(emptyCust.items).toHaveLength(0);
  });

  it('performs ops interventions with audit result', async () => {
    const repo = new MemoryRideRepository();
    const created = await repo.create(makeInput('cust-1', 'idem-1'));

    const cancelResult = await repo.opsCancel(
      { rideId: created.id, now },
      'ops-admin-1',
      'Customer request by phone',
    );

    expect(cancelResult.ride.status).toBe('CANCELLED');
    expect(cancelResult.auditId).toContain('cancel');
  });
});
