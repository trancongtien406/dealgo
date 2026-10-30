import { randomUUID } from 'node:crypto';
import type { StoredDocumentRef } from '../../platform/storage/document-store.service.js';

/** t54u: the ops "All" filter — every reviewable status (drafts are only listed explicitly). */
export const OPS_ALL_STATUSES = ['SUBMITTED', 'IN_REVIEW', 'APPROVED', 'REJECTED'] as const;

/** A stored upload tagged with its document kind (ID_FRONT, LICENSE, ...). */
export type PartnerDocumentRef = StoredDocumentRef & { kind?: string };

export type PartnerReviewIssue = { section: string; note: string };

export type PartnerRoleName = 'DRIVER' | 'MERCHANT';
export type PartnerStatusName = 'DRAFT' | 'SUBMITTED' | 'IN_REVIEW' | 'APPROVED' | 'REJECTED';

/** Statuses a reviewer may still decide on (t52u: SUBMITTED or claimed IN_REVIEW). */
export const PARTNER_REVIEWABLE_STATUSES: readonly PartnerStatusName[] = ['SUBMITTED', 'IN_REVIEW'];

/** Append-only OpsAuditLog row written in the same transaction as the decision. */
export type PartnerReviewAudit = {
  actorUserId: string;
  action: 'KYC_CLAIM' | 'KYC_APPROVE' | 'KYC_REJECT' | 'KYC_AUTO_APPROVE';
  reason: string;
  metadata: Record<string, unknown>;
};

export type PartnerApplicationRecord = {
  id: string;
  userId: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: Record<string, unknown>;
  documents: PartnerDocumentRef[];
  reason: string | null;
  reviewIssues: PartnerReviewIssue[];
  reviewedBy: string | null;
  reviewedAt: Date | null;
  submittedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
};

export type OpsPartnerPage = {
  items: PartnerApplicationRecord[];
  total: number;
};

export type PartnerRepository = {
  findByUserAndRole(userId: string, role: PartnerRoleName): Promise<PartnerApplicationRecord | null>;
  listByUser(userId: string): Promise<PartnerApplicationRecord[]>;
  listByStatus(status: PartnerStatusName): Promise<PartnerApplicationRecord[]>;
  listForOps(input: {
    status: PartnerStatusName | 'ALL';
    page: number;
    limit: number;
    q?: string;
    role?: PartnerRoleName;
  }): Promise<OpsPartnerPage>;
  findById(id: string): Promise<PartnerApplicationRecord | null>;
  upsertSubmit(input: {
    id: string;
    userId: string;
    role: PartnerRoleName;
    metadata: Record<string, unknown>;
    documents: PartnerDocumentRef[];
    now: Date;
  }): Promise<PartnerApplicationRecord>;
  review(input: {
    id: string;
    status: Extract<PartnerStatusName, 'APPROVED' | 'REJECTED'>;
    reason: string | null;
    reviewIssues: PartnerReviewIssue[];
    reviewedBy: string | null;
    now: Date;
    /** Approval only: replaces metadata (e.g. ops-confirmed vehicleClassCode). */
    metadata?: Record<string, unknown>;
    audit?: PartnerReviewAudit;
  }): Promise<PartnerApplicationRecord | null>;
  /** SUBMITTED → IN_REVIEW, conditional; null when the case is not SUBMITTED. */
  claim(input: {
    id: string;
    reviewerId: string;
    now: Date;
    audit?: PartnerReviewAudit;
  }): Promise<PartnerApplicationRecord | null>;
  /** Queues the decision event for the applicant's realtime `user:` room (outbox). */
  recordStatusEvent(input: PartnerStatusEventInput): Promise<void>;
};

export type PartnerStatusEventInput = {
  applicationId: string;
  userId: string;
  role: PartnerRoleName;
  status: 'IN_REVIEW' | 'APPROVED' | 'REJECTED';
  /** t61u: rejection reason + flagged sections ride on the realtime event. */
  reason?: string | null;
  sections?: string[];
  reviewedAt: Date;
};

type Stored = PartnerApplicationRecord;

export class MemoryPartnerRepository implements PartnerRepository {
  private readonly byId = new Map<string, Stored>();
  /** Decision events (tests read this; the Prisma repository writes outbox rows). */
  readonly statusEvents: PartnerStatusEventInput[] = [];
  /** Ops audit rows (the Prisma repository writes OpsAuditLog). */
  readonly auditLogs: (PartnerReviewAudit & { applicationId: string })[] = [];

  async claim(input: {
    id: string;
    reviewerId: string;
    now: Date;
    audit?: PartnerReviewAudit;
  }): Promise<PartnerApplicationRecord | null> {
    const existing = this.byId.get(input.id);
    if (!existing || existing.status !== 'SUBMITTED') {
      return null;
    }
    const updated: Stored = {
      ...existing,
      status: 'IN_REVIEW',
      reviewedBy: input.reviewerId,
      updatedAt: input.now,
    };
    this.byId.set(updated.id, updated);
    if (input.audit) {
      this.auditLogs.push({ ...input.audit, applicationId: input.id });
    }
    return copy(updated);
  }

  async recordStatusEvent(input: PartnerStatusEventInput): Promise<void> {
    this.statusEvents.push({ ...input });
  }

