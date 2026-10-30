import { describe, expect, it } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import { TINY_JPEG_BASE64, TINY_MP4_BASE64, createTestDocumentStore } from '../../platform/storage/testing.js';

const DRIVER_DOCS = [
  ...['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map((kind) => ({
    kind,
    contentType: 'image/jpeg',
    contentBase64: TINY_JPEG_BASE64,
  })),
  { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: TINY_MP4_BASE64 },
] as never[];
const PHOTO_DOCS = (DRIVER_DOCS as { kind: string }[]).filter((d) => d.kind !== 'SELFIE_VIDEO') as never[];

// t52u: in-house KYC — manual review state machine, audit log, advisory AI pre-check.
describe('KYC manual review (t52u)', () => {
  const setup = async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store } = createTestDocumentStore();
    const user = await identity.createUser({ email: 'k@dealgo.vn', phone: '+84988770009', displayName: 'K' });
    const service = new PartnerService(partners, identity, store);
    const submit = (metadata: Record<string, unknown> = {}) =>
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1', ...metadata },
        documents: DRIVER_DOCS,
      });
    return { partners, user, service, submit };
  };

  it('SUBMITTED → IN_REVIEW → APPROVED with audit rows and realtime events', async () => {
    const { partners, service, submit } = await setup();
    const app = await submit();
    const claimed = await service.claim(app.id, 'ops-1');
    expect(claimed.status).toBe('IN_REVIEW');
    const approved = await service.approve(app.id, 'ops-1');
    expect(approved.status).toBe('APPROVED');
    expect(partners.auditLogs.map((row) => row.action)).toEqual(['KYC_CLAIM', 'KYC_APPROVE']);
    expect(partners.statusEvents.map((e) => e.status)).toEqual(['IN_REVIEW', 'APPROVED']);
  });

  it('reject from IN_REVIEW keeps reason + sections in the audit log, then resubmit works', async () => {
    const { partners, service, submit } = await setup();
    const app = await submit();
    await service.claim(app.id, 'ops-1');
    const rejected = await service.reject(app.id, 'ops-1', 'Ảnh mờ', [{ section: 'ID_CARD', note: 'Chụp lại' }]);
    expect(rejected.status).toBe('REJECTED');
    expect(partners.auditLogs.at(-1)).toMatchObject({
      action: 'KYC_REJECT',
      reason: 'Ảnh mờ',
      metadata: { sections: ['ID_CARD'] },
    });
    const again = await submit();
    expect(again.status).toBe('SUBMITTED');
  });

  it('the ops "All" filter lists every non-draft status (t54u)', async () => {
    const { service, submit } = await setup();
    const app = await submit();
    await service.claim(app.id, 'ops-1');
    await service.approve(app.id, 'ops-1');
    expect((await service.listForOps({ status: 'SUBMITTED' })).total).toBe(0);
    const all = await service.listForOps({ status: 'ALL' });
    expect(all.applications.map((row) => row.status)).toEqual(['APPROVED']);
  });

  it('a driver without the liveness clip is refused (t54u: SELFIE_VIDEO required)', async () => {
    const { service, user } = await setup();
    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1' },
        documents: PHOTO_DOCS,
      }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('claim is only allowed once and only from SUBMITTED', async () => {
    const { service, submit } = await setup();
    const app = await submit();
    await service.claim(app.id, 'ops-1');
    await expect(service.claim(app.id, 'ops-2')).rejects.toMatchObject({ status: 409 });
    await service.approve(app.id, 'ops-1');
    await expect(service.claim(app.id, 'ops-2')).rejects.toMatchObject({ status: 409 });
    await expect(service.reject(app.id, 'ops-2', 'x')).rejects.toMatchObject({ status: 409 });
  });

  it('applicant cannot resubmit while a case is IN_REVIEW', async () => {
    const { service, submit } = await setup();
    const app = await submit();
    await service.claim(app.id, 'ops-1');
    await expect(submit()).rejects.toMatchObject({ status: 409 });
  });

  it('stores no AI verdict: a client aiPrecheck is dropped and the case stays SUBMITTED (t56u)', async () => {
    const { service, submit } = await setup();
    const app = await submit({ aiPrecheck: 'PASSED' });
    expect(app.status).toBe('SUBMITTED');
    expect(app.metadata.aiPrecheck).toBeUndefined();
    expect((await service.getForOps(app.id)).status).toBe('SUBMITTED');
  });
});

// t53u: auto-recorded face liveness clip.
describe('SELFIE_VIDEO liveness clip (t53u)', () => {
  const mp4 = Buffer.concat([
    Buffer.from([0, 0, 0, 0x18]),
    Buffer.from('ftypisom', 'latin1'),
    Buffer.alloc(64, 1),
  ]).toString('base64');

  it('accepts an mp4 clip beside the photos, sniffed by bytes, ', async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store } = createTestDocumentStore();
    const user = await identity.createUser({ email: 'v@dealgo.vn', phone: '+84988770010', displayName: 'V' });
    const service = new PartnerService(partners, identity, store);
    const app = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1' },
      documents: [
        ...PHOTO_DOCS,
        { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: mp4 },
      ] as never[],
    });
    const clip = app.documents.find((d) => d.kind === 'SELFIE_VIDEO');
    expect(clip).toMatchObject({ contentType: 'video/mp4' });
  });

  it('rejects a clip whose bytes are not video', async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store } = createTestDocumentStore();
    const user = await identity.createUser({ email: 'w@dealgo.vn', phone: '+84988770011', displayName: 'W' });
    const service = new PartnerService(partners, identity, store);
    await expect(
      service.submit(user.id, {
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1' },
        documents: [
          ...PHOTO_DOCS,
          { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: Buffer.from('%PDF-1.4').toString('base64') },
        ] as never[],
      }),
    ).rejects.toMatchObject({ status: 415 });
  });
});
