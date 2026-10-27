import type { Prisma } from '../../generated/prisma/client.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type {
  OpsPartnerPage,
  PartnerDocumentRef,
  PartnerReviewIssue,
  PartnerApplicationRecord,
  PartnerRepository,
  PartnerRoleName,
  PartnerStatusEventInput,
  PartnerStatusName,
} from './partner.repository.js';
import { writePartnerStatusOutbox } from '../communication/outbox/outbox.write.js';

type Db = NonNullable<PrismaClient>;

function asInputJson(value: unknown): Prisma.InputJsonValue {
  return value as Prisma.InputJsonValue;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class PrismaPartnerRepository implements PartnerRepository {
  constructor(private readonly db: Db) {}

  async findByUserAndRole(
    userId: string,
    role: PartnerRoleName,
  ): Promise<PartnerApplicationRecord | null> {
    const row = await this.db.partnerApplication.findUnique({
      where: { userId_role: { userId, role } },
    });
    return row ? mapRow(row) : null;
  }

  async listByUser(userId: string): Promise<PartnerApplicationRecord[]> {
    const rows = await this.db.partnerApplication.findMany({
      where: { userId },
      orderBy: [{ role: 'asc' }],
    });
    return rows.map(mapRow);
  }

  async listByStatus(status: PartnerStatusName): Promise<PartnerApplicationRecord[]> {
    const rows = await this.db.partnerApplication.findMany({
      where: { status },
      orderBy: [{ submittedAt: 'asc' }, { id: 'asc' }],
    });
    return rows.map(mapRow);
  }

  async listForOps(input: {
    status: PartnerStatusName;
    page: number;
    limit: number;
    q?: string;
    role?: PartnerRoleName;
  }): Promise<OpsPartnerPage> {
    const where: Prisma.PartnerApplicationWhereInput = {
      status: input.status,
    };
    if (input.role) {
      where.role = input.role;
    }

    const q = input.q?.trim();
    if (q) {
      const isUuid = UUID_RE.test(q);
      const orClauses: Prisma.PartnerApplicationWhereInput[] = [
        { user: { displayName: { contains: q, mode: 'insensitive' } } },
        { user: { email: { contains: q, mode: 'insensitive' } } },
        { user: { phone: { contains: q, mode: 'insensitive' } } },
        { reason: { contains: q, mode: 'insensitive' } },
      ];
      if (isUuid) {
        orClauses.push({ id: q }, { userId: q });
      }
      where.OR = orClauses;
    }

    const [total, rows] = await Promise.all([
      this.db.partnerApplication.count({ where }),
      this.db.partnerApplication.findMany({
        where,
        orderBy: [{ submittedAt: 'asc' }, { id: 'asc' }],
        skip: (input.page - 1) * input.limit,
        take: input.limit,
      }),
    ]);

    return {
      items: rows.map(mapRow),
      total,
    };
  }

  async findById(id: string): Promise<PartnerApplicationRecord | null> {
    const row = await this.db.partnerApplication.findUnique({ where: { id } });
    return row ? mapRow(row) : null;
  }

  async upsertSubmit(input: {
    id: string;
    userId: string;
    role: PartnerRoleName;
    metadata: Record<string, unknown>;
    documents: PartnerDocumentRef[];
    now: Date;
  }): Promise<PartnerApplicationRecord> {
    const row = await this.db.partnerApplication.upsert({
      where: { userId_role: { userId: input.userId, role: input.role } },
      create: {
        id: input.id,
        userId: input.userId,
        role: input.role,
        status: 'SUBMITTED',
        metadata: asInputJson(input.metadata),
        documents: asInputJson(input.documents),
        submittedAt: input.now,
      },
      update: {
        status: 'SUBMITTED',
        metadata: asInputJson(input.metadata),
        documents: asInputJson(input.documents),
        reason: null,
        reviewIssues: asInputJson([]),
        reviewedBy: null,
        reviewedAt: null,
        submittedAt: input.now,
      },
    });
    return mapRow(row);
  }

  async recordStatusEvent(input: PartnerStatusEventInput): Promise<void> {
    await writePartnerStatusOutbox(this.db, input);
  }

  async review(input: {
    id: string;
    status: Extract<PartnerStatusName, 'APPROVED' | 'REJECTED'>;
    reason: string | null;
    reviewIssues: PartnerReviewIssue[];
    reviewedBy: string;
    now: Date;
    metadata?: Record<string, unknown>;
  }): Promise<PartnerApplicationRecord | null> {
    // Conditional on SUBMITTED so concurrent approve/reject cannot both win.
    const updated = await this.db.partnerApplication.updateMany({
      where: { id: input.id, status: 'SUBMITTED' },
      data: {
        status: input.status,
        reason: input.reason,
        reviewIssues: asInputJson(input.reviewIssues),
        reviewedBy: input.reviewedBy,
        reviewedAt: input.now,
        ...(input.metadata ? { metadata: asInputJson(input.metadata) } : {}),
      },
    });
    if (updated.count !== 1) {
      return null;
    }
    const row = await this.db.partnerApplication.findUnique({ where: { id: input.id } });
    return row ? mapRow(row) : null;
  }
}

function mapRow(row: {
  id: string;
  userId: string;
  role: PartnerRoleName;
  status: PartnerStatusName;
  metadata: unknown;
  documents: unknown;
  reason: string | null;
  reviewIssues: unknown;
  reviewedBy: string | null;
  reviewedAt: Date | null;
  submittedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}): PartnerApplicationRecord {
  return {
    id: row.id,
    userId: row.userId,
    role: row.role,
    status: row.status,
    metadata: asObject(row.metadata),
    documents: asDocuments(row.documents),
    reason: row.reason,
    reviewIssues: asIssues(row.reviewIssues),
    reviewedBy: row.reviewedBy,
    reviewedAt: row.reviewedAt,
    submittedAt: row.submittedAt,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function asObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }
  return {};
}

function asIssues(value: unknown): PartnerReviewIssue[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.flatMap((item) => {
    if (!item || typeof item !== 'object') {
      return [];
    }
    const { section, note } = item as { section?: unknown; note?: unknown };
    return typeof section === 'string' && typeof note === 'string' ? [{ section, note }] : [];
  });
}

function asDocuments(value: unknown): PartnerDocumentRef[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isDocumentRef);
}

function isDocumentRef(value: unknown): value is PartnerDocumentRef {
  if (!value || typeof value !== 'object') {
    return false;
  }
  const doc = value as Partial<PartnerDocumentRef>;
  return (
    typeof doc.key === 'string' &&
    typeof doc.label === 'string' &&
    typeof doc.contentType === 'string' &&
    typeof doc.sizeBytes === 'number' &&
    typeof doc.uploadedAt === 'string'
  );
}
