import { describe, expect, it } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { TINY_JPEG_BASE64, TINY_MP4_BASE64, createTestDocumentStore } from '../../platform/storage/testing.js';
import { licenseClassCoversVehicle, requiredPartnerDocuments } from './partner.constants.js';

const jpeg = (kind: string) => ({ kind, contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 });
const DRIVER_DOCS = [
  ...['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map(jpeg),
  { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: TINY_MP4_BASE64 },
] as never[];
const SHOP = { shopName: 'Bun Bo', shopLat: 16.06, shopLng: 108.22 };

// t60u: food-safety certificate for merchants; licence class must cover the vehicle class.
describe('KYC required documents (t60u)', () => {
  const setup = async () => {
    const identity = new MemoryIdentityRepository();
    const user = await identity.createUser({ email: 't60u@dealgo.vn', phone: '+84988770060', displayName: 'T' });
    await identity.updateUserProfile(user.id, { avatarUrl: 'https://cdn.example/t.png' });
    const service = new PartnerService(new MemoryPartnerRepository(), identity, createTestDocumentStore().store);
    return { service, user };
  };

  it('merchant KYB requires FOOD_SAFETY_CERT', async () => {
    expect(requiredPartnerDocuments('MERCHANT')).toContain('FOOD_SAFETY_CERT');
    const { service, user } = await setup();
    await expect(
      service.submit(user.id, {
        role: 'MERCHANT',
        metadata: SHOP,
        documents: ['BUSINESS_LICENSE', 'REP_ID_FRONT', 'REP_ID_BACK'].map(jpeg) as never[],
      }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_DOCUMENTS_REQUIRED', details: { missing: ['FOOD_SAFETY_CERT'] } } });
    const ok = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: SHOP,
      documents: ['BUSINESS_LICENSE', 'FOOD_SAFETY_CERT', 'REP_ID_FRONT', 'REP_ID_BACK'].map(jpeg) as never[],
    });
    expect(ok.status).toBe('SUBMITTED');
  });

  it('maps licence classes to vehicle classes', () => {
    expect(licenseClassCoversVehicle('a1', 'MOTORBIKE')).toBe(true);
    expect(licenseClassCoversVehicle('A1', 'CAR_4')).toBe(false);
    expect(licenseClassCoversVehicle('B2', 'CAR_7')).toBe(true);
    expect(licenseClassCoversVehicle('B', 'MOTORBIKE')).toBe(false);
    expect(licenseClassCoversVehicle(undefined, 'MOTORBIKE')).toBe(false);
  });

  it('rejects a CAR_4 driver who declares a motorbike licence, accepts class B', async () => {
    const { service, user } = await setup();
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'CAR_4', licenseClass: 'A1' }, documents: DRIVER_DOCS }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_LICENSE_CLASS_MISMATCH' } });
    await expect(
      service.submit(user.id, { role: 'DRIVER', metadata: { vehicleClassCode: 'CAR_4' }, documents: DRIVER_DOCS }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_LICENSE_CLASS_MISMATCH' } });
    const ok = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4', licenseClass: 'B' },
      documents: DRIVER_DOCS,
    });
    expect(ok.status).toBe('SUBMITTED');
  });

  it('ops cannot approve into a class the declared licence does not cover', async () => {
    const { service, user } = await setup();
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1' },
      documents: DRIVER_DOCS,
    });
    await expect(service.approve(app.id, 'ops-1', 'CAR_4')).rejects.toMatchObject({
      response: { errorCode: 'PARTNER_LICENSE_CLASS_MISMATCH' },
    });
    expect((await service.approve(app.id, 'ops-1')).status).toBe('APPROVED');
  });
});