  async findByUserAndRole(
    userId: string,
    role: PartnerRoleName,
  ): Promise<PartnerApplicationRecord | null> {
    for (const row of this.byId.values()) {
      if (row.userId === userId && row.role === role) {
        return copy(row);
      }
    }
    return null;
  }

  async listByUser(userId: string): Promise<PartnerApplicationRecord[]> {
    return [...this.byId.values()]
      .filter((row) => row.userId === userId)
      .sort((a, b) => a.role.localeCompare(b.role))
      .map(copy);
  }

  async listByStatus(status: PartnerStatusName): Promise<PartnerApplicationRecord[]> {
    return [...this.byId.values()]
      .filter((row) => row.status === status)
      .sort(
        (a, b) =>
          (a.submittedAt?.getTime() ?? a.createdAt.getTime()) -
            (b.submittedAt?.getTime() ?? b.createdAt.getTime()) ||
          a.id.localeCompare(b.id),
      )
      .map(copy);
  }

  async listForOps(input: {
    status: PartnerStatusName | 'ALL';
    page: number;
    limit: number;
    q?: string;
    role?: PartnerRoleName;
  }): Promise<OpsPartnerPage> {
    let rows = [...this.byId.values()].filter((row) =>
      input.status === 'ALL'
        ? (OPS_ALL_STATUSES as readonly string[]).includes(row.status)
        : row.status === input.status,
    );
    if (input.role) {
      rows = rows.filter((row) => row.role === input.role);
    }
    if (input.q && input.q.trim()) {
      const q = input.q.trim().toLowerCase();
      rows = rows.filter(
        (row) =>
          row.id.toLowerCase().includes(q) ||
          row.userId.toLowerCase().includes(q) ||
          JSON.stringify(row.metadata).toLowerCase().includes(q),
      );
    }
    rows.sort(
      (a, b) =>
        (a.submittedAt?.getTime() ?? a.createdAt.getTime()) -
          (b.submittedAt?.getTime() ?? b.createdAt.getTime()) ||
        a.id.localeCompare(b.id),
    );
    const total = rows.length;
    const start = (input.page - 1) * input.limit;
    return {
      items: rows.slice(start, start + input.limit).map(copy),
      total,
    };
  }

  async findById(id: string): Promise<PartnerApplicationRecord | null> {
    const row = this.byId.get(id);
    return row ? copy(row) : null;
  }

  async upsertSubmit(input: {
    id: string;
    userId: string;
    role: PartnerRoleName;
    metadata: Record<string, unknown>;
    documents: PartnerDocumentRef[];
    now: Date;
  }): Promise<PartnerApplicationRecord> {
    const existing = await this.findByUserAndRole(input.userId, input.role);
    if (existing) {
      const updated: Stored = {
        ...existing,
        status: 'SUBMITTED',
        metadata: { ...input.metadata },
        documents: input.documents.map((doc) => ({ ...doc })),
        reason: null,
        reviewIssues: [],
        reviewedBy: null,
        reviewedAt: null,
        submittedAt: input.now,
        updatedAt: input.now,
      };
      this.byId.set(updated.id, updated);
      return copy(updated);
    }
    const created: Stored = {
      id: input.id || randomUUID(),
      userId: input.userId,
      role: input.role,
      status: 'SUBMITTED',
      metadata: { ...input.metadata },
      documents: input.documents.map((doc) => ({ ...doc })),
      reason: null,
      reviewIssues: [],
      reviewedBy: null,
      reviewedAt: null,
      submittedAt: input.now,
      createdAt: input.now,
      updatedAt: input.now,
    };
    this.byId.set(created.id, created);
    return copy(created);
  }

  async review(input: {
    id: string;
    status: Extract<PartnerStatusName, 'APPROVED' | 'REJECTED'>;
    reason: string | null;
    reviewIssues: PartnerReviewIssue[];
    reviewedBy: string | null;
    now: Date;
    metadata?: Record<string, unknown>;
    audit?: PartnerReviewAudit;
  }): Promise<PartnerApplicationRecord | null> {
    const existing = this.byId.get(input.id);
    // Conditional like the Prisma updateMany: only a pending row can be reviewed once.
    if (!existing || !PARTNER_REVIEWABLE_STATUSES.includes(existing.status)) {
      return null;
    }
    if (input.audit) {
      this.auditLogs.push({ ...input.audit, applicationId: input.id });
    }
    const updated: Stored = {
      ...existing,
      metadata: input.metadata ? { ...input.metadata } : existing.metadata,
      status: input.status,
      reason: input.reason,
      reviewIssues: input.reviewIssues.map((issue) => ({ ...issue })),
      reviewedBy: input.reviewedBy,
      reviewedAt: input.now,
      updatedAt: input.now,
    };
    this.byId.set(updated.id, updated);
    return copy(updated);
  }
}

function copy(row: Stored): PartnerApplicationRecord {
  return {
    ...row,
    metadata: { ...row.metadata },
    documents: row.documents.map((doc) => ({ ...doc })),
    reviewIssues: row.reviewIssues.map((issue) => ({ ...issue })),
    reviewedAt: row.reviewedAt ? new Date(row.reviewedAt) : null,
    submittedAt: row.submittedAt ? new Date(row.submittedAt) : null,
    createdAt: new Date(row.createdAt),
    updatedAt: new Date(row.updatedAt),
  };
}
