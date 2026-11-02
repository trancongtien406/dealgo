import { describe, expect, it } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { TINY_JPEG_BASE64, createTestDocumentStore } from '../../platform/storage/testing.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

/** DEC-PROD-048 (DRAFT): admin switch to waive KYC/KYB documents; ops still approves. */
function settingsStub(values: Record<string, unknown>): PlatformSettingsService {
  return {
    getJson: async (key: string) => (key in values ? values[key] : true),
    getBoolean: async (key: string) => (key in values ? values[key] : true) === true,
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
  await identity.updateUserProfile(user.id, { avatarUrl: 'https://cdn.example/kyc-off.png' });
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

  it('DEC-PROD-091: refuses a driver application until the profile has an avatar', async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const user = await identity.createUser({ email: null, phone: '+84988770091', displayName: 'No Photo' });
    const service = new PartnerService(
      partners,
      identity,
      createTestDocumentStore().store,
      undefined,
      undefined,
      settingsStub({ ONBOARDING_DRIVER_KYC_REQUIRED: false, DRIVER_CAR_EXTRA_DOCS_REQUIRED: false }),
    );
    const submit = () => service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'MOTORBIKE' } });
    await expect(submit()).rejects.toMatchObject({
      status: 400,
      response: { errorCode: 'PARTNER_AVATAR_REQUIRED' },
    });
    expect(await partners.findByUserAndRole(user.id, 'DRIVER')).toBeNull();

    await identity.updateUserProfile(user.id, { avatarUrl: '   ' });
    await expect(submit()).rejects.toMatchObject({ response: { errorCode: 'PARTNER_AVATAR_REQUIRED' } });

    await identity.updateUserProfile(user.id, { avatarUrl: 'https://cdn.example/me.png' });
    await expect(submit()).resolves.toMatchObject({ status: 'SUBMITTED' });
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
    const { service, user } = await setup({
      ONBOARDING_DRIVER_KYC_REQUIRED: false,
      DRIVER_CAR_EXTRA_DOCS_REQUIRED: false,
    });
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

  it('t88u: quick mode drops the app-default licence so a car driver can be approved', async () => {
    const { service, user } = await setup({
      ONBOARDING_DRIVER_KYC_REQUIRED: false,
      DRIVER_CAR_EXTRA_DOCS_REQUIRED: false,
    });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4', licenseClass: 'A1', licenseNumber: '123456' },
    });
    expect(app.metadata.licenseClass).toBeUndefined();
    expect(app.metadata.licenseNumber).toBeUndefined();
    expect((await service.approve(app.id, 'ops-1')).status).toBe('APPROVED');
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
    const { service, user } = await setup({
      ONBOARDING_DRIVER_KYC_REQUIRED: false,
      DRIVER_CAR_EXTRA_DOCS_REQUIRED: false,
    });
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

  it('t90u: quick mode still asks a car driver for VEHICLE_INSURANCE while the gate is on', async () => {
    const { service, user } = await setup({ ONBOARDING_DRIVER_KYC_REQUIRED: false });
    expect((await service.requirements('DRIVER', 'CAR_4')).requiredDocuments).toEqual(['VEHICLE_INSURANCE']);
    expect((await service.requirements('DRIVER', 'MOTORBIKE')).requiredDocuments).toEqual([]);
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'CAR_4' } }),
    ).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_DOCUMENTS_REQUIRED', details: { missing: ['VEHICLE_INSURANCE'] } },
    });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
      documents: [{ kind: 'VEHICLE_INSURANCE', contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 }],
    });
    expect((await service.approve(app.id, 'ops-1')).status).toBe('APPROVED');
  });

  it('t90u: approve refuses a car application without car documents while the gate is on', async () => {
    const { service, user } = await setup({
      ONBOARDING_DRIVER_KYC_REQUIRED: false,
      DRIVER_CAR_EXTRA_DOCS_REQUIRED: false,
    });
    const app = await service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'MOTORBIKE' } });
    const gated = new PartnerService(
      (service as unknown as { partners: MemoryPartnerRepository }).partners,
      new MemoryIdentityRepository(),
      createTestDocumentStore().store,
      undefined,
      undefined,
      settingsStub({ ONBOARDING_DRIVER_KYC_REQUIRED: false }),
    );
    await expect(gated.approve(app.id, 'ops-1', 'CAR_4')).rejects.toMatchObject({
      status: 400,
      response: { errorCode: 'PARTNER_CAR_DOCS_REQUIRED', details: { missing: ['VEHICLE_INSURANCE'] } },
    });
    // Admin turns the gate off → the same approval goes through.
    expect((await service.approve(app.id, 'ops-1', 'CAR_4')).status).toBe('APPROVED');
  });

  it('t90u: an approved car driver missing insurance can resubmit it and returns to review', async () => {
    const { service, user } = await setup({
      ONBOARDING_DRIVER_KYC_REQUIRED: false,
      DRIVER_CAR_EXTRA_DOCS_REQUIRED: false,
    });
    const app = await service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'CAR_4' } });
    await service.approve(app.id, 'ops-1');
    // Gate off: nothing to top up → still refused as already approved.
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'CAR_4' } }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_APPLICATION_ALREADY_APPROVED' } });
    const gated = new PartnerService(
      (service as unknown as { partners: MemoryPartnerRepository }).partners,
      new MemoryIdentityRepository(),
      createTestDocumentStore().store,
      undefined,
      undefined,
      settingsStub({ ONBOARDING_DRIVER_KYC_REQUIRED: false }),
    );
    const again = await gated.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4' },
      documents: [{ kind: 'VEHICLE_INSURANCE', contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 }],
    });
    expect(again.status).toBe('SUBMITTED');
  });
});

