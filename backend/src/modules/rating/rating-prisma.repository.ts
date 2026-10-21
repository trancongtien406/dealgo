import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import type { RatingSubjectType, RatingTag } from './rating.constants.js';
import {
  RatingAlreadySubmittedError,
  ratingKey,
  summarize,
  type DriverRatingSummary,
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
      by: ['storeId'],
      where: { storeId: { in: storeIds }, storeStars: { not: null } },
      _count: { _all: true },
      _sum: { storeStars: true },
    });
    return groups
      .filter((g) => g.storeId !== null)
      .map((g) => ({
        storeId: g.storeId as string,
        count: g._count._all,
        sum: g._sum.storeStars ?? 0,
      }));
  }

  async recentStoreReviews(storeId: string, limit: number): Promise<StoreReviewRow[]> {
    const rows = await this.db.serviceRating.findMany({
      where: { storeId, storeStars: { not: null } },
      orderBy: { createdAt: 'desc' },
      take: limit,
      select: { storeStars: true, tags: true, comment: true, createdAt: true },
    });
    return rows.map((row) => ({
      storeStars: row.storeStars as number,
      tags: row.tags as RatingTag[],
      comment: row.comment,
      createdAt: row.createdAt,
    }));
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
  createdAt: Date;
}): ServiceRating {
  return { ...row, tags: row.tags as RatingTag[] };
}
