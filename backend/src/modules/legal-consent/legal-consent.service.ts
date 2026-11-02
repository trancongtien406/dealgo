import { HttpException, Injectable, Logger, OnModuleInit, Optional } from '@nestjs/common';
import { DynamicMailSender } from '../../integrations/email/dynamic-mail-sender.js';
import { redactEmail } from '../../integrations/email/mail-templates.js';
import { MAIL_BRAND } from '../../integrations/email/mail-templates.js';
import type { MailSender } from '../../integrations/email/mail-sender.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { registerOutboxHandler } from '../communication/outbox/outbox-handlers.js';
import type { OutboxPendingRow } from '../communication/outbox/outbox.repository.js';
import { PublicPagesService } from '../public-pages/public-pages.service.js';
import {
  LEGAL_EMAIL_BATCH,
  LEGAL_EMAIL_PACE_MS,
  LEGAL_POLICY_AGGREGATE,
  LEGAL_POLICY_EMAIL_EVENT,
  PARTNER_APPLICATION_CONSENT_SLUGS,
  type AcceptedLegalDocument,
  type LegalPolicyVersionView,
  type PendingConsentView,
} from './legal-consent.types.js';

type Db = NonNullable<ReturnType<PrismaService['db']>>;
type VersionRow = Awaited<ReturnType<Db['legalPolicyVersion']['findFirstOrThrow']>>;

const iso = (d: Date | null | undefined) => (d ? d.toISOString() : null);

export function legalError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}

export const APPLICATION_CONSENT_CHANGELOG = 'Ghi nhận khi đăng ký tài xế/cửa hàng';

function isApplicationConsentRow(row: { requiresConsent: boolean; publishedByUserId: string | null; changelog: string }): boolean {
  return !row.requiresConsent && row.publishedByUserId === null && row.changelog === APPLICATION_CONSENT_CHANGELOG;
}

export function legalPageUrl(slug: string): string {
  return `${MAIL_BRAND.siteUrl}/${slug}`;
}

/**
 * t82u (DEC-PROD-090): legal document versions that users must accept, consent audit,
 * and the "terms changed" email (outbox → paced batches; two-step admin send).
 */
@Injectable()
export class LegalConsentService implements OnModuleInit {
  private readonly logger = new Logger(LegalConsentService.name);
  /** Overridable in tests. */
  paceMs = LEGAL_EMAIL_PACE_MS;
  batchSize = LEGAL_EMAIL_BATCH;

  constructor(
    private readonly pages: PublicPagesService,
    @Optional() private readonly prisma?: PrismaService,
    @Optional() private readonly mail?: DynamicMailSender,
  ) {}

  onModuleInit(): void {
    registerOutboxHandler(LEGAL_POLICY_AGGREGATE, (row) => this.handleEmailBatch(row));
  }

  private db(): Db {
    const db = this.prisma?.db();
    if (!db) throw legalError(503, 'LEGAL_CONSENT_UNAVAILABLE', 'Legal consent needs the database');
    return db;
  }

  // ---------- ops ----------

  async listVersions(): Promise<LegalPolicyVersionView[]> {
    const db = this.prisma?.db();
    if (!db) return [];
    const rows = await db.legalPolicyVersion.findMany({
      orderBy: { publishedAt: 'desc' },
      take: 100,
      include: { _count: { select: { consents: true } } },
    });
    return rows.map((r) => ({ ...toView(r), consentCount: r._count.consents }));
  }

