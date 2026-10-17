import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
} from '../identity/identity.repository.js';
import { KYC_STORAGE, PARTNER_REPOSITORY } from './partner.constants.js';
import type {
  OpsPartnerApplicationQueryDto,
  SubmitPartnerApplicationDto,
} from './partner.dto.js';
import { partnerError } from './partner.error.js';
import type { KycStorage } from '../../integrations/object-storage/mock-kyc-storage.js';
import { maskPhone } from '../../shared/privacy/pii-mask.js';
import type {
  PartnerApplicationRecord,
  PartnerRepository,
  PartnerRoleName,
  PartnerStatusName,
} from './partner.repository.js';

export type PartnerApplicationView = {
  id: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: Record<string, unknown>;
  documents: Array<{
    key: string;
    label: string;
    contentType: string;
    sizeBytes: number;
    uploadedAt: string;
  }>;
  reason: string | null;
  reviewedBy: string | null;
  reviewedAt: string | null;
  submittedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

/**
 * Rejection policy: REJECTED sets (or keeps) the matching RoleGrant at SUSPENDED.
 * APPROVED upserts/updates the matching RoleGrant to ACTIVE.
 * This matches ops role-grant reject semantics (no REJECTED grant status in schema).
 */
@Injectable()
export class PartnerService {
  constructor(
    @Inject(PARTNER_REPOSITORY) private readonly partners: PartnerRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(KYC_STORAGE) private readonly storage: KycStorage,
    private readonly config: ConfigService<AppEnv, true>,
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
    this.assertStorageAllowed();
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

    const applicationId = existing?.id ?? cryptoRandomId();
    const documents = await this.storage.storeDocuments(applicationId, dto.documents ?? []);
    const now = new Date();
    const saved = await this.partners.upsertSubmit({
      id: applicationId,
      userId,
      role: dto.role,
      metadata: sanitizeMetadata(dto.metadata),
      documents,
      now,
    });
    return toView(saved);
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
      reviewedBy: reviewerId,
      now,
    });
    if (!updated) {
      throw partnerError(404, 'PARTNER_APPLICATION_NOT_FOUND', 'Partner application not found');
    }
    await this.ensureGrant(existing.userId, existing.role, 'ACTIVE');
    return toView(updated);
  }

  async reject(
    applicationId: string,
    reviewerId: string,
    reason: string,
  ): Promise<PartnerApplicationView> {
    const existing = await this.requireSubmitted(applicationId);
    const trimmed = reason.trim();
    if (!trimmed) {
      throw partnerError(400, 'VALIDATION_ERROR', 'Rejection reason is required');
    }
    const now = new Date();
    const updated = await this.partners.review({
      id: existing.id,
      status: 'REJECTED',
      reason: trimmed.slice(0, 500),
      reviewedBy: reviewerId,
      now,
    });
    if (!updated) {
      throw partnerError(404, 'PARTNER_APPLICATION_NOT_FOUND', 'Partner application not found');
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
      throw partnerError(
        409,
        'PARTNER_APPLICATION_NOT_SUBMITTED',
        'Only submitted applications can be reviewed',
      );
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

  private assertStorageAllowed(): void {
    const provider = this.config.get('KYC_STORAGE_PROVIDER', { infer: true });
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    if (nodeEnv === 'production' && (provider === 'mock' || provider === undefined)) {
      throw partnerError(
        503,
        'KYC_STORAGE_UNAVAILABLE',
        'KYC storage is not configured for production',
      );
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
    documents: row.documents,
    reason: row.reason,
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

function cryptoRandomId(): string {
  return globalThis.crypto.randomUUID();
}
