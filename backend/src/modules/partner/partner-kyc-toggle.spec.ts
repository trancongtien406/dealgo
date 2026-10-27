import { describe, expect, it } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { createTestDocumentStore } from '../../platform/storage/testing.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

/** DEC-PROD-048 (DRAFT): admin switch to waive KYC/KYB documents; ops still approves. */
function settingsStub(values: Record<string, unknown>): PlatformSettingsService {
  return {
    getJson: async (key: string) => (key in values ? values[key] : true),
  } as unknown as PlatformSettingsService;
}

async function setup(values: Record<string, unknown>) {
  const partners = new MemoryPartnerRepository();
  const identity = new MemoryIdentityRepository();
  const { store } = createTestDocumentStore();
  const user = await identity.createUser({
    email: 'kyc-off@dealgo.vn',
    phone: '+84988770001',
    displayName: 'KYC Off',
  });
  const service = new PartnerService(
    partners,
    identity,
    store,
    undefined,
    undefined,
    settingsStub(values),
  );
  return { service, user };
}

describe('PartnerService KYC/KYB switch (DEC-PROD-048)', () => {
  it('requires documents by default (fail closed)', async () => {
    const { service, user } = await setup({});
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'MOTORBIKE' } }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_DOCUMENTS_REQUIRED' } });
    const req = await service.requirements('MERCHANT');
    expect(req.documentsRequired).toBe(true);
    expect(req.requiredDocuments.length).toBeGreaterThan(0);
  });

  it('treats a missing settings service as required', async () => {
    const service = new PartnerService(
      new MemoryPartnerRepository(),
      new MemoryIdentityRepository(),
      createTestDocumentStore().store,
    );
    expect(await service.documentsRequired('DRIVER')).toBe(true);
  });

  it('accepts a driver without documents when OFF but still requires a vehicle class', async () => {
    const { service, user } = await setup({ ONBOARDING_DRIVER_KYC_REQUIRED: false });
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: {} }),
    ).rejects.toMatchObject({ response: { errorCode: 'VALIDATION_ERROR' } });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
    });
    expect(app.status).toBe('SUBMITTED');
    expect(app.metadata.documentsWaived).toBe(true);
    expect((await service.requirements('DRIVER')).requiredDocuments).toEqual([]);
  });

  it('never auto-approves: application stays SUBMITTED until ops approves', async () => {
    const { service, user } = await setup({ ONBOARDING_MERCHANT_KYB_REQUIRED: false });
    const app = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: { storeName: 'Quán thử', shopLat: 16.06, shopLng: 108.22 },
    });
    expect(app.status).toBe('SUBMITTED');
    const approved = await service.approve(app.id, user.id);
    expect(approved.status).toBe('APPROVED');
  });

  it('A shop application needs a map pin inside Vietnam even when KYB is off', async () => {
    const { service, user } = await setup({ ONBOARDING_MERCHANT_KYB_REQUIRED: false });
    await expect(
      service.submit(user.id, { role: 'MERCHANT', metadata: { storeName: 'Quán thử' } }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_SHOP_LOCATION_REQUIRED' } });
    await expect(
      service.submit(user.id, {
        role: 'MERCHANT',
        metadata: { storeName: 'Quán thử', shopLat: 48.85, shopLng: 2.35 },
      }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_SHOP_LOCATION_REQUIRED' } });
  });

  it('lets ops assign the vehicle class on approval', async () => {
    const { service, user } = await setup({ ONBOARDING_DRIVER_KYC_REQUIRED: false });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE' },
    });
    const approved = await service.approve(app.id, user.id, 'car_4');
    expect(approved.metadata.vehicleClassCode).toBe('CAR_4');
    expect(approved.metadata.vehicleClassConfirmedBy).toBe(user.id);
  });

  it('refuses an approval with an invalid vehicle class', async () => {
    const { service, user } = await setup({ ONBOARDING_DRIVER_KYC_REQUIRED: false });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE' },
    });
    await expect(service.approve(app.id, user.id, 'TRUCK')).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_VEHICLE_CLASS_REQUIRED' },
    });
  });
});