  /** Marks the currently published (vi) page version as requiring consent. No legal text is created here. */
  async publish(
    input: { slug: string; changelog: string; effectiveAt?: string; audienceRoles: string[]; requiresConsent?: boolean },
    actorUserId: string,
  ): Promise<LegalPolicyVersionView> {
    const db = this.db();
    const page = await this.pages.getPublic(this.pages.parseSlug(input.slug), 'vi');
    if (page.source !== 'cms' || page.version < 1) {
      throw legalError(409, 'LEGAL_PAGE_NOT_PUBLISHED', 'Publish the document in Nội dung › Trang pháp lý first');
    }
    const existing = await db.legalPolicyVersion.findUnique({
      where: { slug_version: { slug: input.slug, version: page.version } },
    });
    if (existing && isApplicationConsentRow(existing)) {
      // pt5u: the row was only auto-recorded by a partner application; promote it.
      const row = await db.legalPolicyVersion.update({
        where: { id: existing.id },
        data: {
          title: page.title,
          changelog: input.changelog.trim(),
          effectiveAt: input.effectiveAt ? new Date(input.effectiveAt) : existing.effectiveAt,
          audienceRoles: [...new Set(input.audienceRoles)],
          requiresConsent: input.requiresConsent ?? true,
          publishedByUserId: actorUserId,
        },
      });
      return toView(row);
    }
    if (existing) {
      throw legalError(409, 'LEGAL_VERSION_EXISTS', `Version ${page.version} of ${input.slug} already requires consent`);
    }
    const effectiveAt = input.effectiveAt ? new Date(input.effectiveAt) : page.effectiveAt ? new Date(page.effectiveAt) : null;
    const row = await db.legalPolicyVersion.create({
      data: {
        slug: input.slug,
        version: page.version,
        title: page.title,
        changelog: input.changelog.trim(),
        effectiveAt,
        audienceRoles: [...new Set(input.audienceRoles)],
        requiresConsent: input.requiresConsent ?? true,
        publishedByUserId: actorUserId,
      },
    });
    this.logger.log({ msg: 'legal.version_published', id: row.id, slug: row.slug, version: row.version });
    return toView(row);
  }

  async emailPreview(id: string): Promise<{ id: string; recipients: number; emailStatus: string }> {
    const row = await this.version(id);
    return { id, recipients: await this.countRecipients(row.audienceRoles), emailStatus: row.emailStatus };
  }

  /** Second click of the two-step send: count must still match the preview; sends once. */
  async queueEmail(id: string, confirmCount: number, actorUserId: string): Promise<LegalPolicyVersionView> {
    const db = this.db();
    const row = await this.version(id);
    if (row.emailStatus !== 'NONE') {
      throw legalError(409, 'LEGAL_EMAIL_ALREADY_SENT', 'Email for this version was already queued');
    }
    const recipients = await this.countRecipients(row.audienceRoles);
    if (recipients !== confirmCount) {
      throw legalError(409, 'LEGAL_EMAIL_COUNT_CHANGED', `Recipient count changed (${recipients}); preview again`);
    }
    const now = new Date();
    const updated = await db.$transaction(async (tx) => {
      const claimed = await tx.legalPolicyVersion.updateMany({
        where: { id, emailStatus: 'NONE' },
        data: { emailStatus: recipients === 0 ? 'SENT' : 'QUEUED', emailQueuedAt: now, emailRecipients: recipients },
      });
      if (claimed.count !== 1) {
        throw legalError(409, 'LEGAL_EMAIL_ALREADY_SENT', 'Email for this version was already queued');
      }
      if (recipients > 0) {
        await tx.outboxMessage.createMany({
          data: [
            {
              eventKey: `legal-email:${id}:start`,
              aggregateType: LEGAL_POLICY_AGGREGATE,
              aggregateId: id,
              eventType: LEGAL_POLICY_EMAIL_EVENT,
              payload: { cursor: null },
            },
          ],
          skipDuplicates: true,
        });
      }
      return tx.legalPolicyVersion.findUniqueOrThrow({ where: { id } });
    });
    this.logger.log({ msg: 'legal.email_queued', id, recipients, actorUserId });
    return toView(updated);
  }

