import { describe, expect, it } from 'vitest';
import type { RideVehicleClass } from './ride-vehicle-class.js';
import { MemoryRideZoneTariffRepository } from './ride-zone-tariff.repository.js';
import { applyZoneTariff, RideZoneTariffService } from './ride-zone-tariff.service.js';
import type { RideVehicleClassService } from './ride-vehicle-class.service.js';

const bike = {
  code: 'MOTORBIKE',
  name: 'Xe máy',
  perKmVnd: 5000,
  minFareVnd: 10_000,
  maxFareVnd: 500_000,
} as unknown as RideVehicleClass;

function service() {
  const repo = new MemoryRideZoneTariffRepository();
  const classes = {
    findAny: async (code: string) => (code.toUpperCase() === 'MOTORBIKE' ? bike : null),
    listAll: async () => [bike],
  } as unknown as RideVehicleClassService;
  return { repo, svc: new RideZoneTariffService(repo, classes) };
}

describe('zone tariff resolution', () => {
  it('no override -> global default', () => {
    const r = applyZoneTariff(bike, 'DN', undefined);
    expect(r.tariff).toMatchObject({ source: 'DEFAULT', regionCode: 'DN', version: 0, perKmVnd: 5000 });
    expect(r.vehicle).toBe(bike);
  });

  it('override wins and min fare never exceeds class max', () => {
    const r = applyZoneTariff(bike, 'HN', {
      id: 'x', regionCode: 'HN', vehicleClassCode: 'MOTORBIKE', perKmVnd: 7000, minFareVnd: 900_000,
      version: 3, updatedByUserId: null, updatedAt: new Date(),
    });
    expect(r.vehicle.perKmVnd).toBe(7000);
    expect(r.vehicle.minFareVnd).toBe(500_000);
    expect(r.tariff).toMatchObject({ source: 'ZONE', version: 3 });
  });

  it('pickup inside a zone uses its override; outside every zone falls back', async () => {
    const { svc } = service();
    await svc.upsert('DN', 'MOTORBIKE', { perKmVnd: 6000, minFareVnd: 11_000 }, 'ops');
    const inside = await svc.resolve(bike, { lat: 16.0544, lng: 108.2022 });
    expect(inside.tariff).toMatchObject({ source: 'ZONE', regionCode: 'DN', perKmVnd: 6000, version: 1 });
    const outside = await svc.resolve(bike, { lat: 0, lng: 0 });
    expect(outside.tariff).toMatchObject({ source: 'DEFAULT', regionCode: null, perKmVnd: 5000 });
    const otherZone = await svc.resolve(bike, { lat: 21.0278, lng: 105.8342 });
    expect(otherZone.tariff.source).toBe('DEFAULT');
  });

  it('edits bump version, are audited, and reject no-op', async () => {
    const { svc, repo } = service();
    await svc.upsert('DN', 'MOTORBIKE', { perKmVnd: 6000, minFareVnd: 11_000 }, 'ops');
    const second = await svc.upsert('DN', 'MOTORBIKE', { perKmVnd: 6500, minFareVnd: 11_000, reason: 'r' }, 'ops');
    expect(second.version).toBe(2);
    expect(repo.audits).toHaveLength(2);
    expect(repo.audits[1]).toMatchObject({ reason: 'r', changes: { perKmVnd: { from: 6000, to: 6500 } } });
    await expect(svc.upsert('DN', 'MOTORBIKE', { perKmVnd: 6500, minFareVnd: 11_000 }, 'ops')).rejects.toMatchObject({ status: 400 });
  });

  it('snapshot is write-once (idempotent replay keeps the first lock)', async () => {
    const { svc } = service();
    const base = { rideId: 'r1', regionCode: 'DN', tariffSource: 'DEFAULT' as const, zoneTariffId: null, tariffVersion: 0, perKmVnd: 5000, minFareVnd: 10_000, bidFloorPercent: 70, bidCeilingPercent: 130 };
    await svc.saveSnapshot(base);
    await svc.saveSnapshot({ ...base, bidCeilingPercent: 200 });
    expect((await svc.findSnapshot('r1'))?.bidCeilingPercent).toBe(130);
    expect(svc.applySnapshot(bike, { ...base, perKmVnd: 9000 }).perKmVnd).toBe(9000);
  });
});
