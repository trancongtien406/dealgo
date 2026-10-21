import { HttpException, Inject, Injectable } from '@nestjs/common';
import { FoodService } from '../food-order/food.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { RideService } from '../ride/ride.service.js';
import { RATING_REPOSITORY, type RatingSubjectType } from './rating.constants.js';
import type { SubmitRatingDto } from './rating.dto.js';
import {
  RatingAlreadySubmittedError,
  type RatingRepository,
  type ServiceRating,
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
};

export type StoreReviews = {
  summary: StoreRatingSummary;
  /** Empty until the store reaches RATING_STORE_MIN_COUNT ratings. */
  items: { stars: number; tags: string[]; comment: string | null; createdAt: string }[];
};

const STORE_REVIEW_LIMIT = 20;

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
      return {
        storeId,
        count,
        average:
          row && count >= minCount ? Math.round((row.sum / count) * 10) / 10 : null,
      };
    });
  }

  async storeReviews(storeId: string): Promise<StoreReviews> {
    const [summary] = await this.storeSummaries([storeId]);
    if (summary.average === null) {
      return { summary, items: [] };
    }
    const rows = await this.ratings.recentStoreReviews(storeId, STORE_REVIEW_LIMIT);
    return {
      summary,
      items: rows.map((row) => ({
        stars: row.storeStars,
        tags: row.tags,
        comment: row.comment,
        createdAt: row.createdAt.toISOString(),
      })),
    };
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

function publish(rating: ServiceRating): PublicRating {
  const { raterId: _raterId, createdAt, ...rest } = rating;
  return { ...rest, createdAt: createdAt.toISOString() };
}
