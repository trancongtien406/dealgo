import { describe, expect, it, vi } from 'vitest';
import type { PrismaService } from '../platform/database/prisma.service.js';
import type { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';
import type { DocumentStoreService } from '../platform/storage/document-store.service.js';
import { KycMediaRetentionService } from './kyc-media-retention.service.js';

const NOW = new Date('2026-10-30T00:00:00.000Z');

function harness(rows: unknown[]) {
  const findMany = vi.fn(async () => rows);
  const update = vi.fn((args: unknown) => ({ op: 'update', args }));
  const create = vi.fn((args: unknown) => ({ op: 'audit', args }));
  const $transaction = vi.fn(async (ops: unknown[]) => ops);
  const prisma = {
    db: () => ({ partnerApplication: { findMany, update }, opsAuditLog: { create }, $transaction }),
  } as unknown as PrismaService;
  const settings = { getNumber: async () => 90 } as unknown as PlatformSettingsService;
  const discard = vi.fn(async () => undefined);
  const store = { discard } as unknown as DocumentStoreService;
  return { service: new KycMediaRetentionService(prisma, settings, store), findMany, update, create, discard, $transaction };
}

describe('KycMediaRetentionService (t54u)', () => {
  it('purges only the liveness clip of decided cases past retention, with an audit row', async () => {
    const h = harness([
      {
        id: 'a1',
        userId: 'u1',
        reviewedBy: null,
        reviewedAt: new Date('2026-07-01T00:00:00.000Z'),
        metadata: { fullName: 'A' },
        documents: [
          { kind: 'ID_FRONT', key: 'partner-applications/a1/f.jpg' },
          { kind: 'SELFIE_VIDEO', key: 'partner-applications/a1/v.mp4' },
        ],
      },
    ]);
    await expect(h.service.runOnce(NOW)).resolves.toBe(1);
    expect(h.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: { in: ['APPROVED', 'REJECTED'] },
          reviewedAt: { lt: new Date('2026-08-01T00:00:00.000Z') },
        }),
      }),
    );
    expect(h.update).toHaveBeenCalledWith({
      where: { id: 'a1' },
      data: {
        documents: [{ kind: 'ID_FRONT', key: 'partner-applications/a1/f.jpg' }],
        metadata: { fullName: 'A', mediaPurgedAt: NOW.toISOString() },
      },
    });
    expect(h.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorUserId: 'u1',
        action: 'KYC_MEDIA_PURGE',
        entityType: 'PARTNER_APPLICATION',
        entityId: 'a1',
        metadata: expect.objectContaining({ actor: 'SYSTEM_RETENTION', kinds: ['SELFIE_VIDEO'] }),
      }),
    });
    expect(h.discard).toHaveBeenCalledWith([{ kind: 'SELFIE_VIDEO', key: 'partner-applications/a1/v.mp4' }]);
  });

  it('skips rows without a clip and is a no-op without a database', async () => {
    const h = harness([{ id: 'a2', userId: 'u2', reviewedBy: 'r', reviewedAt: NOW, metadata: {}, documents: [] }]);
    await expect(h.service.runOnce(NOW)).resolves.toBe(0);
    expect(h.$transaction).not.toHaveBeenCalled();
    const none = new KycMediaRetentionService(
      { db: () => null } as unknown as PrismaService,
      {} as PlatformSettingsService,
      {} as DocumentStoreService,
    );
    await expect(none.runOnce()).resolves.toBe(0);
  });
});
