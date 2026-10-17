import { randomUUID } from 'node:crypto';
import type { StoredDocumentRef } from '../../integrations/object-storage/mock-kyc-storage.js';

export type PartnerRoleName = 'DRIVER' | 'MERCHANT';
export type PartnerStatusName = 'DRAFT' | 'SUBMITTED' | 'APPROVED' | 'REJECTED';

export type PartnerApplicationRecord = {
  id: string;
  userId: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: Record<string, unknown>;
  documents: StoredDocumentRef[];
  reason: string | null;
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
    status: PartnerStatusName;
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
    documents: StoredDocumentRef[];
    now: Date;
  }): Promise<PartnerApplicationRecord>;
  review(input: {
    id: string;
    status: Extract<PartnerStatusName, 'APPROVED' | 'REJECTED'>;
    reason: string | null;
    reviewedBy: string;
    now: Date;
  }): Promise<PartnerApplicationRecord | null>;
};

type Stored = PartnerApplicationRecord;

export class MemoryPartnerRepository implements PartnerRepository {
  private readonly byId = new Map<string, Stored>();

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
    status: PartnerStatusName;
    page: number;
    limit: number;
    q?: string;
    role?: PartnerRoleName;
  }): Promise<OpsPartnerPage> {
    let rows = [...this.byId.values()].filter((row) => row.status === input.status);
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
    documents: StoredDocumentRef[];
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
    reviewedBy: string;
    now: Date;
  }): Promise<PartnerApplicationRecord | null> {
    const existing = this.byId.get(input.id);
    if (!existing) {
      return null;
    }
    const updated: Stored = {
      ...existing,
      status: input.status,
      reason: input.reason,
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
    reviewedAt: row.reviewedAt ? new Date(row.reviewedAt) : null,
    submittedAt: row.submittedAt ? new Date(row.submittedAt) : null,
    createdAt: new Date(row.createdAt),
    updatedAt: new Date(row.updatedAt),
  };
}
