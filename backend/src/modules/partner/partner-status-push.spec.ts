import { describe, expect, it, vi } from 'vitest';
import { PartnerService } from './partner.service.js';
import { MemoryPartnerRepository } from './partner.repository.js';
import { MemoryIdentityRepository } from '../identity/identity.repository.js';
import {
  TINY_JPEG_BASE64,
  TINY_MP4_BASE64,
  TINY_PDF_BASE64,
  createTestDocumentStore,
} from '../../platform/storage/testing.js';

const jpeg = (kind: string) => ({ kind, contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 });

const DRIVER_DOCS = [
  ...['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map((kind) => jpeg(kind)),
  { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: TINY_MP4_BASE64 },
] as never[];
const MERCHANT_DOCS = [
  { kind: 'BUSINESS_LICENSE', contentType: 'application/pdf', contentBase64: TINY_PDF_BASE64 },
  jpeg('FOOD_SAFETY_CERT'),
  jpeg('REP_ID_FRONT'),
  jpeg('REP_ID_BACK'),
] as never[];

import { OutboxRelayService } from '../communication/outbox/outbox-relay.service.js';
import { MemoryOutboxRepository } from '../communication/outbox/outbox.repository.js';
import { writePartnerStatusOutbox } from '../communication/outbox/outbox.write.js';
import { SnapshotFanoutService } from '../communication/realtime/snapshot-fanout.service.js';
import { SnapshotGateway } from '../communication/realtime/snapshot.gateway.js';

// Partner approval reaches the app by socket push, not polling.
describe('partner status push', () => {
  const setup = async () => {
    const partners = new MemoryPartnerRepository();
    const identity = new MemoryIdentityRepository();
    const { store } = createTestDocumentStore();
    const user = await identity.createUser({ email: 'p@dealgo.vn', phone: '+84988770001', displayName: 'P' });
    await identity.updateUserProfile(user.id, { avatarUrl: 'https://cdn.example/p.png' });
    return { partners, user, service: new PartnerService(partners, identity, store) };
  };

  it('approve and reject record one decision event for the applicant', async () => {
    const { partners, user, service } = await setup();
    const driver = await service.submit(user.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1', vehiclePlate: '51F-12345' },
      documents: DRIVER_DOCS,
    });
    await service.approve(driver.id, 'ops');
    const shop = await service.submit(user.id, { role: 'MERCHANT', metadata: { shopName: 'Quán', shopLat: 16.06, shopLng: 108.22 }, documents: MERCHANT_DOCS });
    await service.reject(shop.id, 'ops', 'Thiếu thông tin');
    expect(partners.statusEvents.map((e) => [e.applicationId, e.userId, e.role, e.status])).toEqual([
      [driver.id, user.id, 'DRIVER', 'APPROVED'],
      [shop.id, user.id, 'MERCHANT', 'REJECTED'],
    ]);
  });

  it('outbox row relays to the user room as partnerStatus', async () => {
    const tx = { outboxMessage: { createMany: vi.fn().mockResolvedValue({ count: 1 }) } };
    const reviewedAt = new Date('2026-10-25T06:00:00.000Z');
    await writePartnerStatusOutbox(tx, { applicationId: 'a1', userId: 'u1', role: 'MERCHANT', status: 'APPROVED', reviewedAt });
    const row = tx.outboxMessage.createMany.mock.calls[0]![0].data[0];
    expect(row.eventKey).toBe(`PartnerApplication:a1:status:APPROVED:${reviewedAt.getTime()}`);

    const repo = new MemoryOutboxRepository();
    repo.seed({ id: 'm1', ...row, createdAt: reviewedAt, attempts: 0 });
    const emit = vi.fn();
    const to = vi.fn(() => ({ emit }));
    const fanout = new SnapshotFanoutService();
    fanout.bindServer({ to } as never);
    const push = { send: vi.fn() };
    const relay = new OutboxRelayService(repo, fanout, push as never);
    const at = new Date('2026-10-25T06:00:01.000Z');
    await expect(relay.relayOnce(10, at)).resolves.toBe(1);
    expect(to).toHaveBeenCalledWith('user:u1');
    expect(emit).toHaveBeenCalledWith('partnerStatus', {
      applicationId: 'a1', userId: 'u1', role: 'MERCHANT', status: 'APPROVED', occurredAt: at.toISOString(),
    });
    expect(push.send).toHaveBeenCalledTimes(1); // partner approved push
  });

  it('authenticated sockets join their private user room on connect', async () => {
    const access = { authenticateSocket: vi.fn().mockResolvedValue({ userId: 'u9', sessionId: 's', channel: 'customer' }) };
    const gw = new SnapshotGateway(access as never, { bindServer: vi.fn() } as never, { get: vi.fn() } as never);
    const sock = { data: {}, join: vi.fn().mockResolvedValue(undefined), emit: vi.fn(), disconnect: vi.fn() };
    await gw.handleConnection(sock as never);
    expect(sock.join).toHaveBeenCalledWith('user:u9');
  });

  it('ops views carry the applicant account phone (masked in list, full in detail)', async () => {
    const { user, service } = await setup();
    const app = await service.submit(user.id, { role: 'MERCHANT', metadata: { shopName: 'Quán', shopLat: 16.06, shopLng: 108.22 }, documents: MERCHANT_DOCS });
    const list = await service.listForOps({ status: 'SUBMITTED', role: 'MERCHANT' });
    expect(list.applications[0]!.metadata.phoneMasked).toMatch(/\*/);
    expect(list.applications[0]!.applicantPhone).toBeUndefined();
    const detail = await service.getForOps(app.id);
    expect(detail.applicantPhone).toBe('+84988770001');
    expect((await service.listForOps({ status: 'SUBMITTED', role: 'DRIVER' })).applications).toHaveLength(0);
  });
});
