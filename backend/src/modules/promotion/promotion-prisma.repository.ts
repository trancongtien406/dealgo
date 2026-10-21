import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import {
  PromotionCodeConflictError,
  type NewPromotion,
  type PromotionListFilter,
  type PromotionRepository,
} from './promotion.repository.js';
import type {
  PromotionCampaign,
  PromotionKpiSummary,
} from './promotion.types.js';
import {
  redeemVoucherInTx,
  releaseVoucherInTx,
  type ReleaseVoucherInput,
  type RedeemVoucherInput,
  type RedeemVoucherResult,
} from './promotion-redemption.js';

type DbPromotion = Prisma.PromotionGetPayload<object>;

export class PrismaPromotionRepository implements PromotionRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(
    filter: PromotionListFilter,
    page: number,
    limit: number,
  ): Promise<{ items: PromotionCampaign[]; total: number }> {
    const where = buildWhere(filter);
    const [rows, total] = await Promise.all([
      this.db.promotion.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.db.promotion.count({ where }),
    ]);
    return { items: rows.map(mapPromotion), total };
  }

  async kpi(): Promise<PromotionKpiSummary> {
    const [byStatus, sums] = await Promise.all([
      this.db.promotion.groupBy({ by: ['status'], _count: { _all: true } }),
      this.db.promotion.aggregate({
        _sum: { totalBudget: true, usedBudget: true, usedCount: true },
      }),
    ]);
    const count = (status: DbPromotion['status']) =>
      byStatus.find((row) => row.status === status)?._count._all ?? 0;
    return {
      totalCampaigns: byStatus.reduce((sum, row) => sum + row._count._all, 0),
      activeCount: count('ACTIVE'),
      scheduledCount: count('SCHEDULED'),
      endedCount: count('ENDED') + count('CANCELLED'),
      totalBudgetCommitted: sums._sum.totalBudget ?? 0,
      totalBudgetSpent: sums._sum.usedBudget ?? 0,
      totalRedemptions: sums._sum.usedCount ?? 0,
    };
  }

  async findById(id: string): Promise<PromotionCampaign | null> {
    const row = await this.db.promotion.findUnique({ where: { id } });
    return row ? mapPromotion(row) : null;
  }

  async listAvailable(now: Date, limit: number): Promise<PromotionCampaign[]> {
    const rows = await this.db.promotion.findMany({
      where: {
        status: 'ACTIVE',
        targetAudience: { in: ['ALL', 'CUSTOMER'] },
        startDate: { lte: now },
        endDate: { gt: now },
      },
      orderBy: [{ endDate: 'asc' }, { code: 'asc' }],
      // Usage/budget caps compare two columns; filter after a bounded read.
      take: limit * 4,
    });
    return rows
      .filter((row) => row.usedCount < row.usageLimit && row.usedBudget < row.totalBudget)
      .slice(0, limit)
      .map(mapPromotion);
  }

  async findByCode(code: string): Promise<PromotionCampaign | null> {
    const row = await this.db.promotion.findUnique({ where: { code } });
    return row ? mapPromotion(row) : null;
  }

  async create(input: NewPromotion): Promise<PromotionCampaign> {
    try {
      const row = await this.db.promotion.create({
        data: { ...input, maxDiscountAmount: input.maxDiscountAmount ?? null },
      });
      return mapPromotion(row);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new PromotionCodeConflictError();
      }
      throw error;
    }
  }

  async updateStatus(
    id: string,
    status: PromotionCampaign['status'],
  ): Promise<PromotionCampaign | null> {
    const updated = await this.db.promotion.updateMany({
      where: { id },
      data: { status },
    });
    if (updated.count === 0) {
      return null;
    }
    return this.findById(id);
  }

  async countUserRedemptions(promotionId: string, userId: string): Promise<number> {
    return this.db.promotionRedemption.count({
      where: { promotionId, userId, releasedAt: null },
    });
  }

  async redeem(input: RedeemVoucherInput): Promise<RedeemVoucherResult> {
    return this.db.$transaction((tx) => redeemVoucherInTx(tx, input));
  }

  async release(input: ReleaseVoucherInput): Promise<boolean> {
    return this.db.$transaction((tx) => releaseVoucherInTx(tx, input));
  }
}


function buildWhere(filter: PromotionListFilter): Prisma.PromotionWhereInput {
  const and: Prisma.PromotionWhereInput[] = [];
  const needle = filter.q?.trim();
  if (needle) {
    and.push({
      OR: [
        { code: { contains: needle, mode: 'insensitive' } },
        { name: { contains: needle, mode: 'insensitive' } },
        { description: { contains: needle, mode: 'insensitive' } },
      ],
    });
  }
  if (filter.status) {
    and.push({ status: filter.status });
  }
  if (filter.serviceType) {
    and.push({ serviceType: { in: [filter.serviceType, 'ALL'] } });
  }
  if (filter.audience) {
    and.push({ targetAudience: { in: [filter.audience, 'ALL'] } });
  }
  return and.length > 0 ? { AND: and } : {};
}

function mapPromotion(row: DbPromotion): PromotionCampaign {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    description: row.description,
    serviceType: row.serviceType,
    discountType: row.discountType,
    discountValue: row.discountValue,
    maxDiscountAmount: row.maxDiscountAmount ?? undefined,
    minOrderAmount: row.minOrderAmount,
    totalBudget: row.totalBudget,
    usedBudget: row.usedBudget,
    usageLimit: row.usageLimit,
    usedCount: row.usedCount,
    userLimit: row.userLimit,
    targetAudience: row.targetAudience,
    status: row.status,
    startDate: row.startDate.toISOString(),
    endDate: row.endDate.toISOString(),
    sponsor: row.sponsor,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}
