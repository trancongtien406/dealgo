/**
 * DEC-PROD-022: the worker's orphan-upload cleanup against Postgres. Boots the real WorkersModule
 * (DI check) and verifies every table that stores upload refs protects its files.
 * Skips when DATABASE_URL is unset.
 */
import { randomUUID } from 'node:crypto';
import type { INestApplicationContext } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import { MemoryObjectStorage } from '../../src/integrations/object-storage/memory-object-storage.js';
import { loadEnv } from '../../src/platform/config/env.js';
import { PrismaService } from '../../src/platform/database/prisma.service.js';
import { OBJECT_STORAGE } from '../../src/platform/storage/storage.constants.js';
import { OrphanUploadCleanupService } from '../../src/workers/orphan-upload-cleanup.service.js';
import { UPLOAD_REFERENCE_SOURCE, type UploadReferenceSource } from '../../src/workers/upload-references.js';
import { WorkersModule } from '../../src/workers/workers.module.js';
import { uniqueTestPhone } from './test-phone.js';

const hasDatabase = Boolean(process.env.DATABASE_URL?.trim());
const describePg = hasDatabase ? describe : describe.skip;

describePg('orphan upload cleanup (postgres)', () => {
  let app: INestApplicationContext;
  let prisma: PrismaService;
  const storage = new MemoryObjectStorage();

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
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
        WorkersModule,
      ],
    })
      .overrideProvider(OBJECT_STORAGE)
      .useValue(storage)
      .compile();
    app = moduleRef;
    await app.init();
    prisma = app.get(PrismaService);
  });

  afterAll(async () => {
    await app?.close();
  });

  it('keeps files referenced by documents, ticket attachments and avatars; deletes old orphans', async () => {
    const db = prisma.db()!;
    const tag = randomUUID();
    const user = await db.user.create({ data: { phone: uniqueTestPhone(), displayName: 'Orphan Test' } });
    const docKey = `partner-applications/${tag}/doc.jpg`;
    const attKey = `support-attachments/2026-10/${tag}.jpg`;
    const avatarKey = `avatars/${user.id}/${randomUUID()}.jpg`;
    const orphanKey = `support-attachments/2026-10/${tag}-orphan.jpg`;
    const ref = (key: string) => ({ key, label: 'x', contentType: 'image/jpeg', sizeBytes: 1, uploadedAt: '2026-10-01T00:00:00.000Z' });

    await db.partnerApplication.create({
      data: { userId: user.id, role: 'DRIVER', status: 'SUBMITTED', documents: [ref(docKey)] },
    });
    const ticket = await db.supportTicket.create({
      data: {
        code: `T${tag.slice(0, 8)}`,
        requesterUserId: user.id,
        requesterRole: 'CUSTOMER',
        channel: 'APP',
        category: 'OTHER',
        subject: 'orphan test',
      },
    });
    await db.supportTicketMessage.create({
      data: { ticketId: ticket.id, authorType: 'REQUESTER', body: 'x', attachments: [ref(attKey)] },
    });
    await db.user.update({
      where: { id: user.id },
      data: { avatarUrl: `/v1/public/avatars/${avatarKey.slice('avatars/'.length)}` },
    });

    const refs = await app.get<UploadReferenceSource>(UPLOAD_REFERENCE_SOURCE).referencedKeys();
    expect(refs).not.toBeNull();
    expect([...refs!].filter((k) => k.includes(tag) || k.includes(user.id)).sort()).toEqual(
      [attKey, avatarKey, docKey].sort(),
    );

    const old = new Date(Date.now() - 30 * 24 * 3_600_000);
    for (const key of [docKey, attKey, avatarKey, orphanKey]) {
      await storage.put(key, Buffer.from('x'), 'image/jpeg');
      storage.setLastModified(key, old);
    }
    const report = await app.get(OrphanUploadCleanupService).runOnce();
    expect(report).toMatchObject({ ran: true, maxAgeHours: 72 });
    expect(storage.has(orphanKey)).toBe(false);
    for (const key of [docKey, attKey, avatarKey]) {
      expect(storage.has(key)).toBe(true);
    }
  });
});
