import type { Prisma } from '../../generated/prisma/client.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import type { StoredDocumentRef } from '../../integrations/object-storage/mock-kyc-storage.js';
import type {
  OpsPartnerPage,
  PartnerApplicationRecord,
  PartnerRepository,
  PartnerRoleName,
  PartnerStatusName,
} from './partner.repository.js';

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
    documents: StoredDocumentRef[];
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
        reviewedBy: null,
        reviewedAt: null,
        submittedAt: input.now,
      },
    });
    return mapRow(row);
  }

  async review(input: {
    id: string;
    status: Extract<PartnerStatusName, 'APPROVED' | 'REJECTED'>;
    reason: string | null;
    reviewedBy: string;
    now: Date;
  }): Promise<PartnerApplicationRecord | null> {
    try {
      const row = await this.db.partnerApplication.update({
        where: { id: input.id },
        data: {
          status: input.status,
          reason: input.reason,
          reviewedBy: input.reviewedBy,
          reviewedAt: input.now,
        },
      });
      return mapRow(row);
    } catch {
      return null;
    }
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

function asDocuments(value: unknown): StoredDocumentRef[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter(isDocumentRef);
}

function isDocumentRef(value: unknown): value is StoredDocumentRef {
  if (!value || typeof value !== 'object') {
    return false;
  }
  const doc = value as Partial<StoredDocumentRef>;
  return (
    typeof doc.key === 'string' &&
    typeof doc.label === 'string' &&
    typeof doc.contentType === 'string' &&
    typeof doc.sizeBytes === 'number' &&
    typeof doc.uploadedAt === 'string'
  );
}
