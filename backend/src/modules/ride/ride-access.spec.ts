import { describe, expect, it, vi } from 'vitest';
import { RideService } from './ride.service.js';

type Grant = { role: string; status: string };

function build(opts: { grants: Grant[]; driverClass?: string | null; eligibilityThrows?: boolean }) {
  const ride = {
    id: 'ride-1',
    customerId: 'owner',
    assignedDriverId: null as string | null,
    status: 'NEGOTIATING',
    vehicleClassCode: 'CAR_4',
  };
  const rides = { findById: vi.fn().mockResolvedValue(ride) };
  const identity = { listGrants: vi.fn().mockResolvedValue(opts.grants) };
  const clock = { now: () => new Date('2026-10-24T00:00:00Z') };
  const eligibility = {
    driverVehicleClassCode: opts.eligibilityThrows
      ? vi.fn().mockRejectedValue(new Error('db down'))
      : vi.fn().mockResolvedValue(opts.driverClass ?? null),
  };
  const u = undefined as never;
  const svc = new RideService(rides as never, identity as never, clock as never, u, u, u, eligibility as never, u, u, u, u, u, u, u);
  return { svc, ride };
}

describe('RideService.canSubscribe (ride:<id> room / IDOR)', () => {
  it('owner may join', async () => {
    const { svc } = build({ grants: [{ role: 'CUSTOMER', status: 'ACTIVE' }] });
    expect(await svc.canSubscribe('owner', 'ride-1')).toBe(true);
  });

  it('another customer without DRIVER grant is denied', async () => {
    const { svc } = build({ grants: [{ role: 'CUSTOMER', status: 'ACTIVE' }] });
    expect(await svc.canSubscribe('intruder', 'ride-1')).toBe(false);
  });

  it('suspended DRIVER grant is denied even with matching class', async () => {
    const { svc } = build({ grants: [{ role: 'DRIVER', status: 'SUSPENDED' }], driverClass: 'CAR_4' });
    expect(await svc.canSubscribe('intruder', 'ride-1')).toBe(false);
  });

  it('active driver of a different class is denied', async () => {
    const { svc } = build({ grants: [{ role: 'DRIVER', status: 'ACTIVE' }], driverClass: 'MOTORBIKE' });
    expect(await svc.canSubscribe('d', 'ride-1')).toBe(false);
  });

  it('active same-class driver may read a NEGOTIATING ride (by design)', async () => {
    const { svc } = build({ grants: [{ role: 'DRIVER', status: 'ACTIVE' }], driverClass: 'CAR_4' });
    expect(await svc.canSubscribe('d', 'ride-1')).toBe(true);
  });

  it('fails closed when eligibility lookup throws', async () => {
    const { svc } = build({ grants: [{ role: 'DRIVER', status: 'ACTIVE' }], eligibilityThrows: true });
    expect(await svc.canSubscribe('d', 'ride-1')).toBe(false);
  });

  it('non-assigned driver denied once ride left NEGOTIATING', async () => {
    const { svc, ride } = build({ grants: [{ role: 'DRIVER', status: 'ACTIVE' }], driverClass: 'CAR_4' });
    ride.status = 'DRIVER_ASSIGNED';
    ride.assignedDriverId = 'someone-else';
    expect(await svc.canSubscribe('d', 'ride-1')).toBe(false);
  });
});
