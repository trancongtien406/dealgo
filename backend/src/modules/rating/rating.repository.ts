import { randomUUID } from 'node:crypto';
import type { RatingSubjectType, RatingTag } from './rating.constants.js';

export type ServiceRating = {
  id: string;
  subjectType: RatingSubjectType;
  subjectId: string;
  raterId: string;
  driverId: string | null;
  storeId: string | null;
  driverStars: number | null;
  storeStars: number | null;
  tags: RatingTag[];
  comment: string | null;
  createdAt: Date;
};

export type NewServiceRating = Omit<ServiceRating, 'id' | 'createdAt'>;

export type DriverRatingSummary = {
  average: number | null;
  count: number;
  /** Count per star, index 0 = 1 star. */
  distribution: [number, number, number, number, number];
};

export type StoreRatingAggregate = { storeId: string; count: number; sum: number };

export type StoreReviewRow = {
  storeStars: number;
  tags: RatingTag[];
  comment: string | null;
  createdAt: Date;
};

export class RatingAlreadySubmittedError extends Error {
  constructor() {
    super('RATING_ALREADY_SUBMITTED');
    this.name = 'RatingAlreadySubmittedError';
  }
}

export interface RatingRepository {
  /** One rating per subject; throws RatingAlreadySubmittedError on a duplicate. */
  create(input: NewServiceRating): Promise<ServiceRating>;
  find(subjectType: RatingSubjectType, subjectId: string): Promise<ServiceRating | null>;
  driverSummary(driverId: string): Promise<DriverRatingSummary>;
  /** storeStars count and sum per store; stores without ratings are omitted. */
  storeAggregates(storeIds: string[]): Promise<StoreRatingAggregate[]>;
  /** Newest store ratings first (never exposes the rater). */
  recentStoreReviews(storeId: string, limit: number): Promise<StoreReviewRow[]>;
  /** driverStars per subject for a driver's history list. */
  driverStarsFor(
    driverId: string,
    subjects: { subjectType: RatingSubjectType; subjectId: string }[],
  ): Promise<Map<string, number>>;
}

export function ratingKey(subjectType: RatingSubjectType, subjectId: string): string {
  return `${subjectType}:${subjectId}`;
}

export function summarize(stars: number[]): DriverRatingSummary {
  const distribution: DriverRatingSummary['distribution'] = [0, 0, 0, 0, 0];
  for (const value of stars) {
    distribution[value - 1] += 1;
  }
  const count = stars.length;
  const average =
    count === 0 ? null : Math.round((stars.reduce((a, b) => a + b, 0) / count) * 100) / 100;
  return { average, count, distribution };
}

export class MemoryRatingRepository implements RatingRepository {
  private readonly rows = new Map<string, ServiceRating>();

  async create(input: NewServiceRating): Promise<ServiceRating> {
    const key = ratingKey(input.subjectType, input.subjectId);
    if (this.rows.has(key)) {
      throw new RatingAlreadySubmittedError();
    }
    const row = { ...input, tags: [...input.tags], id: randomUUID(), createdAt: new Date() };
    this.rows.set(key, row);
    return { ...row };
  }

  async find(subjectType: RatingSubjectType, subjectId: string): Promise<ServiceRating | null> {
    const row = this.rows.get(ratingKey(subjectType, subjectId));
    return row ? { ...row } : null;
  }

  async driverSummary(driverId: string): Promise<DriverRatingSummary> {
    return summarize(
      [...this.rows.values()]
        .filter((row) => row.driverId === driverId && row.driverStars !== null)
        .map((row) => row.driverStars as number),
    );
  }

  async storeAggregates(storeIds: string[]): Promise<StoreRatingAggregate[]> {
    const wanted = new Set(storeIds);
    const byStore = new Map<string, StoreRatingAggregate>();
    for (const row of this.rows.values()) {
      if (!row.storeId || row.storeStars === null || !wanted.has(row.storeId)) {
        continue;
      }
      const agg = byStore.get(row.storeId) ?? { storeId: row.storeId, count: 0, sum: 0 };
      agg.count += 1;
      agg.sum += row.storeStars;
      byStore.set(row.storeId, agg);
    }
    return [...byStore.values()];
  }

  async recentStoreReviews(storeId: string, limit: number): Promise<StoreReviewRow[]> {
    return [...this.rows.values()]
      .filter((row) => row.storeId === storeId && row.storeStars !== null)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit)
      .map((row) => ({
        storeStars: row.storeStars as number,
        tags: [...row.tags],
        comment: row.comment,
        createdAt: row.createdAt,
      }));
  }

  async driverStarsFor(
    driverId: string,
    subjects: { subjectType: RatingSubjectType; subjectId: string }[],
  ): Promise<Map<string, number>> {
    const out = new Map<string, number>();
    for (const subject of subjects) {
      const row = this.rows.get(ratingKey(subject.subjectType, subject.subjectId));
      if (row && row.driverId === driverId && row.driverStars !== null) {
        out.set(ratingKey(subject.subjectType, subject.subjectId), row.driverStars);
      }
    }
    return out;
  }
}
