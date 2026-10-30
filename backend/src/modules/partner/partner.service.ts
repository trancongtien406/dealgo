import { HttpException, Inject, Injectable, Optional } from '@nestjs/common';
import { RideVehicleClassService } from '../ride-vehicle/ride-vehicle-class.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
} from '../identity/identity.repository.js';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import {
  PARTNER_DOCUMENT_KINDS,
  PARTNER_VIDEO_CONTENT_TYPES,
  PARTNER_VIDEO_DOCUMENT_KINDS,
  PARTNER_VIDEO_MAX_KB,
  PARTNER_ISSUE_SECTIONS,
  PARTNER_REPOSITORY,
  requiredPartnerDocuments,
  missingPartnerDocuments,
  documentAlternatives,
  PARTNER_AUTO_APPROVE_FIELDS,
  licenseClassCoversVehicle,
  LICENSE_CLASSES_FOR_VEHICLE,
} from './partner.constants.js';
import { vehicleClassCodeFromMetadata } from '../ride-vehicle/ride-vehicle-class.js';
import type {
  OpsPartnerApplicationQueryDto,
  PartnerReviewIssueDto,
  SubmitPartnerApplicationDto,
} from './partner.dto.js';
import { partnerError } from './partner.error.js';
import { shopPinFromMetadata } from './partner-shop-pin.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
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
import { PARTNER_REVIEWABLE_STATUSES } from './partner.repository.js';