  /** Outbox handler: one paced batch per row, then a follow-up row with the cursor. */
  async handleEmailBatch(row: OutboxPendingRow): Promise<void> {
    if (row.eventType !== LEGAL_POLICY_EMAIL_EVENT) return;
    const db = this.db();
    const version = await db.legalPolicyVersion.findUnique({ where: { id: row.aggregateId } });
    if (!version || version.emailStatus === 'SENT') return;
    const mail: MailSender | undefined = this.mail;
    if (!mail) throw new Error('Mail sender unavailable');
    const cursor = cursorFrom(row.payload);
    const users = await db.user.findMany({
      where: { ...recipientWhere(version.audienceRoles), ...(cursor ? { id: { gt: cursor } } : {}) },
      select: { id: true, email: true },
      orderBy: { id: 'asc' },
      take: this.batchSize,
    });
    let sent = 0;
    let failed = 0;
    for (const [i, u] of users.entries()) {
      if (!u.email) continue;
      if (i > 0 && this.paceMs > 0) await sleep(this.paceMs);
      try {
        await mail.sendPolicyUpdate({
          email: u.email,
          documentTitle: version.title,
          version: version.version,
          effectiveAt: version.effectiveAt,
          changelog: version.changelog,
          url: legalPageUrl(version.slug),
        });
        sent += 1;
      } catch (error) {
        failed += 1;
        this.logger.warn({
          msg: 'legal.email_failed',
          to: redactEmail(u.email),
          error: error instanceof Error ? error.message : 'unknown',
        });
      }
    }
    const last = users.at(-1)?.id;
    const more = users.length === this.batchSize && last !== undefined;
    await db.$transaction(async (tx) => {
      await tx.legalPolicyVersion.update({
        where: { id: version.id },
        data: {
          emailSentCount: { increment: sent },
          emailFailedCount: { increment: failed },
          emailStatus: more ? 'SENDING' : 'SENT',
        },
      });
      if (more) {
        await tx.outboxMessage.createMany({
          data: [
            {
              eventKey: `legal-email:${version.id}:${last}`,
              aggregateType: LEGAL_POLICY_AGGREGATE,
              aggregateId: version.id,
              eventType: LEGAL_POLICY_EMAIL_EVENT,
              payload: { cursor: last },
            },
          ],
          skipDuplicates: true,
        });
      }
    });
    this.logger.log({ msg: 'legal.email_batch', id: version.id, sent, failed, more });
  }

  // ---------- users ----------

  async pending(userId: string): Promise<PendingConsentView[]> {
    const db = this.prisma?.db();
    if (!db) return [];
    const roles = await this.activeRoles(userId);
    if (roles.length === 0) return [];
    const versions = await db.legalPolicyVersion.findMany({
      where: { requiresConsent: true, audienceRoles: { hasSome: roles } },
      orderBy: [{ slug: 'asc' }, { version: 'desc' }],
    });
    const latest = new Map<string, VersionRow>();
    for (const v of versions) if (!latest.has(v.slug)) latest.set(v.slug, v);
    if (latest.size === 0) return [];
    const accepted = await db.userLegalConsent.findMany({
      where: { userId, policyVersionId: { in: [...latest.values()].map((v) => v.id) } },
      select: { policyVersionId: true },
    });
    const done = new Set(accepted.map((a) => a.policyVersionId));
    return [...latest.values()]
      .filter((v) => !done.has(v.id))
      .map((v) => ({
        id: v.id,
        slug: v.slug,
        version: v.version,
        title: v.title,
        changelog: v.changelog,
        effectiveAt: iso(v.effectiveAt),
        publishedAt: v.publishedAt.toISOString(),
        url: legalPageUrl(v.slug),
      }));
  }

  async accept(userId: string, id: string, meta: { ip: string | null; userAgent: string | null }): Promise<{ accepted: true }> {
    const db = this.db();
    const v = await this.version(id);
    const roles = await this.activeRoles(userId);
    if (!v.audienceRoles.some((r) => roles.includes(r))) {
      throw legalError(404, 'LEGAL_VERSION_NOT_FOUND', 'Legal version not found');
    }
    await db.userLegalConsent.createMany({
      data: [
        {
          userId,
          policyVersionId: v.id,
          slug: v.slug,
          version: v.version,
          ip: meta.ip?.slice(0, 64) ?? null,
          userAgent: meta.userAgent?.slice(0, 300) ?? null,
        },
      ],
      skipDuplicates: true,
    });
    this.logger.log({ msg: 'legal.consent_accepted', policyVersionId: v.id, slug: v.slug, version: v.version });
    return { accepted: true };
  }

  // ---------- partner applications (pt5u) ----------

  /** Current published (vi) version per required document; 0 = built-in default text. */
  async currentApplicationDocuments(): Promise<AcceptedLegalDocument[]> {
    const out: AcceptedLegalDocument[] = [];
    for (const slug of PARTNER_APPLICATION_CONSENT_SLUGS) {
      const page = await this.pages.getPublic(slug, 'vi');
      out.push({ slug, version: page.source === 'cms' ? page.version : 0 });
    }
    return out;
  }

