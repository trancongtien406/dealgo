import { HttpException, Inject, Injectable } from '@nestjs/common';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
} from '../identity/identity.repository.js';
import {
  PARTNER_DOCUMENT_KINDS,
  PARTNER_ISSUE_SECTIONS,
  PARTNER_REPOSITORY,
  PARTNER_REQUIRED_DOCUMENTS,
} from './partner.constants.js';
import type {
  OpsPartnerApplicationQueryDto,
  PartnerReviewIssueDto,
  SubmitPartnerApplicationDto,
} from './partner.dto.js';
import { partnerError } from './partner.error.js';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import { maskPhone } from '../../shared/privacy/pii-mask.js';
import type {
  PartnerApplicationRecord,
  PartnerDocumentRef,
  PartnerReviewIssue,
  PartnerRepository,
  PartnerRoleName,
  PartnerStatusName,
} from './partner.repository.js';

export type PartnerApplicationView = {
  id: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: Record<string, unknown>;
  documents: PartnerDocumentView[];
  reason: string | null;
  /** Sections ops asked the applicant to fix (empty for approvals and plain rejections). */
  issues: PartnerReviewIssue[];
  reviewedBy: string | null;
  reviewedAt: string | null;
  submittedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type PartnerDocumentView = {
  /** Position in `documents`; ops download with GET .../documents/:index. */
  index: number;
  kind: string | null;
  label: string;
  contentType: string;
  sizeBytes: number;
  uploadedAt: string;
  /** False for legacy metadata-only refs that have no stored bytes. */
  hasFile: boolean;
};

@Injectable()
export class PartnerService {
  constructor(
    @Inject(PARTNER_REPOSITORY) private readonly partners: PartnerRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly documents: DocumentStoreService,
  ) {}

  async listMine(userId: string): Promise<{ applications: PartnerApplicationView[] }> {
    const rows = await this.partners.listByUser(userId);
    return { applications: rows.map(toView) };
  }

  async getMine(userId: string, role: PartnerRoleName): Promise<PartnerApplicationView> {
    const row = await this.partners.findByUserAndRole(userId, role);
    if (!row) {
      throw partnerError(404, 'PARTNER_APPLICATION_NOT_FOUND', 'Partner application not found');
    }
    return toView(row);
  }

  async submit(userId: string, dto: SubmitPartnerApplicationDto): Promise<PartnerApplicationView> {
    const existing = await this.partners.findByUserAndRole(userId, dto.role);
    if (existing?.status === 'APPROVED') {
      throw partnerError(
        409,
        'PARTNER_APPLICATION_ALREADY_APPROVED',
        'An approved application already exists for this role',
      );
    }
    if (existing?.status === 'SUBMITTED') {
      throw partnerError(
        409,
        'PARTNER_APPLICATION_ALREADY_SUBMITTED',
        'Application is already awaiting review',
      );
    }

    const uploads = dto.documents ?? [];
    const allowedKinds = PARTNER_DOCUMENT_KINDS[dto.role] as readonly string[];
    const seen = new Set<string>();
    for (const upload of uploads) {
      if (!allowedKinds.includes(upload.kind)) {
        throw partnerError(400, 'VALIDATION_ERROR', `Document kind ${upload.kind} is not valid for ${dto.role}`);
      }
      if (seen.has(upload.kind)) {
        throw partnerError(400, 'VALIDATION_ERROR', `Document kind ${upload.kind} is sent twice`);
      }
      seen.add(upload.kind);
    }
    // A resubmission only re-sends the documents ops flagged; the rest stay on file.
    const kept = (existing?.documents ?? []).filter(
      (doc) => doc.kind && allowedKinds.includes(doc.kind) && !seen.has(doc.kind) && hasStoredFile(doc),
    );
    const onFile = new Set([...seen, ...kept.map((doc) => doc.kind!)]);
    const missing = (PARTNER_REQUIRED_DOCUMENTS[dto.role] as readonly string[]).filter(
      (kind) => !onFile.has(kind),
    );
    if (missing.length > 0) {
      throw new HttpException(
        {
          message: `Missing required documents: ${missing.join(', ')}`,
          errorCode: 'PARTNER_DOCUMENTS_REQUIRED',
          details: { missing },
        },
        400,
      );
    }

    const applicationId = existing?.id ?? cryptoRandomId();
    const stored = await this.documents.storeAll(
      `partner-applications/${applicationId}`,
      uploads.map((upload) => ({
        label: upload.label?.trim() || upload.kind,
        contentType: upload.contentType,
        contentBase64: upload.contentBase64,
      })),
    );
    const fresh: PartnerDocumentRef[] = stored.map((ref, index) => ({
      ...ref,
      kind: uploads[index]!.kind,
    }));
    const order = PARTNER_DOCUMENT_KINDS[dto.role] as readonly string[];
    const documents = [...kept, ...fresh].sort(
      (a, b) => order.indexOf(a.kind ?? '') - order.indexOf(b.kind ?? ''),
    );
    const now = new Date();
    let saved;
    try {
      saved = await this.partners.upsertSubmit({
        id: applicationId,
        userId,
        role: dto.role,
        metadata: sanitizeMetadata(dto.metadata),
        documents,
        now,
      });
    } catch (error) {
      await this.documents.discard(fresh);
      throw error;
    }
    // Files the new upload replaced are no longer referenced by any application.
    await this.documents.discard(
      (existing?.documents ?? []).filter((doc) => doc.kind && seen.has(doc.kind) && hasStoredFile(doc)),
    );
    return toView(saved);
  }

  /** Ops-only: bytes of one stored document for review. */
  async readDocumentForOps(
    applicationId: string,
    index: number,
  ): Promise<{ body: Buffer; contentType: string; filename: string }> {
    const existing = await this.partners.findById(applicationId);
    const doc = existing?.documents[index];
    if (!existing || !doc) {
      throw partnerError(404, 'PARTNER_DOCUMENT_NOT_FOUND', 'Document not found');
    }
    const file = await this.documents.read(doc);
    if (!file) {
      throw partnerError(404, 'PARTNER_DOCUMENT_NOT_FOUND', 'Document file is not stored');
    }
    const ext = doc.key.includes('.') ? doc.key.slice(doc.key.lastIndexOf('.') + 1) : 'bin';
    return { ...file, filename: `${(doc.kind ?? 'document').toLowerCase()}-${index}.${ext}` };
  }

  async listForOps(query?: OpsPartnerApplicationQueryDto | PartnerStatusName): Promise<{
    applications: PartnerApplicationView[];
    total: number;
    page: number;
    limit: number;
  }> {
    const opts: OpsPartnerApplicationQueryDto =
      typeof query === 'string' ? { status: query } : query ?? {};
    const page = opts.page ?? 1;
    const limit = opts.limit ?? 20;
    const result = await this.partners.listForOps({
      status: opts.status ?? 'SUBMITTED',
      page,
      limit,
      q: opts.q,
      role: opts.role,
    });
    return {
      applications: result.items.map(toView),
      total: result.total,
      page,
      limit,
    };
  }

  async getForOps(applicationId: string): Promise<PartnerApplicationView> {
    const existing = await this.partners.findById(applicationId);
    if (!existing) {
      throw partnerError(404, 'PARTNER_APPLICATION_NOT_FOUND', 'Partner application not found');
    }
    return toView(existing);
  }

  async approve(applicationId: string, reviewerId: string): Promise<PartnerApplicationView> {
    const existing = await this.requireSubmitted(applicationId);
    const now = new Date();
    const updated = await this.partners.review({
      id: existing.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: reviewerId,
      now,
    });
    if (!updated) {
      throw notSubmittedError();
    }
    await this.ensureGrant(existing.userId, existing.role, 'ACTIVE');
    return toView(updated);
  }

  async reject(
    applicationId: string,
    reviewerId: string,
    reason: string,
    issues: readonly PartnerReviewIssueDto[] = [],
  ): Promise<PartnerApplicationView> {
    const existing = await this.requireSubmitted(applicationId);
    const trimmed = reason.trim();
    if (!trimmed) {
      throw partnerError(400, 'VALIDATION_ERROR', 'Rejection reason is required');
    }
    const sections = PARTNER_ISSUE_SECTIONS[existing.role] as readonly string[];
    const reviewIssues: PartnerReviewIssue[] = [];
    for (const issue of issues) {
      const note = issue.note.trim();
      if (!sections.includes(issue.section) || !note) {
        throw partnerError(
          400,
          'VALIDATION_ERROR',
          `Issue section must be one of ${sections.join(', ')} with a note`,
        );
      }
      if (reviewIssues.some((row) => row.section === issue.section)) {
        throw partnerError(400, 'VALIDATION_ERROR', `Issue section ${issue.section} is repeated`);
      }
      reviewIssues.push({ section: issue.section, note: note.slice(0, 300) });
    }
    const now = new Date();
    const updated = await this.partners.review({
      id: existing.id,
      status: 'REJECTED',
      reason: trimmed.slice(0, 500),
      reviewIssues,
      reviewedBy: reviewerId,
      now,
    });
    if (!updated) {
      throw notSubmittedError();
    }
    await this.ensureGrant(existing.userId, existing.role, 'SUSPENDED');
    return toView(updated);
  }

  private async requireSubmitted(applicationId: string): Promise<PartnerApplicationRecord> {
    const existing = await this.partners.findById(applicationId);
    if (!existing) {
      throw partnerError(404, 'PARTNER_APPLICATION_NOT_FOUND', 'Partner application not found');
    }
    if (existing.status !== 'SUBMITTED') {
      throw notSubmittedError();
    }
    return existing;
  }

  private async ensureGrant(
    userId: string,
    role: PartnerRoleName,
    status: 'ACTIVE' | 'SUSPENDED',
  ): Promise<void> {
    const grants = await this.identity.listGrants(userId);
    const existing = grants.find((grant) => grant.role === role);
    if (!existing) {
      try {
        await this.identity.insertGrant(userId, role, status);
      } catch (error) {
        if (!(error instanceof UniqueConflictError)) {
          throw error;
        }
        const raced = (await this.identity.listGrants(userId)).find((grant) => grant.role === role);
        if (raced && raced.status !== status) {
          await this.identity.updateGrantStatus(raced.id, status);
        }
      }
      return;
    }
    if (existing.status !== status) {
      await this.identity.updateGrantStatus(existing.id, status);
    }
  }
}

function toView(row: PartnerApplicationRecord): PartnerApplicationView {
  const metadata = { ...row.metadata };
  const rawPhone =
    (typeof metadata.phone === 'string' && metadata.phone) ||
    (typeof metadata.phoneNumber === 'string' && metadata.phoneNumber) ||
    undefined;
  if (rawPhone && !metadata.phoneMasked) {
    metadata.phoneMasked = maskPhone(rawPhone);
  }
  return {
    id: row.id,
    role: row.role,
    status: row.status,
    metadata,
    documents: row.documents.map((doc, index) => ({
      index,
      kind: doc.kind ?? null,
      label: doc.label,
      contentType: doc.contentType,
      sizeBytes: doc.sizeBytes,
      uploadedAt: doc.uploadedAt,
      hasFile: hasStoredFile(doc),
    })),
    reason: row.reason,
    issues: row.reviewIssues.map((issue) => ({ ...issue })),
    reviewedBy: row.reviewedBy,
    reviewedAt: row.reviewedAt?.toISOString() ?? null,
    submittedAt: row.submittedAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

function sanitizeMetadata(metadata: Record<string, unknown>): Record<string, unknown> {
  const entries = Object.entries(metadata).slice(0, 40);
  const result: Record<string, unknown> = {};
  for (const [key, value] of entries) {
    if (key.length > 64) {
      continue;
    }
    if (
      value === null ||
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    ) {
      result[key] = typeof value === 'string' ? value.slice(0, 500) : value;
    }
  }
  return result;
}

function notSubmittedError(): HttpException {
  return partnerError(
    409,
    'PARTNER_APPLICATION_NOT_SUBMITTED',
    'Only submitted applications can be reviewed',
  );
}

/** Pre-DEC-PROD-020 refs were `mock://`/`s3://` URIs without stored bytes. */
function hasStoredFile(doc: PartnerDocumentRef): boolean {
  return !doc.key.includes('://');
}

function cryptoRandomId(): string {
  return globalThis.crypto.randomUUID();
}
