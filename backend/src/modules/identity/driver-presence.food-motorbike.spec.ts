import { describe, expect, it } from 'vitest';
import { MemoryDriverPresenceRepository } from './driver-presence.repository.js';
import { DriverPresenceService } from './driver-presence.service.js';

/** DEC-PROD-071: presence never stores foodEnabled=true for a non-motorbike driver. */
describe('DriverPresenceService.upsert FOOD motorbike-only', () => {
  function setup(bikes: string[]) {
    const repo = new MemoryDriverPresenceRepository();
    const moduleRef = {
      get: () => ({ canDeliverFood: async (id: string) => bikes.includes(id) }),
    };
    const svc = new DriverPresenceService(repo, {} as never, undefined, undefined, moduleRef as never);
    // requireActiveDriver is covered elsewhere; bypass it here.
    (svc as unknown as { requireActiveDriver: () => Promise<void> }).requireActiveDriver = async () => {};
    return svc;
  }

  it('defaults food OFF for a car driver and refuses to turn it on', async () => {
    const svc = setup(['bike']);
    expect((await svc.upsert('car', { online: true })).foodEnabled).toBe(false);
    expect((await svc.upsert('car', { online: true, foodEnabled: true })).foodEnabled).toBe(false);
  });

  it('keeps the default ON and honours the switch for a motorbike driver', async () => {
    const svc = setup(['bike']);
    expect((await svc.upsert('bike', { online: true })).foodEnabled).toBe(true);
    expect((await svc.upsert('bike', { online: true, foodEnabled: false })).foodEnabled).toBe(false);
  });

  it('fails closed when the eligibility check throws', async () => {
    const repo = new MemoryDriverPresenceRepository();
    const moduleRef = { get: () => ({ canDeliverFood: async () => { throw new Error('db'); } }) };
    const svc = new DriverPresenceService(repo, {} as never, undefined, undefined, moduleRef as never);
    (svc as unknown as { requireActiveDriver: () => Promise<void> }).requireActiveDriver = async () => {};
    expect((await svc.upsert('x', { online: true, foodEnabled: true })).foodEnabled).toBe(false);
  });
});
