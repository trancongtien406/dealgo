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
  /** The store's public answer (DEC-PROD-055). */
  merchantReply: string | null;
  repliedAt: Date | null;
  /** Ops-hidden reviews leave the public list and the store average. */
  hiddenAt: Date | null;
  hiddenReason: string | null;
  createdAt: Date;
};

export type NewServiceRating = Omit<
  ServiceRating,
  'id' | 'createdAt' | 'merchantReply' | 'repliedAt' | 'hiddenAt' | 'hiddenReason'
>;

export type DriverRatingSummary = {
  average: number | null;
  count: number;
  /** Count per star, index 0 = 1 star. */
  distribution: [number, number, number, number, number];
};

export type StarDistribution = [number, number, number, number, number];

export type StoreRatingAggregate = {
  storeId: string;
  count: number;
  sum: number;
  /** Count per star, index 0 = 1 star. */
  distribution: StarDistribution;
};

export type StoreReviewRow = {
  id: string;
  storeStars: number;
  tags: RatingTag[];
  comment: string | null;
  merchantReply: string | null;
  repliedAt: Date | null;
  createdAt: Date;
};

export type ModeratedReviewRow = StoreReviewRow & {
  storeId: string;
  subjectId: string;
  hiddenAt: Date | null;
  hiddenReason: string | null;
};

export type OpsReviewFilter = {
  storeId?: string;
  hidden?: boolean;
  /** Only reviews at or below this many stars (triage of complaints). */
  maxStars?: number;
  q?: string;
};

export type ReviewHideAudit = { actorUserId: string; reason: string };

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
  /** Visible storeStars count, sum and spread per store; stores without ratings are omitted. */
  storeAggregates(storeIds: string[]): Promise<StoreRatingAggregate[]>;
  /** Newest visible store ratings first (never exposes the rater). */
  recentStoreReviews(
    storeId: string,
    limit: number,
    offset?: number,
    stars?: number,
  ): Promise<StoreReviewRow[]>;
  /** Store reviews with moderation state, newest first (merchant and ops views). */
  listModerated(
    filter: OpsReviewFilter,
    page: number,
    limit: number,
  ): Promise<{ items: ModeratedReviewRow[]; total: number }>;
  /** Sets or clears the store's reply; null when the review is not this store's. */
  reply(
    storeId: string,
    ratingId: string,
    text: string | null,
    now: Date,
  ): Promise<ModeratedReviewRow | null>;
  /** Ops hide/unhide with an audit entry; null when the review does not exist. */
  setHidden(
    ratingId: string,
    hidden: boolean,
    audit: ReviewHideAudit,
    now: Date,
  ): Promise<ModeratedReviewRow | null>;
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

export function emptyDistribution(): StarDistribution {
  return [0, 0, 0, 0, 0];
}

function foldText(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .toLowerCase();
}

function toModerated(row: ServiceRating): ModeratedReviewRow {
  return {
    id: row.id,
    storeId: row.storeId as string,
    subjectId: row.subjectId,
    storeStars: row.storeStars as number,
    tags: [...row.tags],
    comment: row.comment,
    merchantReply: row.merchantReply,
    repliedAt: row.repliedAt,
    hiddenAt: row.hiddenAt,
    hiddenReason: row.hiddenReason,
    createdAt: row.createdAt,
  };
}

export class MemoryRatingRepository implements RatingRepository {
  private readonly rows = new Map<string, ServiceRating>();
  /** Audit entries (in-memory mode only). */
  readonly audits: Array<ReviewHideAudit & { entityId: string; hidden: boolean }> = [];

  async create(input: NewServiceRating): Promise<ServiceRating> {
    const key = ratingKey(input.subjectType, input.subjectId);
    if (this.rows.has(key)) {
      throw new RatingAlreadySubmittedError();
    }
    const row: ServiceRating = {
      ...input,
      tags: [...input.tags],
      id: randomUUID(),
      merchantReply: null,
      repliedAt: null,
      hiddenAt: null,
      hiddenReason: null,
      createdAt: new Date(),
    };
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
      if (!row.storeId || row.storeStars === null || row.hiddenAt || !wanted.has(row.storeId)) {
        continue;
      }
      const agg = byStore.get(row.storeId) ?? {
        storeId: row.storeId,
        count: 0,
        sum: 0,
        distribution: emptyDistribution(),
      };
      agg.count += 1;
      agg.sum += row.storeStars;
      agg.distribution[row.storeStars - 1] += 1;
      byStore.set(row.storeId, agg);
    }
    return [...byStore.values()];
  }

  async recentStoreReviews(
    storeId: string,
    limit: number,
    offset = 0,
    stars?: number,
  ): Promise<StoreReviewRow[]> {
    return [...this.rows.values()]
      .filter(
        (row) =>
          row.storeId === storeId &&
          row.storeStars !== null &&
          !row.hiddenAt &&
          (stars === undefined || row.storeStars === stars),
      )
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(offset, offset + limit)
      .map((row) => ({
        id: row.id,
        storeStars: row.storeStars as number,
        tags: [...row.tags],
        comment: row.comment,
        merchantReply: row.merchantReply,
        repliedAt: row.repliedAt,
        createdAt: row.createdAt,
      }));
  }

  async listModerated(
    filter: OpsReviewFilter,
    page: number,
    limit: number,
  ): Promise<{ items: ModeratedReviewRow[]; total: number }> {
    const needle = filter.q?.trim() ? foldText(filter.q.trim()) : null;
    const rows = [...this.rows.values()]
      .filter(
        (row) =>
          row.storeId !== null &&
          row.storeStars !== null &&
          (!filter.storeId || row.storeId === filter.storeId) &&
          (filter.hidden === undefined || Boolean(row.hiddenAt) === filter.hidden) &&
          (filter.maxStars === undefined || (row.storeStars as number) <= filter.maxStars) &&
          (!needle || foldText(row.comment ?? '').includes(needle)),
      )
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    const offset = (page - 1) * limit;
    return { items: rows.slice(offset, offset + limit).map(toModerated), total: rows.length };
  }

  async reply(
    storeId: string,
    ratingId: string,
    text: string | null,
    now: Date,
  ): Promise<ModeratedReviewRow | null> {
    const row = [...this.rows.values()].find((entry) => entry.id === ratingId);
    if (!row || row.storeId !== storeId || row.storeStars === null) {
      return null;
    }
    row.merchantReply = text;
    row.repliedAt = text ? now : null;
    return toModerated(row);
  }

  async setHidden(
    ratingId: string,
    hidden: boolean,
    audit: ReviewHideAudit,
    now: Date,
  ): Promise<ModeratedReviewRow | null> {
    const row = [...this.rows.values()].find((entry) => entry.id === ratingId);
    if (!row || row.storeId === null || row.storeStars === null) {
      return null;
    }
    row.hiddenAt = hidden ? now : null;
    row.hiddenReason = hidden ? audit.reason : null;
    this.audits.push({ ...audit, entityId: ratingId, hidden });
    return toModerated(row);
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
