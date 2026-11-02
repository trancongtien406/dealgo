import { describe, expect, it } from 'vitest';
import { PartnerService, autoApproveBlockers } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import {
  TINY_JPEG_BASE64,
  TINY_MP4_BASE64,
  TINY_PDF_BASE64,
  createTestDocumentStore,
} from '../../platform/storage/testing.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

const jpeg = (kind: string) => ({ kind, contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 });
const DRIVER_DOCS = [
  ...['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map(jpeg),
  { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: TINY_MP4_BASE64 },
] as never[];
const DRIVER_FIELDS = {
  vehicleClassCode: 'MOTORBIKE',
  licenseClass: 'A1',
  fullName: 'Nguyễn Văn A',
  birthDate: '1990-01-02',
  idNumber: '079090001234',
  licenseNumber: '790123456789',
  vehiclePlate: '59X1-123.45',
};
const MERCHANT_FIELDS = {
  registrationSubject: 'HOUSEHOLD',
  shopName: 'Quán Mẫu',
  shopAddress: '1 Lê Lợi, Q1',
  representativeName: 'Trần B',
  shopLat: 10.77,
  shopLng: 106.7,
};
const merchantDocs = (foodKind: string) =>
  [
    { kind: 'BUSINESS_LICENSE', contentType: 'application/pdf', contentBase64: TINY_PDF_BASE64 },
    jpeg(foodKind),
    jpeg('REP_ID_FRONT'),
    jpeg('REP_ID_BACK'),
  ] as never[];

async function setup(values: Record<string, unknown>) {
  const partners = new MemoryPartnerRepository();
  const identity = new MemoryIdentityRepository();
  const { store } = createTestDocumentStore();
  const user = await identity.createUser({ email: null, phone: '+84988771234', displayName: 'Auto' });
  await identity.updateUserProfile(user.id, { avatarUrl: 'https://cdn.example/auto.png' });
  const settings = {
    getJson: async (key: string) => (key in values ? values[key] : true),
  } as unknown as PlatformSettingsService;
  const service = new PartnerService(partners, identity, store, undefined, undefined, settings);
  return { partners, identity, user, service };
}

// t61u (DEC-PROD-070, AGENT_PROPOSED): admin toggle for system auto-approval.
describe('KYC/KYB auto-approve (t61u)', () => {
  it('OFF (default): a complete driver case stays SUBMITTED for manual review', async () => {
    const { service, user, partners } = await setup({ KYC_AUTO_APPROVE_DRIVER: false });
    const app = await service.submit(user.id, { role: 'DRIVER', metadata: DRIVER_FIELDS, documents: DRIVER_DOCS });
    expect(app.status).toBe('SUBMITTED');
    expect(partners.auditLogs).toEqual([]);
    expect((await service.requirements('DRIVER')).autoApprove).toBe(false);
  });

  it('ON: a complete, valid driver case is APPROVED by SYSTEM with audit + realtime + grant', async () => {
    const { service, user, partners, identity } = await setup({ KYC_AUTO_APPROVE_DRIVER: true });
    const app = await service.submit(user.id, { role: 'DRIVER', metadata: DRIVER_FIELDS, documents: DRIVER_DOCS });
    expect(app.status).toBe('APPROVED');
    expect(app.metadata.autoApproved).toBe(true);
    expect(partners.auditLogs.at(-1)).toMatchObject({
      action: 'KYC_AUTO_APPROVE',
      metadata: expect.objectContaining({ actor: 'SYSTEM' }),
    });
    expect(partners.statusEvents.map((e) => e.status)).toContain('APPROVED');
    const grants = await identity.listGrants(user.id);
    expect(grants.some((g) => g.role === 'DRIVER' && g.status === 'ACTIVE')).toBe(true);
  });

  it('ON but incomplete (missing fields / class mismatch) → manual queue with reasons', async () => {
    const { service, user } = await setup({ KYC_AUTO_APPROVE_DRIVER: true });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { ...DRIVER_FIELDS, licenseNumber: '', vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1', idNumber: '123' },
      documents: DRIVER_DOCS,
    });
    expect(app.status).toBe('SUBMITTED');
    expect(String(app.metadata.autoApproveSkipped)).toContain('FIELD_licenseNumber');
    expect(String(app.metadata.autoApproveSkipped)).toContain('ID_NUMBER_FORMAT');
  });

  it('a client cannot forge autoApproved metadata', async () => {
    const { service, user } = await setup({ KYC_AUTO_APPROVE_DRIVER: false });
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { ...DRIVER_FIELDS, autoApproved: true, autoApproveSkipped: 'x' },
      documents: DRIVER_DOCS,
    });
    expect(app.metadata.autoApproved).toBeUndefined();
    expect(app.metadata.autoApproveSkipped).toBeUndefined();
  });

  it('merchant toggle is separate; household may file the food-safety commitment', async () => {
    const { service, user } = await setup({ KYC_AUTO_APPROVE_DRIVER: true, KYC_AUTO_APPROVE_MERCHANT: true });
    const app = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: MERCHANT_FIELDS,
      documents: merchantDocs('FOOD_SAFETY_COMMITMENT'),
    });
    expect(app.status).toBe('APPROVED');
  });

  it('a company merchant still needs the food-safety certificate', async () => {
    const { service, user } = await setup({ KYC_AUTO_APPROVE_MERCHANT: false });
    await expect(
      service.submit(user.id, {
        role: 'MERCHANT',
        metadata: { ...MERCHANT_FIELDS, registrationSubject: 'COMPANY' },
        documents: merchantDocs('FOOD_SAFETY_COMMITMENT'),
      }),
    ).rejects.toMatchObject({ status: 400 });
    expect((await service.requirements('MERCHANT', undefined, 'HOUSEHOLD')).documentAlternatives).toEqual({
      FOOD_SAFETY_CERT: ['FOOD_SAFETY_COMMITMENT'],
    });
  });

  it('merchant without a shop pin is not auto-approved', () => {
    const { shopLat: _a, shopLng: _b, ...noPin } = MERCHANT_FIELDS;
    expect(autoApproveBlockers('MERCHANT', noPin, [])).toContain('SHOP_LOCATION');
  });

  it('a failed on-device capture check blocks auto-approval', () => {
    expect(autoApproveBlockers('DRIVER', { ...DRIVER_FIELDS, captureFaceLive: false }, [])).toContain(
      'DEVICE_captureFaceLive',
    );
  });

  it('reject puts reason + sections on the realtime status event', async () => {
    const { service, user, partners } = await setup({ KYC_AUTO_APPROVE_DRIVER: false });
    const app = await service.submit(user.id, { role: 'DRIVER', metadata: DRIVER_FIELDS, documents: DRIVER_DOCS });
    await service.claim(app.id, 'ops-1');
    await service.reject(app.id, 'ops-1', 'Ảnh mờ', [{ section: 'ID_CARD', note: 'Chụp lại' }]);
    expect(partners.statusEvents.at(-1)).toMatchObject({
      status: 'REJECTED',
      reason: 'Ảnh mờ',
      sections: ['ID_CARD'],
    });
  });
});
