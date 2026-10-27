import { describe, expect, it } from 'vitest';
import {
  MemoryRideVehicleClassRepository,
  rideVehicleClassAuditId,
} from './ride-vehicle-class.repository.js';
import { RideVehicleClassService, diffVehicleClass } from './ride-vehicle-class.service.js';

function makeService() {
  const repo = new MemoryRideVehicleClassRepository();
  const fares: Record<string, number> = { RIDE_MIN_FARE_VND: 15_000, RIDE_MAX_FARE_VND: 2_000_000, RIDE_REFERENCE_VND_PER_KM: 8_000 };
  const settings = { getNumber: async (key: string) => fares[key] } as never;
  const uploads = { discard: async () => undefined } as never;
  return { repo, service: new RideVehicleClassService(repo, settings, uploads) };
}

describe('ride vehicle class audit', () => {
  it('derives a stable UUID per class code', () => {
    const id = rideVehicleClassAuditId('CAR_4');
    expect(id).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    expect(rideVehicleClassAuditId('CAR_4')).toBe(id);
    expect(rideVehicleClassAuditId('CAR_7')).not.toBe(id);
  });

  it('lists only the fields that changed', () => {
    const current = { code: 'X', name: 'A', seats: 4, perKmVnd: 10 } as never;
    expect(diffVehicleClass(current, { name: 'A', seats: 7, perKmVnd: 10 })).toEqual({
      seats: { from: 4, to: 7 },
    });
  });

  it('records actor, reason and before/after on update', async () => {
    const { repo, service } = makeService();
    const [first] = await service.listAll();
    expect(first).toBeDefined();
    await service.update(first!.code, { perKmVnd: first!.perKmVnd + 1000, reason: 'Điều chỉnh giá' }, 'ops-1');
    expect(repo.audits).toHaveLength(1);
    expect(repo.audits[0]).toMatchObject({
      code: first!.code,
      actorUserId: 'ops-1',
      reason: 'Điều chỉnh giá',
      changes: { perKmVnd: { from: first!.perKmVnd, to: first!.perKmVnd + 1000 } },
    });
  });

  it('records image removal', async () => {
    const { repo, service } = makeService();
    const [first] = await service.listAll();
    await service.clearImage(first!.code, 'ops-2');
    expect(repo.audits.at(-1)).toMatchObject({
      actorUserId: 'ops-2',
      reason: 'Xoá ảnh hạng xe',
      changes: { imageUrl: { to: null } },
    });
  });
});
