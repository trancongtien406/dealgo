import { HttpException, Inject, Injectable } from '@nestjs/common';
import { FoodService } from '../food-order/food.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { RideService } from '../ride/ride.service.js';
import { RATING_REPOSITORY, type RatingSubjectType } from './rating.constants.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import type { MerchantReviewsQueryDto, OpsReviewsQueryDto, SubmitRatingDto } from './rating.dto.js';
import {
  RatingAlreadySubmittedError,
  type ModeratedReviewRow,
  type RatingRepository,
  type ServiceRating,
  type StarDistribution,
  type StoreReviewRow,
} from './rating.repository.js';

export type PublicRating = Omit<ServiceRating, 'raterId' | 'createdAt'> & { createdAt: string };

type Subject = {
  customerId: string;
  driverId: string | null;
  storeId: string | null;
  status: string;
  finishedAt: Date;
};

export type StoreRatingSummary = {
  storeId: string;
  /** Null until the store has RATING_STORE_MIN_COUNT ratings, so one rater's stars stay private. */
  average: number | null;
  count: number;
  /** Count per star (index 0 = 1 star); null while the average is hidden. */
  distribution: StarDistribution | null;
};

export type PublicStoreReview = {
  id: string;
  stars: number;
  tags: string[];
  comment: string | null;
  merchantReply: string | null;
  repliedAt: string | null;
  createdAt: string;
};

export type StoreReviews = {
  summary: StoreRatingSummary;
  /** Empty until the store reaches RATING_STORE_MIN_COUNT ratings. */
  items: PublicStoreReview[];
  page: number;
  hasMore: boolean;
};

export type ModeratedReview = PublicStoreReview & {
  storeId: string;
  storeName: string | null;
  hidden: boolean;
  hiddenAt: string | null;
  hiddenReason: string | null;
};

const STORE_REVIEW_LIMIT = 20;
const MERCHANT_REVIEW_LIMIT = 20;

const DAY_MS = 86_400_000;

const RATEABLE_STATUS: Record<RatingSubjectType, string> = {
  RIDE: 'COMPLETED',
  FOOD_ORDER: 'DELIVERED',
};

function fail(status: number, errorCode: string, message: string): never {
  throw new HttpException({ message, errorCode }, status);
}

@Injectable()
export class RatingService {
  constructor(
    @Inject(RATING_REPOSITORY) private readonly ratings: RatingRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly settings: PlatformSettingsService,
  ) {}

  /** Public store rating summaries for browse cards; unknown ids come back with count 0. */
  async storeSummaries(storeIds: string[]): Promise<StoreRatingSummary[]> {
    const unique = [...new Set(storeIds)];
    const [rows, minCount] = await Promise.all([
      this.ratings.storeAggregates(unique),
      this.settings.getNumber('RATING_STORE_MIN_COUNT'),
    ]);
    const byStore = new Map(rows.map((row) => [row.storeId, row]));
    return unique.map((storeId) => {
      const row = byStore.get(storeId);
      const count = row?.count ?? 0;
      const shown = row && count >= minCount;
      return {
        storeId,
        count,
        average: shown ? Math.round((row.sum / count) * 10) / 10 : null,
        distribution: shown ? row.distribution : null,
      };
    });
  }

  async storeReviews(
    storeId: string,
    query: { page?: number; stars?: number } = {},
  ): Promise<StoreReviews> {
    const page = Math.max(1, query.page ?? 1);
    const [summary] = await this.storeSummaries([storeId]);
    if (summary.average === null) {
      return { summary, items: [], page, hasMore: false };
    }
    const rows = await this.ratings.recentStoreReviews(
      storeId,
      STORE_REVIEW_LIMIT + 1,
      (page - 1) * STORE_REVIEW_LIMIT,
      query.stars,
    );
    return {
      summary,
      items: rows.slice(0, STORE_REVIEW_LIMIT).map(publicReview),
      page,
      hasMore: rows.length > STORE_REVIEW_LIMIT,
    };
  }

  /** The merchant sees every review of its store, including hidden ones and below the min count. */
  async merchantReviews(
    actor: RequestActor,
    queryOrPage: MerchantReviewsQueryDto | number = {},
  ): Promise<{ summary: StoreRatingSummary; items: ModeratedReview[]; total: number; page: number }> {
    const query: MerchantReviewsQueryDto =
      typeof queryOrPage === 'number' ? { page: queryOrPage } : queryOrPage;
    const page = Math.max(1, query.page ?? 1);
    const from =
      query.from && !Number.isNaN(Date.parse(query.from)) ? new Date(query.from) : undefined;
    const to = query.to && !Number.isNaN(Date.parse(query.to)) ? new Date(query.to) : undefined;
    const storeId = await this.food.merchantStoreId(actor);
    const [[summary], result] = await Promise.all([
      this.storeSummaries([storeId]),
      this.ratings.listModerated(
        {
          storeId,
          stars: query.stars,
          replied: query.replied === undefined ? undefined : query.replied === 'REPLIED',
          hasComment: query.hasComment,
          hidden: query.visibility === undefined ? undefined : query.visibility === 'HIDDEN',
          tag: query.tag,
          q: query.q,
          from,
          to,
          sort: query.sort,
        },
        page,
        MERCHANT_REVIEW_LIMIT,
      ),
    ]);
    return {
      summary,
      items: result.items.map((row) => moderatedReview(row, null)),
      total: result.total,
      page,
    };
  }

  async replyAsMerchant(
    actor: RequestActor,
    ratingId: string,
    text: string | undefined,
  ): Promise<ModeratedReview> {
    const storeId = await this.food.merchantStoreId(actor);
    const trimmed = text?.trim() ? text.trim() : null;
    const row = await this.ratings.reply(storeId, ratingId, trimmed, new Date());
    if (!row) {
      fail(404, 'RATING_NOT_FOUND', 'Review not found');
    }
    return moderatedReview(row, null);
  }

