import { describe, expect, it } from 'vitest';
import { DriverWorkloadService } from './driver-workload.service.js';

const settings = (max: number) => ({ getNumber: async () => max }) as never;
const source = (counts: Record<string, number>) => ({
  activeJobCounts: async (ids: readonly string[]) => new Map(ids.map((id) => [id, counts[id] ?? 0])),
});

describe('DriverWorkloadService (t71u busy driver)', () => {
  it('drops drivers with an active ride/parcel/food job from the audience, keeping order', async () => {
    const svc = new DriverWorkloadService(undefined, settings(1));
    svc.useSource(source({ busy: 1 }));
    expect(await svc.availableOnly(['a', 'busy', 'b'])).toEqual(['a', 'b']);
    expect(await svc.isBusy('busy')).toBe(true);
    expect(await svc.isBusy('a')).toBe(false);
  });

  it('honours MAX_CONCURRENT_JOBS_PER_DRIVER above 1', async () => {
    const svc = new DriverWorkloadService(undefined, settings(2));
    svc.useSource(source({ one: 1, two: 2 }));
    expect(await svc.availableOnly(['one', 'two'])).toEqual(['one']);
  });

  it('rejects an offer from a busy driver with 409 DRIVER_AT_CAPACITY', async () => {
    const svc = new DriverWorkloadService(undefined, settings(1));
    svc.useSource(source({ busy: 1 }));
    await expect(svc.assertAvailable('busy')).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ errorCode: 'DRIVER_AT_CAPACITY' }),
    });
    await expect(svc.assertAvailable('free')).resolves.toBeUndefined();
  });

  it('treats a missing/invalid setting as 1 job (fail closed)', async () => {
    const svc = new DriverWorkloadService(undefined, { getNumber: async () => Number.NaN } as never);
    svc.useSource(source({ x: 1 }));
    expect(await svc.isBusy('x')).toBe(true);
  });
});
