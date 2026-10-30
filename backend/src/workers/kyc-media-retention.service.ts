import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../platform/database/prisma.service.js';
import { PlatformSettingsService } from '../platform/settings/platform-settings.service.js';
import { DocumentStoreService } from '../platform/storage/document-store.service.js';

export const KYC_MEDIA_RETENTION_BATCH = 200;
/** Kinds purged after the decision; ID photos stay as evidence for the partner record. */
export const KYC_PURGEABLE_KINDS = ['SELFIE_VIDEO'] as const;
const DAY_MS = 86_400_000;

type DocRef = { kind?: string | null; key?: string };

/**
 * t54u (DEC-PROD-070, AGENT_PROPOSED): once a KYC case is decided (APPROVED/REJECTED) and
 * KYC_VIDEO_RETENTION_DAYS (admin setting, default 90) have passed since `reviewedAt`, the
 * liveness clip is deleted from storage, removed from the application, and an ops audit row
 * KYC_MEDIA_PURGE is written (actor = the reviewer, or the applicant if the reviewer is gone).
 */
@Injectable()
export class KycMediaRetentionService {
  private readonly logger = new Logger(KycMediaRetentionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly settings: PlatformSettingsService,
    private readonly store: DocumentStoreService,
  ) {}

  async cutoff(now = new Date()): Promise<Date> {
    const days = await this.settings.getNumber('KYC_VIDEO_RETENTION_DAYS');
    return new Date(now.getTime() - days * DAY_MS);
  }

  async runOnce(now = new Date()): Promise<number> {
    const db = this.prisma.db();
    if (!db) {
      return 0;
    }
    const before = await this.cutoff(now);
    const rows = await db.partnerApplication.findMany({
      where: {
        status: { in: ['APPROVED', 'REJECTED'] },
        reviewedAt: { lt: before },
        OR: KYC_PURGEABLE_KINDS.map((kind) => ({ documents: { array_contains: [{ kind }] } })),
      },
      select: { id: true, userId: true, reviewedBy: true, reviewedAt: true, documents: true, metadata: true },
      take: KYC_MEDIA_RETENTION_BATCH,
    });
    let purged = 0;
    for (const row of rows) {
      const docs = (Array.isArray(row.documents) ? row.documents : []) as DocRef[];
      const gone = docs.filter((doc) => (KYC_PURGEABLE_KINDS as readonly string[]).includes(doc.kind ?? ''));
      if (gone.length === 0) {
        continue;
      }
      const kept = docs.filter((doc) => !gone.includes(doc));
      const metadata = {
        ...((row.metadata && typeof row.metadata === 'object' && !Array.isArray(row.metadata)
          ? row.metadata
          : {}) as Record<string, unknown>),
        mediaPurgedAt: now.toISOString(),
      };
      await db.$transaction([
        db.partnerApplication.update({
          where: { id: row.id },
          data: { documents: kept as never, metadata: metadata as never },
        }),
        db.opsAuditLog.create({
          data: {
            actorUserId: row.reviewedBy ?? row.userId,
            action: 'KYC_MEDIA_PURGE',
            entityType: 'PARTNER_APPLICATION',
            entityId: row.id,
            reason: 'KYC_VIDEO_RETENTION_DAYS elapsed after decision',
            metadata: {
              actor: 'SYSTEM_RETENTION',
              kinds: gone.map((doc) => doc.kind ?? ''),
              reviewedAt: row.reviewedAt?.toISOString() ?? null,
            },
          },
        }),
      ]);
      // After commit: a failed delete leaves an orphan the orphan-upload cleanup removes later.
      await this.store.discard(gone.filter((doc): doc is { key: string } => typeof doc.key === 'string'));
      purged += 1;
    }
    if (purged > 0) {
      this.logger.log({ msg: 'kyc.media_purged', applications: purged, before: before.toISOString() });
    }
    return purged;
  }
}