  async opsReviews(
    query: OpsReviewsQueryDto,
  ): Promise<{ items: ModeratedReview[]; total: number; page: number; limit: number }> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(50, Math.max(1, query.limit ?? 20));
    const result = await this.ratings.listModerated(
      {
        storeId: query.storeId,
        hidden: query.visibility === undefined ? undefined : query.visibility === 'HIDDEN',
        maxStars: query.maxStars,
        q: query.q,
      },
      page,
      limit,
    );
    const names = await this.food.storeNames(result.items.map((row) => row.storeId));
    return {
      items: result.items.map((row) => moderatedReview(row, names.get(row.storeId) ?? null)),
      total: result.total,
      page,
      limit,
    };
  }

  async setHidden(
    actorUserId: string,
    ratingId: string,
    hidden: boolean,
    reason: string,
  ): Promise<ModeratedReview> {
    const row = await this.ratings.setHidden(
      ratingId,
      hidden,
      { actorUserId, reason: reason.trim() },
      new Date(),
    );
    if (!row) {
      fail(404, 'RATING_NOT_FOUND', 'Review not found');
    }
    const names = await this.food.storeNames([row.storeId]);
    return moderatedReview(row, names.get(row.storeId) ?? null);
  }

  async submit(userId: string, dto: SubmitRatingDto): Promise<PublicRating> {
    const subject = await this.ownedSubject(userId, dto.subjectType, dto.subjectId);
    if (subject.status !== RATEABLE_STATUS[dto.subjectType]) {
      fail(422, 'RATING_NOT_ALLOWED', 'Only finished rides and delivered orders can be rated');
    }
    const rateableUntil = await this.rateableUntil(subject);
    if (Date.now() > rateableUntil.getTime()) {
      fail(422, 'RATING_WINDOW_EXPIRED', 'The rating window for this ride/order has closed');
    }
    if (subject.driverId && dto.driverStars === undefined) {
      fail(400, 'RATING_DRIVER_STARS_REQUIRED', 'driverStars is required');
    }
    if (dto.subjectType === 'FOOD_ORDER' && dto.storeStars === undefined) {
      fail(400, 'RATING_STORE_STARS_REQUIRED', 'storeStars is required for food orders');
    }
    if (dto.subjectType === 'RIDE' && dto.storeStars !== undefined) {
      fail(400, 'RATING_STORE_STARS_NOT_ALLOWED', 'Rides have no store to rate');
    }
    try {
      const created = await this.ratings.create({
        subjectType: dto.subjectType,
        subjectId: dto.subjectId,
        raterId: userId,
        driverId: subject.driverId,
        storeId: subject.storeId,
        driverStars: subject.driverId ? (dto.driverStars ?? null) : null,
        storeStars: dto.storeStars ?? null,
        tags: [...new Set(dto.tags ?? [])],
        comment: dto.comment ? dto.comment : null,
      });
      return publish(created);
    } catch (error) {
      if (error instanceof RatingAlreadySubmittedError) {
        fail(409, 'RATING_ALREADY_SUBMITTED', 'This ride or order was already rated');
      }
      throw error;
    }
  }

  async get(
    userId: string,
    subjectType: RatingSubjectType,
    subjectId: string,
  ): Promise<{ rating: PublicRating | null; canRate: boolean; rateableUntil: string | null }> {
    const subject = await this.ownedSubject(userId, subjectType, subjectId);
    const rating = await this.ratings.find(subjectType, subjectId);
    const finished = subject.status === RATEABLE_STATUS[subjectType];
    const until = finished ? await this.rateableUntil(subject) : null;
    return {
      rating: rating ? publish(rating) : null,
      canRate: !rating && until !== null && Date.now() <= until.getTime(),
      rateableUntil: until ? until.toISOString() : null,
    };
  }

  /** Confirmed (DEC-PROD-013): ratings close RATING_WINDOW_DAYS after completion (admin setting). */
  private async rateableUntil(subject: Subject): Promise<Date> {
    const days = await this.settings.getNumber('RATING_WINDOW_DAYS');
    return new Date(subject.finishedAt.getTime() + days * DAY_MS);
  }

  /** Only the customer of the ride/order may rate it; everyone else gets 404. */
  private async ownedSubject(
    userId: string,
    subjectType: RatingSubjectType,
    subjectId: string,
  ): Promise<Subject> {
    const subject =
      subjectType === 'RIDE'
        ? await this.rides.ratingSubject(subjectId)
        : await this.food.ratingSubject(subjectId);
    if (!subject || subject.customerId !== userId) {
      fail(404, 'RATING_SUBJECT_NOT_FOUND', 'Ride or order not found');
    }
    return subject;
  }
}

function publicReview(row: StoreReviewRow): PublicStoreReview {
  return {
    id: row.id,
    stars: row.storeStars,
    tags: row.tags,
    comment: row.comment,
    merchantReply: row.merchantReply,
    repliedAt: row.repliedAt ? row.repliedAt.toISOString() : null,
    createdAt: row.createdAt.toISOString(),
  };
}

function moderatedReview(row: ModeratedReviewRow, storeName: string | null): ModeratedReview {
  return {
    ...publicReview(row),
    storeId: row.storeId,
    storeName,
    hidden: row.hiddenAt !== null,
    hiddenAt: row.hiddenAt ? row.hiddenAt.toISOString() : null,
    hiddenReason: row.hiddenReason,
  };
}

function publish(rating: ServiceRating): PublicRating {
  const { raterId: _raterId, createdAt, ...rest } = rating;
  return { ...rest, createdAt: createdAt.toISOString() };
}