  /** Rejects a driver/shop application unless every current required version is accepted. */
  async assertApplicationConsent(accepted: AcceptedLegalDocument[] | undefined): Promise<AcceptedLegalDocument[]> {
    const current = await this.currentApplicationDocuments();
    const missing = current.filter(
      (doc) => !(accepted ?? []).some((a) => a.slug === doc.slug && a.version === doc.version),
    );
    if (missing.length > 0) {
      throw new HttpException(
        {
          message: `Accept the current ${missing.map((m) => m.slug).join(', ')} before submitting`,
          errorCode: 'PARTNER_LEGAL_CONSENT_REQUIRED',
          details: { required: current, missing },
        },
        400,
      );
    }
    return current;
  }

  /** Audit rows for the accepted versions (published CMS versions only; needs the database). */
  async recordApplicationConsent(
    userId: string,
    role: string,
    docs: AcceptedLegalDocument[],
    meta: { ip?: string | null; userAgent?: string | null } = {},
  ): Promise<void> {
    const db = this.prisma?.db();
    if (!db) return;
    for (const doc of docs) {
      if (doc.version < 1) continue;
      let v = await db.legalPolicyVersion.findUnique({
        where: { slug_version: { slug: doc.slug, version: doc.version } },
      });
      if (!v) {
        const page = await this.pages.getPublic(doc.slug as (typeof PARTNER_APPLICATION_CONSENT_SLUGS)[number], 'vi');
        v = await db.legalPolicyVersion.upsert({
          where: { slug_version: { slug: doc.slug, version: doc.version } },
          create: {
            slug: doc.slug,
            version: doc.version,
            title: page.title,
            changelog: APPLICATION_CONSENT_CHANGELOG,
            effectiveAt: page.effectiveAt ? new Date(page.effectiveAt) : null,
            audienceRoles: [role],
            requiresConsent: false,
          },
          update: {},
        });
      }
      await db.userLegalConsent.createMany({
        data: [
          {
            userId,
            policyVersionId: v.id,
            slug: v.slug,
            version: v.version,
            ip: meta.ip?.slice(0, 64) ?? null,
            userAgent: meta.userAgent?.slice(0, 300) ?? null,
          },
        ],
        skipDuplicates: true,
      });
    }
    this.logger.log({ msg: 'legal.application_consent', role, docs });
  }

  // ---------- helpers ----------

  private async version(id: string): Promise<VersionRow> {
    const row = await this.db().legalPolicyVersion.findUnique({ where: { id } });
    if (!row) throw legalError(404, 'LEGAL_VERSION_NOT_FOUND', 'Legal version not found');
    return row;
  }

  private async activeRoles(userId: string): Promise<string[]> {
    const grants = await this.db().roleGrant.findMany({
      where: { userId, status: 'ACTIVE' },
      select: { role: true },
    });
    return grants.map((g) => g.role as string);
  }

  private countRecipients(roles: string[]): Promise<number> {
    return this.db().user.count({ where: recipientWhere(roles) });
  }
}

function recipientWhere(roles: string[]) {
  return {
    email: { not: null },
    deletedAt: null,
    roleGrants: { some: { status: 'ACTIVE' as const, role: { in: roles as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[] } } },
  };
}

function cursorFrom(payload: unknown): string | null {
  const c = (payload as { cursor?: unknown } | null)?.cursor;
  return typeof c === 'string' && c.length > 0 ? c : null;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function toView(r: VersionRow): LegalPolicyVersionView {
  return {
    id: r.id,
    slug: r.slug,
    version: r.version,
    title: r.title,
    changelog: r.changelog,
    effectiveAt: iso(r.effectiveAt),
    audienceRoles: r.audienceRoles,
    requiresConsent: r.requiresConsent,
    publishedAt: r.publishedAt.toISOString(),
    emailStatus: r.emailStatus,
    emailQueuedAt: iso(r.emailQueuedAt),
    emailRecipients: r.emailRecipients,
    emailSentCount: r.emailSentCount,
    emailFailedCount: r.emailFailedCount,
  };
}
