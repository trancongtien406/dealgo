import { randomUUID } from 'node:crypto';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { RatingSubjectType, RatingTag } from './rating.constants.js';
import {
  RatingAlreadySubmittedError,
  emptyDistribution,
  ratingKey,
  summarize,
  type DriverRatingSummary,
  type ModeratedReviewRow,
  type OpsReviewFilter,
  type ReviewHideAudit,
  type NewServiceRating,
  type RatingRepository,
  type ServiceRating,
  type StoreRatingAggregate,
  type StoreReviewRow,
} from './rating.repository.js';

export class PrismaRatingRepository implements RatingRepository {
  constructor(private readonly db: PrismaClient) {}

  async create(input: NewServiceRating): Promise<ServiceRating> {
    try {
      const row = await this.db.serviceRating.create({ data: input });
      return toRating(row);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        throw new RatingAlreadySubmittedError();
      }
      throw error;
    }
  }

  async find(subjectType: RatingSubjectType, subjectId: string): Promise<ServiceRating | null> {
    const row = await this.db.serviceRating.findUnique({
      where: { subjectType_subjectId: { subjectType, subjectId } },
    });
    return row ? toRating(row) : null;
  }

  async driverSummary(driverId: string): Promise<DriverRatingSummary> {
    const groups = await this.db.serviceRating.groupBy({
      by: ['driverStars'],
      where: { driverId, driverStars: { not: null } },
      _count: { _all: true },
    });
    const stars: number[] = [];
    for (const group of groups) {
      for (let i = 0; i < group._count._all; i += 1) {
        stars.push(group.driverStars as number);
      }
    }
    return summarize(stars);
  }

  async storeAggregates(storeIds: string[]): Promise<StoreRatingAggregate[]> {
    if (storeIds.length === 0) {
      return [];
    }
    const groups = await this.db.serviceRating.groupBy({
      by: ['storeId', 'storeStars'],
      where: { storeId: { in: storeIds }, storeStars: { not: null }, hiddenAt: null },
      _count: { _all: true },
    });
    const byStore = new Map<string, StoreRatingAggregate>();
    for (const g of groups) {
      if (g.storeId === null || g.storeStars === null) {
        continue;
      }
      const agg = byStore.get(g.storeId) ?? {
        storeId: g.storeId,
        count: 0,
        sum: 0,
        distribution: emptyDistribution(),
      };
      agg.count += g._count._all;
      agg.sum += g.storeStars * g._count._all;
      agg.distribution[g.storeStars - 1] += g._count._all;
      byStore.set(g.storeId, agg);
    }
    return [...byStore.values()];
  }

  async recentStoreReviews(
    storeId: string,
    limit: number,
    offset = 0,
    stars?: number,
  ): Promise<StoreReviewRow[]> {
    const rows = await this.db.serviceRating.findMany({
      where: {
        storeId,
        hiddenAt: null,
        storeStars: stars === undefined ? { not: null } : stars,
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      skip: offset,
      take: limit,
      select: REVIEW_SELECT,
    });
    return rows.map((row) => {
      const { storeId: _s, subjectId: _j, hiddenAt: _h, hiddenReason: _r, ...rest } = toModerated(row);
      return rest;
    });
  }

  async listModerated(
    filter: OpsReviewFilter,
    page: number,
    limit: number,
  ): Promise<{ items: ModeratedReviewRow[]; total: number }> {
    const where: Prisma.ServiceRatingWhereInput = {
      storeId: filter.storeId ?? { not: null },
      storeStars: filter.maxStars === undefined ? { not: null } : { lte: filter.maxStars },
      ...(filter.hidden === undefined ? {} : { hiddenAt: filter.hidden ? { not: null } : null }),
      ...(filter.q?.trim()
        ? { comment: { contains: filter.q.trim(), mode: 'insensitive' as const } }
        : {}),
    };
    const [rows, total] = await Promise.all([
      this.db.serviceRating.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: REVIEW_SELECT,
      }),
      this.db.serviceRating.count({ where }),
    ]);
    return { items: rows.map(toModerated), total };
  }

  async reply(
    storeId: string,
    ratingId: string,
    text: string | null,
    now: Date,
  ): Promise<ModeratedReviewRow | null> {
    const updated = await this.db.serviceRating.updateMany({
      where: { id: ratingId, storeId, storeStars: { not: null } },
      data: { merchantReply: text, repliedAt: text ? now : null },
    });
    if (updated.count === 0) {
      return null;
    }
    return this.findModerated(ratingId);
  }

  async setHidden(
    ratingId: string,
    hidden: boolean,
    audit: ReviewHideAudit,
    now: Date,
  ): Promise<ModeratedReviewRow | null> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.serviceRating.findUnique({
        where: { id: ratingId },
        select: { storeId: true, storeStars: true },
      });
      if (!current || current.storeId === null || current.storeStars === null) {
        return null;
      }
      const row = await tx.serviceRating.update({
        where: { id: ratingId },
        data: { hiddenAt: hidden ? now : null, hiddenReason: hidden ? audit.reason : null },
        select: REVIEW_SELECT,
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: audit.actorUserId,
          action: hidden ? 'REVIEW_HIDE' : 'REVIEW_UNHIDE',
          entityType: 'SERVICE_RATING',
          entityId: ratingId,
          reason: audit.reason,
          metadata: { storeId: current.storeId, stars: current.storeStars },
        },
      });
      return toModerated(row);
    });
  }

  private async findModerated(ratingId: string): Promise<ModeratedReviewRow | null> {
    const row = await this.db.serviceRating.findUnique({
      where: { id: ratingId },
      select: REVIEW_SELECT,
    });
    return row ? toModerated(row) : null;
  }

  async driverStarsFor(
    driverId: string,
    subjects: { subjectType: RatingSubjectType; subjectId: string }[],
  ): Promise<Map<string, number>> {
    if (subjects.length === 0) {
      return new Map();
    }
    const rows = await this.db.serviceRating.findMany({
      where: {
        driverId,
        driverStars: { not: null },
        OR: subjects.map((s) => ({ subjectType: s.subjectType, subjectId: s.subjectId })),
      },
      select: { subjectType: true, subjectId: true, driverStars: true },
    });
    return new Map(
      rows.map((row) => [ratingKey(row.subjectType, row.subjectId), row.driverStars as number]),
    );
  }
}

const REVIEW_SELECT = {
  id: true,
  storeId: true,
  subjectId: true,
  storeStars: true,
  tags: true,
  comment: true,
  merchantReply: true,
  repliedAt: true,
  hiddenAt: true,
  hiddenReason: true,
  createdAt: true,
} as const;

function toModerated(row: {
  id: string;
  storeId: string | null;
  subjectId: string;
  storeStars: number | null;
  tags: string[];
  comment: string | null;
  merchantReply: string | null;
  repliedAt: Date | null;
  hiddenAt: Date | null;
  hiddenReason: string | null;
  createdAt: Date;
}): ModeratedReviewRow {
  return {
    ...row,
    storeId: row.storeId as string,
    storeStars: row.storeStars as number,
    tags: row.tags as RatingTag[],
  };
}

function toRating(row: {
  id: string;
  subjectType: RatingSubjectType;
  subjectId: string;
  raterId: string;
  driverId: string | null;
  storeId: string | null;
  driverStars: number | null;
  storeStars: number | null;
  tags: string[];
  comment: string | null;
  merchantReply: string | null;
  repliedAt: Date | null;
  hiddenAt: Date | null;
  hiddenReason: string | null;
  createdAt: Date;
}): ServiceRating {
  return { ...row, tags: row.tags as RatingTag[] };
}
