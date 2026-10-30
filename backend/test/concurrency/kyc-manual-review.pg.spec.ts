import { vi } from 'vitest';
/**
 * t52u: in-house KYC manual review against Postgres — claim/decision are conditional,
 * write OpsAuditLog in the same transaction and queue the partnerStatus outbox row.
 * Skips when DATABASE_URL is unset.
 */
import type { INestApplicationContext } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import { MemoryObjectStorage } from '../../src/integrations/object-storage/memory-object-storage.js';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { OBJECT_STORAGE } from '../../src/platform/storage/storage.constants.js';
import { TINY_JPEG_BASE64, TINY_MP4_BASE64 } from '../../src/platform/storage/testing.js';
import { PartnerModule } from '../../src/modules/partner/partner.module.js';
import { PartnerService } from '../../src/modules/partner/partner.service.js';
import { uniqueTestPhone } from './test-phone.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;
const DRIVER_DOCS = [
  ...['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map((kind) => ({
    kind,
    contentType: 'image/jpeg',
    contentBase64: TINY_JPEG_BASE64,
  })),
  { kind: 'SELFIE_VIDEO', contentType: 'video/mp4', contentBase64: TINY_MP4_BASE64 },
] as never[];

describePg('KYC manual review (postgres)', () => {
  let app: INestApplicationContext;
  let prisma: PrismaService;

  beforeAll(async () => {
    app = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              DATABASE_URL: process.env.DATABASE_URL,
              JWT_ACCESS_SECRET: 'test-access-secret',
              SMS_PROVIDER: 'mock',
              PUSH_PROVIDER: 'mock',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PartnerModule,
      ],
    })
      .overrideProvider(OBJECT_STORAGE)
      .useValue(new MemoryObjectStorage())
      .compile();
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app?.close();
  });

  it('claim + parallel decisions: one wins, audit rows and outbox events are written', async () => {
    const db = prisma.db()!;
    const applicant = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'KYC pg' } });
    const reviewer = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Ops pg' } });
    const service = app.get(PartnerService);
    const submitted = await service.submit(applicant.id, {
      role: 'DRIVER',
      metadata: { vehicleClassCode: 'MOTORBIKE', licenseClass: 'A1' },
      documents: DRIVER_DOCS,
    });
    expect(submitted.metadata.aiPrecheck).toBeUndefined();
    expect((await service.claim(submitted.id, reviewer.id)).status).toBe('IN_REVIEW');

    const results = await Promise.allSettled([
      service.approve(submitted.id, reviewer.id),
      service.reject(submitted.id, reviewer.id, 'Ảnh mờ'),
    ]);
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);

    const audits = await db.opsAuditLog.findMany({
      where: { entityType: 'PARTNER_APPLICATION', entityId: submitted.id },
      orderBy: { createdAt: 'asc' },
    });
    expect(audits.map((row) => row.action)[0]).toBe('KYC_CLAIM');
    expect(audits).toHaveLength(2);
    const outbox = await db.outboxMessage.findMany({ where: { aggregateId: submitted.id } });
    expect(outbox.map((row) => row.eventType)).toContain('PartnerApplication.status.IN_REVIEW');
    expect(outbox).toHaveLength(2);
  });

  it('t61u auto-approve: SYSTEM decision, nullable reviewer, audit + outbox; parallel claim cannot double-decide', async () => {
    const db = prisma.db()!;
    const applicant = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'KYC auto pg' } });
    const reviewer = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Ops auto pg' } });
    const service = app.get(PartnerService);
    const spy = vi.spyOn(service, 'autoApproveEnabled').mockResolvedValue(true);
    try {
      const submitted = await service.submit(applicant.id, {
        role: 'DRIVER',
        metadata: {
          vehicleClassCode: 'MOTORBIKE',
          licenseClass: 'A1',
          fullName: 'Auto PG',
          birthDate: '1990-01-01',
          idNumber: '079090009999',
          licenseNumber: '790000000001',
          vehiclePlate: '59X1-000.01',
        },
        documents: DRIVER_DOCS,
      });
      expect(submitted.status).toBe('APPROVED');
      await expect(service.claim(submitted.id, reviewer.id)).rejects.toMatchObject({ status: 409 });
      const row = await db.partnerApplication.findUnique({ where: { id: submitted.id } });
      expect(row?.reviewedBy).toBeNull();
      const audits = await db.opsAuditLog.findMany({
        where: { entityType: 'PARTNER_APPLICATION', entityId: submitted.id },
      });
      expect(audits.map((a) => a.action)).toEqual(['KYC_AUTO_APPROVE']);
      expect(audits[0]?.metadata).toMatchObject({ actor: 'SYSTEM' });
      const outbox = await db.outboxMessage.findMany({ where: { aggregateId: submitted.id } });
      expect(outbox.map((r) => r.eventType)).toContain('PartnerApplication.status.APPROVED');
    } finally {
      spy.mockRestore();
    }
  });
});
