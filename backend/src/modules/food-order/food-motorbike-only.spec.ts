import { describe, expect, it, vi } from 'vitest';
import { FoodService } from './food.service.js';
import { PartnerEligibilityService } from '../partner/partner-eligibility.service.js';

/** FOOD jobs: MOTORBIKE drivers only, fail closed on car or unknown class. */
function food(canDeliver: boolean) {
  const svc = Object.create(FoodService.prototype) as FoodService;
  const repo = {
    listReady: vi.fn().mockResolvedValue([]),
    claim: vi.fn(),
    findOrder: vi.fn().mockResolvedValue({ id: 'o1', status: 'READY', customerId: 'c', ownerId: 'm', assignedDriverId: null }),
  };
  Object.assign(svc, {
    food: repo,
    eligibility: {
      requireEligibleDriver: vi.fn().mockResolvedValue(undefined),
      canDeliverFood: vi.fn().mockResolvedValue(canDeliver),
    },
    settings: { getBoolean: vi.fn().mockResolvedValue(false), getNumber: vi.fn().mockResolvedValue(5) },
    identity: { listGrants: vi.fn().mockResolvedValue([{ role: 'DRIVER', status: 'ACTIVE' }]) },
  });
  (svc as unknown as { hasActiveGrant: () => Promise<boolean> }).hasActiveGrant = async () => true;
  return { svc, repo };
}
const actor = { userId: 'd1' } as never;

describe('FOOD motorbike-only gate', () => {
  it('car driver: empty ready list, claim refused 403 before touching the order, no READY room', async () => {
    const { svc, repo } = food(false);
    await expect(svc.listReady(actor)).resolves.toEqual([]);
    expect(repo.listReady).not.toHaveBeenCalled();
    await expect(svc.claim(actor, 'o1')).rejects.toMatchObject({
      response: expect.objectContaining({ errorCode: 'FOOD_VEHICLE_NOT_ALLOWED' }),
    });
    expect(repo.claim).not.toHaveBeenCalled();
    await expect(svc.canSubscribe('d1', 'o1')).resolves.toBe(false);
  });

  it('motorbike driver may join the READY room', async () => {
    const { svc } = food(true);
    await expect(svc.canSubscribe('d1', 'o1')).resolves.toBe(true);
  });
});

describe('PartnerEligibilityService.canDeliverFood', () => {
  function elig(metadata: unknown, status = 'APPROVED') {
    const svc = Object.create(PartnerEligibilityService.prototype) as PartnerEligibilityService;
    Object.assign(svc, {
      partners: { findByUserAndRole: vi.fn().mockResolvedValue(metadata === undefined ? null : { status, metadata }) },
      config: { get: vi.fn().mockReturnValue('false') },
    });
    (svc as unknown as { bypassEnabled: () => boolean }).bypassEnabled = () => false;
    return svc;
  }
  it('true only for an approved MOTORBIKE driver', async () => {
    await expect(elig({ vehicleClassCode: 'MOTORBIKE' }).canDeliverFood('u')).resolves.toBe(true);
    await expect(elig({ vehicleClassCode: 'CAR_4' }).canDeliverFood('u')).resolves.toBe(false);
    await expect(elig({ vehicleClassCode: 'CAR_7' }).canDeliverFood('u')).resolves.toBe(false);
    await expect(elig({}).canDeliverFood('u')).resolves.toBe(false);
    await expect(elig(undefined).canDeliverFood('u')).resolves.toBe(false);
    await expect(elig({ vehicleClassCode: 'MOTORBIKE' }, 'SUBMITTED').canDeliverFood('u')).resolves.toBe(false);
  });
});
