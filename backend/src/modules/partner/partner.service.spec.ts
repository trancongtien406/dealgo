import { describe, expect, it } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import {
  TINY_JPEG_BASE64,
  TINY_PDF_BASE64,
  createTestDocumentStore,
} from '../../platform/storage/testing.js';

const jpeg = (kind: string) => ({ kind, contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 });

const DRIVER_DOCS = ['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map((kind) =>
  jpeg(kind),
) as never[];
const MERCHANT_DOCS = [
  { kind: 'BUSINESS_LICENSE', contentType: 'application/pdf', contentBase64: TINY_PDF_BASE64 },
  jpeg('REP_ID_FRONT'),
  jpeg('REP_ID_BACK'),
] as never[];

describe('PartnerService', () => {
  const createService = async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store, storage } = createTestDocumentStore();

    const user = await identity.createUser({
      email: 'driver@dealgo.vn',
      phone: '+84988776655',
      displayName: 'Tran Tai Xe',
    });

    const service = new PartnerService(partners, identity, store);
    return { service, partners, identity, user, storage };
  };

  it('submits a partner application with stored documents and lists it for user', async () => {
    const { service, user, storage } = await createService();

    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: {
        vehicleClassCode: 'MOTORBIKE',
        vehiclePlate: '51F-12345',
        vehicleModel: 'Honda Wave',
      },
      documents: DRIVER_DOCS,
    });

    expect(app.status).toBe('SUBMITTED');
    expect(app.documents.map((doc) => doc.kind)).toEqual([
      'ID_FRONT',
      'ID_BACK',
      'SELFIE',
      'LICENSE',
      'VEHICLE_REG',
    ]);
    expect(app.documents.every((doc) => doc.hasFile && doc.contentType === 'image/jpeg')).toBe(true);
    expect(storage.size).toBe(5);

    const file = await service.readDocumentForOps(app.id, 3);
    expect(file.contentType).toBe('image/jpeg');
    expect(file.body.toString('base64')).toBe(TINY_JPEG_BASE64);
    expect(file.filename).toBe('license-3.jpg');

    const mine = await service.listMine(user.id);
    expect(mine.applications).toHaveLength(1);
    expect(mine.applications[0].id).toBe(app.id);
  });

  it('refuses a submission without the required documents and stores nothing', async () => {
    const { service, user, storage } = await createService();
    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: DRIVER_DOCS.slice(0, 2),
      }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_DOCUMENTS_REQUIRED' } });
    expect(storage.size).toBe(0);
  });

  it('refuses DRIVER submit without a valid vehicleClassCode (fail closed)', async () => {
    const { service, user, storage } = await createService();
    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehiclePlate: '51F-12345' },
        documents: DRIVER_DOCS,
      }),
    ).rejects.toMatchObject({ response: { errorCode: 'VALIDATION_ERROR' } });
    expect(storage.size).toBe(0);
  });

  it('refuses a file whose bytes do not match its declared type', async () => {
    const { service, user } = await createService();
    const docs = [...DRIVER_DOCS] as Array<Record<string, string>>;
    docs[0] = { kind: 'ID_FRONT', contentType: 'image/png', contentBase64: TINY_JPEG_BASE64 };
    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: docs as never[],
      }),
    ).rejects.toMatchObject({ status: 415 });
  });

  it('approves an application and activates role grant', async () => {
    const { service, identity, user } = await createService();

    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', vehiclePlate: '51F-12345' },
      documents: DRIVER_DOCS,
    });

    const reviewed = await service.approve(app.id, 'ops-approver');

    expect(reviewed.status).toBe('APPROVED');
    expect(reviewed.reviewedBy).toBe('ops-approver');

    const directory = await identity.findUserDirectory(user.id);
    const driverGrant = directory?.grants.find((g) => g.role === 'DRIVER');
    expect(driverGrant?.status).toBe('ACTIVE');
    await expect(service.reject(app.id, 'ops-2', 'late')).rejects.toMatchObject({ status: 409 });
  });

  it('rejects with section issues; a resubmission re-sends only the flagged document', async () => {
    const { service, identity, user, storage } = await createService();

    const app = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: { shopName: 'Quán ăn chưa đăng ký', shopLat: 16.06, shopLng: 108.22 },
      documents: MERCHANT_DOCS,
    });

    const reviewed = await service.reject(app.id, 'ops-approver', 'Cần bổ sung giấy tờ', [
      { section: 'BUSINESS_DOCS', note: 'Giấy phép kinh doanh bị mờ' },
    ]);

    expect(reviewed.status).toBe('REJECTED');
    expect(reviewed.issues).toEqual([
      { section: 'BUSINESS_DOCS', note: 'Giấy phép kinh doanh bị mờ' },
    ]);
    const mine = await service.getMine(user.id, 'MERCHANT');
    expect(mine.issues).toHaveLength(1);

    const directory = await identity.findUserDirectory(user.id);
    expect(directory?.grants.find((g) => g.role === 'MERCHANT')?.status).toBe('SUSPENDED');

    await expect(
      service.reject(app.id, 'ops', 'x', [{ section: 'VEHICLE' as never, note: 'n' }]),
    ).rejects.toMatchObject({ status: 409 });

    const resubmitted = await service.submit(user.id, {
      role: 'MERCHANT',
      metadata: { shopName: 'Quán ăn đã đăng ký', shopLat: 16.06, shopLng: 108.22 },
      documents: [MERCHANT_DOCS[0]!],
    });
    expect(resubmitted.status).toBe('SUBMITTED');
    expect(resubmitted.issues).toEqual([]);
    expect(resubmitted.reason).toBeNull();
    expect(resubmitted.documents.map((doc) => doc.kind)).toEqual([
      'BUSINESS_LICENSE',
      'REP_ID_FRONT',
      'REP_ID_BACK',
    ]);
    // The replaced REP_ID_BACK file is discarded; only referenced files remain (DEC-PROD-021).
    expect(storage.size).toBe(3);
  });

  it('rejects issue sections that do not belong to the role', async () => {
    const { service, user } = await createService();
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE' },
      documents: DRIVER_DOCS,
    });
    await expect(
      service.reject(app.id, 'ops', 'x', [{ section: 'SHOP_INFO', note: 'n' }]),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('requires VEHICLE_INSURANCE for CAR_4 when PARTNER_CAR_KYC_EXTRA_DOCS gate is on', async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store, storage } = createTestDocumentStore();
    const user = await identity.createUser({
      email: 'car@dealgo.vn',
      phone: '+84988776656',
      displayName: 'Car Tai Xe',
    });
    const config = {
      get(key: string) {
        if (key === 'PARTNER_CAR_KYC_EXTRA_DOCS') return true;
        if (key === 'NODE_ENV') return 'test';
        return undefined;
      },
    } as never;
    const service = new PartnerService(partners, identity, store, config);

    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'CAR_4', vehiclePlate: '51A-12345' },
        documents: DRIVER_DOCS,
      }),
    ).rejects.toMatchObject({ response: { errorCode: 'PARTNER_DOCUMENTS_REQUIRED' } });
    expect(storage.size).toBe(0);

    const withInsurance = [...DRIVER_DOCS, jpeg('VEHICLE_INSURANCE')] as never[];
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'CAR_4', vehiclePlate: '51A-12345' },
      documents: withInsurance,
    });
    expect(app.status).toBe('SUBMITTED');
    expect(app.documents.map((d) => d.kind)).toContain('VEHICLE_INSURANCE');
  });

  it('does not require VEHICLE_INSURANCE for MOTORBIKE even when Car gate is on', async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store } = createTestDocumentStore();
    const user = await identity.createUser({
      email: 'bike@dealgo.vn',
      phone: '+84988776657',
      displayName: 'Bike Tai Xe',
    });
    const config = {
      get(key: string) {
        if (key === 'PARTNER_CAR_KYC_EXTRA_DOCS') return true;
        if (key === 'NODE_ENV') return 'test';
        return undefined;
      },
    } as never;
    const service = new PartnerService(partners, identity, store, config);
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', vehiclePlate: '51F-12345' },
      documents: DRIVER_DOCS,
    });
    expect(app.status).toBe('SUBMITTED');
  });

});