export type PartnerApplicationView = {
  id: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: Record<string, unknown>;
  /** Ops case detail only: applicant's account phone. */
  applicantPhone?: string;
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
    @Optional() private readonly config?: ConfigService<AppEnv, true>,
    @Optional() private readonly vehicleClasses?: RideVehicleClassService,
    @Optional() private readonly settings?: PlatformSettingsService,
  ) {}

  /**
   * DEC-PROD-048 (DRAFT): admin switch ONBOARDING_DRIVER_KYC_REQUIRED /
   * ONBOARDING_MERCHANT_KYB_REQUIRED. Fails closed (documents required) when settings are absent.
   */
  async documentsRequired(role: PartnerRoleName): Promise<boolean> {
    if (!this.settings) {
      return true;
    }
    const key =
      role === 'DRIVER'
        ? 'ONBOARDING_DRIVER_KYC_REQUIRED'
        : 'ONBOARDING_MERCHANT_KYB_REQUIRED';
    try {
      const raw = await this.settings.getJson<unknown>(key);
      return raw !== false;
    } catch {
      return true;
    }
  }

  /**
   * t61u (AGENT_PROPOSED): admin switch KYC_AUTO_APPROVE_DRIVER / KYC_AUTO_APPROVE_MERCHANT.
   * Fails closed (manual review) when settings are absent or unreadable.
   */
  async autoApproveEnabled(role: PartnerRoleName): Promise<boolean> {
    if (!this.settings) {
      return false;
    }
    try {
      const raw = await this.settings.getJson<unknown>(
        role === 'DRIVER' ? 'KYC_AUTO_APPROVE_DRIVER' : 'KYC_AUTO_APPROVE_MERCHANT',
      );
      return raw === true;
    } catch {
      return false;
    }
  }

  async requirements(
    role: PartnerRoleName,
    vehicleClassCode?: string,
    registrationSubject?: string,
  ): Promise<{
    role: PartnerRoleName;
    documentsRequired: boolean;
    requiredDocuments: readonly string[];
    /** t61u: kind → kinds accepted instead (e.g. FOOD_SAFETY_CERT ← FOOD_SAFETY_COMMITMENT). */
    documentAlternatives: Record<string, readonly string[]>;
    vehicleClassRequired: boolean;
    autoApprove: boolean;
  }> {
    const documentsRequired = await this.documentsRequired(role);
    return {
      role,
      documentsRequired,
      requiredDocuments: documentsRequired
        ? requiredPartnerDocuments(role, {
            vehicleClassCode:
              vehicleClassCode?.trim().toUpperCase() || undefined,
            carExtraDocsGate: this.carExtraDocsGateEnabled(),
          })
        : [],
      documentAlternatives: documentsRequired
        ? documentAlternatives(role, { registrationSubject })
        : {},
      vehicleClassRequired: role === 'DRIVER',
      autoApprove: await this.autoApproveEnabled(role),
    };
  }

  async listMine(
    userId: string,
  ): Promise<{ applications: PartnerApplicationView[] }> {
    const rows = await this.partners.listByUser(userId);
    return { applications: rows.map(toView) };
  }

  async getMine(
    userId: string,
    role: PartnerRoleName,
  ): Promise<PartnerApplicationView> {
    const row = await this.partners.findByUserAndRole(userId, role);
    if (!row) {
      throw partnerError(
        404,
        'PARTNER_APPLICATION_NOT_FOUND',
        'Partner application not found',
      );
    }
    return toView(row);
  }

  async submit(
    userId: string,
    dto: SubmitPartnerApplicationDto,
  ): Promise<PartnerApplicationView> {
    const existing = await this.partners.findByUserAndRole(userId, dto.role);
    if (existing?.status === 'APPROVED') {
      throw partnerError(
        409,
        'PARTNER_APPLICATION_ALREADY_APPROVED',
        'An approved application already exists for this role',
      );
    }
    if (existing && PARTNER_REVIEWABLE_STATUSES.includes(existing.status)) {
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
        throw partnerError(
          400,
          'VALIDATION_ERROR',
          `Document kind ${upload.kind} is not valid for ${dto.role}`,
        );
      }
      if (seen.has(upload.kind)) {
        throw partnerError(
          400,
          'VALIDATION_ERROR',
          `Document kind ${upload.kind} is sent twice`,
        );
      }
      seen.add(upload.kind);
    }
    // A resubmission only re-sends the documents ops flagged; the rest stay on file.
    const kept = (existing?.documents ?? []).filter(
      (doc) =>
        doc.kind &&
        allowedKinds.includes(doc.kind) &&
        !seen.has(doc.kind) &&
        hasStoredFile(doc),
    );
    const onFile = new Set([...seen, ...kept.map((doc) => doc.kind!)]);
    const previewClass =
      dto.role === 'DRIVER'
        ? vehicleClassCodeFromMetadata(sanitizeMetadata(dto.metadata))
        : undefined;
    if (dto.role === 'DRIVER' && !previewClass) {
      throw partnerError(
        400,
        'VALIDATION_ERROR',
        'Driver KYC requires a valid vehicleClassCode (MOTORBIKE | CAR_4 | CAR_7)',
      );
    }
    if (
      dto.role === 'MERCHANT' &&
      !shopPinFromMetadata(sanitizeMetadata(dto.metadata))
    ) {
      // Like GrabFood/ShopeeFood merchant sign-up, the shop must be pinned on the map —
      // delivery fares, distance caps and driver pickup all need real coordinates.
      throw partnerError(
        400,
        'PARTNER_SHOP_LOCATION_REQUIRED',
        'Merchant KYB requires the shop pinned on the map (shopLat/shopLng inside Vietnam)',
      );
    }
    const documentsRequired = await this.documentsRequired(dto.role);
    const missing = documentsRequired
      ? missingPartnerDocuments(dto.role, onFile, {
          vehicleClassCode: previewClass ?? undefined,
          carExtraDocsGate: this.carExtraDocsGateEnabled(),
          registrationSubject: sanitizeMetadata(dto.metadata).registrationSubject,
        })
      : [];
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
    if (
      documentsRequired &&
      previewClass &&
      !licenseClassCoversVehicle(sanitizeMetadata(dto.metadata)?.licenseClass, previewClass)
    ) {
      // t60u: a motorbike licence (A1/A) cannot drive CAR_4/CAR_7 and vice versa.
      throw new HttpException(
        {
          message: `Licence class must cover ${previewClass} (${LICENSE_CLASSES_FOR_VEHICLE[previewClass].join(', ')})`,
          errorCode: 'PARTNER_LICENSE_CLASS_MISMATCH',
          details: { vehicleClassCode: previewClass, allowed: LICENSE_CLASSES_FOR_VEHICLE[previewClass] },
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
        ...((PARTNER_VIDEO_DOCUMENT_KINDS as readonly string[]).includes(
          upload.kind,
        )
          ? {
              policyOverride: {
                maxFileBytes: PARTNER_VIDEO_MAX_KB * 1024,
                allowedTypes: PARTNER_VIDEO_CONTENT_TYPES,
              },
            }
          : {}),
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
    const metadata = await this.bindVehicleClass(
      dto.role,
      sanitizeMetadata(dto.metadata),
    );
    // Audit trail for ops: this application was submitted while documents were waived.
    metadata.documentsWaived = !documentsRequired;
    // t56u: no AI verdict exists; never store a client-supplied one.
    delete metadata.aiPrecheck;
    delete metadata.autoApproved;
    delete metadata.autoApprovedAt;
    delete metadata.autoApproveSkipped;
    // t61u: auto-approval only for a complete, valid submission; otherwise the manual queue
    // shows why the system did not decide.
    let autoApproveCandidate = false;
    if (documentsRequired && (await this.autoApproveEnabled(dto.role))) {
      const blockers = autoApproveBlockers(dto.role, metadata, documents);
      if (blockers.length === 0) {
        autoApproveCandidate = true;
      } else {
        metadata.autoApproveSkipped = blockers.join(',');
      }
    }
    let saved;
    try {
      saved = await this.partners.upsertSubmit({
        id: applicationId,
        userId,
        role: dto.role,
        metadata,
        documents,
        now,
      });
    } catch (error) {
      await this.documents.discard(fresh);
      throw error;
    }
    // Files the new upload replaced are no longer referenced by any application.
    await this.documents.discard(
      (existing?.documents ?? []).filter(
        (doc) => doc.kind && seen.has(doc.kind) && hasStoredFile(doc),
      ),
    );
    if (autoApproveCandidate) {
      const approved = await this.autoApprove(saved);
      if (approved) {
        return approved;
      }
    }
    return toView(saved);
  }

  /**
   * t61u: the system approves a complete, valid submission (KYC_AUTO_APPROVE_* ON).
   * Same transaction rules as a manual approval; audit actor = SYSTEM (the row's actorUserId is
   * the applicant because ops_audit_logs.actorUserId is a non-null FK to users).
   */
  private async autoApprove(
    saved: PartnerApplicationRecord,
  ): Promise<PartnerApplicationView | null> {
    const now = new Date();
    const metadata = {
      ...saved.metadata,
      autoApproved: true,
      autoApprovedAt: now.toISOString(),
    };
    delete (metadata as Record<string, unknown>).autoApproveSkipped;
    const updated = await this.partners.review({
      metadata,
      id: saved.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: null,
      now,
      audit: {
        actorUserId: saved.userId,
        action: 'KYC_AUTO_APPROVE',
        reason: 'auto-approve: complete and valid submission',
        metadata: {
          role: saved.role,
          actor: 'SYSTEM',
          ...(typeof saved.metadata.vehicleClassCode === 'string'
            ? { vehicleClassCode: saved.metadata.vehicleClassCode }
            : {}),
        },
      },
    });
    if (!updated) {
      // An ops reviewer claimed or decided it in between: leave it to them.
      return null;
    }
    await this.ensureGrant(saved.userId, saved.role, 'ACTIVE');
    await this.partners.recordStatusEvent({
      applicationId: saved.id,
      userId: saved.userId,
      role: saved.role,
      status: 'APPROVED',
      reviewedAt: now,
    });
    return toView(updated);
  }

  /** t52u: a reviewer takes a SUBMITTED case (→ IN_REVIEW); the applicant is told in realtime. */
  async claim(
    applicationId: string,
    reviewerId: string,
  ): Promise<PartnerApplicationView> {
    const existing = await this.partners.findById(applicationId);
    if (!existing) {
      throw partnerError(
        404,
        'PARTNER_APPLICATION_NOT_FOUND',
        'Partner application not found',
      );
    }
    if (existing.status !== 'SUBMITTED') {
      throw partnerError(
        409,
        'PARTNER_APPLICATION_NOT_CLAIMABLE',
        'Only submitted applications can be claimed',
      );
    }
    const now = new Date();
    const updated = await this.partners.claim({
      id: existing.id,
      reviewerId,
      now,
      audit: {
        actorUserId: reviewerId,
        action: 'KYC_CLAIM',
        reason: 'claim',
        metadata: { role: existing.role },
      },
    });
    if (!updated) {
      throw partnerError(
        409,
        'PARTNER_APPLICATION_NOT_CLAIMABLE',
        'Only submitted applications can be claimed',
      );
    }
    await this.partners.recordStatusEvent({
      applicationId: existing.id,
      userId: existing.userId,
      role: existing.role,
      status: 'IN_REVIEW',
      reviewedAt: now,
    });
    return toView(updated);
  }

  /** Ops-only: bytes of one stored document for review. */
  async readDocumentForOps(
    applicationId: string,
    index: number,
  ): Promise<{ body: Buffer; contentType: string; filename: string }> {
    const existing = await this.partners.findById(applicationId);
    const doc = existing?.documents[index];
    if (!existing || !doc) {
      throw partnerError(
        404,
        'PARTNER_DOCUMENT_NOT_FOUND',
        'Document not found',
      );
    }
    const file = await this.documents.read(doc);
    if (!file) {
      throw partnerError(
        404,
        'PARTNER_DOCUMENT_NOT_FOUND',
        'Document file is not stored',
      );
    }
    const ext = doc.key.includes('.')
      ? doc.key.slice(doc.key.lastIndexOf('.') + 1)
      : 'bin';
    return {
      ...file,
      filename: `${(doc.kind ?? 'document').toLowerCase()}-${index}.${ext}`,
    };
  }

  async listForOps(
    query?: OpsPartnerApplicationQueryDto | PartnerStatusName,
  ): Promise<{
    applications: PartnerApplicationView[];
    total: number;
    page: number;
    limit: number;
  }> {
    const opts: OpsPartnerApplicationQueryDto =
      typeof query === 'string' ? { status: query } : (query ?? {});
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
      applications: await Promise.all(
        result.items.map((row) => this.toOpsView(row, false)),
      ),
      total: result.total,
      page,
      limit,
    };
  }

  async getForOps(applicationId: string): Promise<PartnerApplicationView> {
    const existing = await this.partners.findById(applicationId);
    if (!existing) {
      throw partnerError(
        404,
        'PARTNER_APPLICATION_NOT_FOUND',
        'Partner application not found',
      );
    }
    return this.toOpsView(existing, true);
  }

  /**
   * Ops views carry the applicant's account phone: the mobile forms never ask
   * for it again, so metadata alone left the KYC queue/detail without one.
   * Lists get the masked phone; the case detail also gets the full number so
   * the reviewer can call the applicant.
   */
  private async toOpsView(
    row: PartnerApplicationRecord,
    withFullPhone: boolean,
  ): Promise<PartnerApplicationView> {
    const view = toView(row);
    let phone: string | null = null;
    try {
      phone = (await this.identity.findUserById(row.userId))?.phone ?? null;
    } catch {
      phone = null;
    }
    if (phone) {
      if (!view.metadata.phoneMasked) {
        view.metadata.phoneMasked = maskPhone(phone);
      }
      if (withFullPhone) {
        view.applicantPhone = phone;
      }
    }
    return view;
  }

  async approve(
    applicationId: string,
    reviewerId: string,
    vehicleClassCode?: string,
  ): Promise<PartnerApplicationView> {
    const existing = await this.requireSubmitted(applicationId);
    const now = new Date();
    let metadata: Record<string, unknown> | undefined;
    if (existing.role === 'DRIVER') {
      // DEC-PROD-048: a driver is never approved without a valid vehicle class (fail closed).
      const requested = vehicleClassCode?.trim().toUpperCase();
      const base = requested
        ? { ...existing.metadata, vehicleClassCode: requested }
        : { ...existing.metadata };
      if (!vehicleClassCodeFromMetadata(base)) {
        throw partnerError(
          400,
          'PARTNER_VEHICLE_CLASS_REQUIRED',
          'Approve a driver only with a valid vehicleClassCode (MOTORBIKE | CAR_4 | CAR_7)',
        );
      }
      const finalClass = vehicleClassCodeFromMetadata(base)!;
      const declaredLicense = (base as Record<string, unknown>).licenseClass;
      if (
        typeof declaredLicense === 'string' &&
        declaredLicense.trim() &&
        !licenseClassCoversVehicle(declaredLicense, finalClass)
      ) {
        // t60u: ops cannot bind a class the declared licence does not cover.
        throw partnerError(
          400,
          'PARTNER_LICENSE_CLASS_MISMATCH',
          `Licence class ${declaredLicense} does not cover ${finalClass}`,
        );
      }
      const bound = await this.bindVehicleClass('DRIVER', base);
      if (requested) {
        bound.vehicleClassConfirmedBy = reviewerId;
      }
      metadata = bound;
    }
    const updated = await this.partners.review({
      metadata,
      id: existing.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: reviewerId,
      now,
      audit: {
        actorUserId: reviewerId,
        action: 'KYC_APPROVE',
        reason: 'approve',
        metadata: {
          role: existing.role,
          ...(vehicleClassCode ? { vehicleClassCode } : {}),
        },
      },
    });
    if (!updated) {
      throw notSubmittedError();
    }
    await this.ensureGrant(existing.userId, existing.role, 'ACTIVE');
    // After the grant so the app's REST refetch already sees the active role.
    await this.partners.recordStatusEvent({
      applicationId: existing.id,
      userId: existing.userId,
      role: existing.role,
      status: 'APPROVED',
      reviewedAt: now,
    });
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
      throw partnerError(
        400,
        'VALIDATION_ERROR',
        'Rejection reason is required',
      );
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
        throw partnerError(
          400,
          'VALIDATION_ERROR',
          `Issue section ${issue.section} is repeated`,
        );
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
      audit: {
        actorUserId: reviewerId,
        action: 'KYC_REJECT',
        reason: trimmed.slice(0, 500),
        metadata: {
          role: existing.role,
          sections: reviewIssues.map((issue) => issue.section),
        },
      },
    });
    if (!updated) {
      throw notSubmittedError();
    }
    await this.ensureGrant(existing.userId, existing.role, 'SUSPENDED');
    await this.partners.recordStatusEvent({
      applicationId: existing.id,
      userId: existing.userId,
      role: existing.role,
      status: 'REJECTED',
      reason: trimmed.slice(0, 500),
      sections: reviewIssues.map((issue) => issue.section),
      reviewedAt: now,
    });
    return toView(updated);
  }

  private async requireSubmitted(
    applicationId: string,
  ): Promise<PartnerApplicationRecord> {
    const existing = await this.partners.findById(applicationId);
    if (!existing) {
      throw partnerError(
        404,
        'PARTNER_APPLICATION_NOT_FOUND',
        'Partner application not found',
      );
    }
    if (!PARTNER_REVIEWABLE_STATUSES.includes(existing.status)) {
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
        const raced = (await this.identity.listGrants(userId)).find(
          (grant) => grant.role === role,
        );
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

  /**
   * OPEN-006 Car KYC extra-docs gate (fail closed in production when unset).
   * Mirrors PARTNER_ELIGIBILITY_BYPASS defaults — no secrets invented.
   */
  private carExtraDocsGateEnabled(): boolean {
    if (!this.config) {
      return false;
    }
    const explicit = this.config.get('PARTNER_CAR_KYC_EXTRA_DOCS', {
      infer: true,
    });
    if (explicit !== undefined) {
      return explicit;
    }
    return this.config.get('NODE_ENV', { infer: true }) === 'production';
  }

  private async bindVehicleClass(
    role: PartnerRoleName,
    metadata: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    if (role !== 'DRIVER' || !this.vehicleClasses) {
      return metadata;
    }
    const raw = metadata.vehicleClassCode;
    if (typeof raw !== 'string' || !raw.trim()) {
      return metadata;
    }
    const vehicle = await this.vehicleClasses.findEnabled(raw);
    if (!vehicle) {
      throw partnerError(
        400,
        'PARTNER_VEHICLE_CLASS_UNKNOWN',
        'Vehicle class is not available',
      );
    }
    return {
      ...metadata,
      vehicleClassCode: vehicle.code,
      vehicleType: vehicle.name,
    };
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

function sanitizeMetadata(
  metadata: Record<string, unknown>,
): Record<string, unknown> {
  const entries = Object.entries(metadata).slice(0, 64);
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

/**
 * t61u: why a submission cannot be auto-approved (empty = eligible). Documents were already
 * checked for presence/type/size by submit; this adds stored bytes, required confirmed fields,
 * the licence/vehicle match and any on-device capture check the app reported as failed.
 */
export function autoApproveBlockers(
  role: PartnerRoleName,
  metadata: Record<string, unknown>,
  documents: readonly PartnerDocumentRef[],
): string[] {
  const blockers: string[] = [];
  if (documents.some((doc) => !hasStoredFile(doc))) {
    blockers.push('DOCUMENT_NOT_STORED');
  }
  for (const field of PARTNER_AUTO_APPROVE_FIELDS[role]) {
    const value = metadata[field];
    if (typeof value !== 'string' || !value.trim()) {
      blockers.push(`FIELD_${field}`);
    }
  }
  if (role === 'DRIVER') {
    const idNumber = metadata.idNumber;
    if (typeof idNumber === 'string' && idNumber.trim() && !/^\d{12}$/.test(idNumber.trim())) {
      blockers.push('ID_NUMBER_FORMAT');
    }
    const vehicleClass = vehicleClassCodeFromMetadata(metadata);
    if (!vehicleClass) {
      blockers.push('VEHICLE_CLASS');
    } else if (!licenseClassCoversVehicle(metadata.licenseClass, vehicleClass)) {
      blockers.push('LICENSE_CLASS_MISMATCH');
    }
  } else if (!shopPinFromMetadata(metadata)) {
    blockers.push('SHOP_LOCATION');
  }
  for (const [key, value] of Object.entries(metadata)) {
    if (key.startsWith('capture') && value === false) {
      blockers.push(`DEVICE_${key}`);
    }
  }
  return blockers;
}
