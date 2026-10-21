import { HttpException, HttpStatus, Inject, Injectable } from '@nestjs/common';
import { EarningsService } from '../earnings/earnings.service.js';
import { earningKey } from '../earnings/earnings.repository.js';
import { FoodService } from '../food-order/food.service.js';
import type { FoodOrderView } from '../food-order/food.repository.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { RATING_REPOSITORY } from '../rating/rating.constants.js';
import {
  ratingKey,
  type DriverRatingSummary,
  type RatingRepository,
} from '../rating/rating.repository.js';
import type { RideSnapshot } from '../ride/ride-ledger.js';
import { RideService } from '../ride/ride.service.js';
import type { DriverHistoryKind, DriverHistoryQueryDto } from './driver-history.dto.js';

const DEFAULT_LIMIT = 20;
/**
 * Extra rows fetched per source so items sharing the cursor timestamp are not lost.
 * More than this many jobs finishing in the same millisecond is not realistic.
 */
const TIE_PADDING = 25;
/** Upper bound for the 7-day summary scan per source. */
const SUMMARY_SCAN_LIMIT = 2000;
const DAY_MS = 86_400_000;
/** Business days are Asia/Ho_Chi_Minh calendar days (UTC+7, no DST). */
const VN_OFFSET_MS = 7 * 3_600_000;
const SUMMARY_DAYS = 7;

export type DriverJobOutcome = 'COMPLETED' | 'CANCELLED' | 'FAILED';

export type DriverHistoryItem = {
  kind: 'RIDE' | 'FOOD_ORDER';
  id: string;
  status: string;
  outcome: DriverJobOutcome;
  /** Gross fare of the job (ride fare / delivery fee). */
  fareVnd: number;
  /** Platform fee rate snapshotted at completion (percent), null when not completed. */
  feePercent: number | null;
  /** Platform fee withheld (0 when not completed or no fee applied). */
  feeVnd: number;
  /** Net earnings: fareVnd - feeVnd for completed jobs, 0 otherwise. */
  earningsVnd: number;
  pickupLabel: string | null;
  dropoffLabel: string;
  storeName: string | null;
  finishedAt: string;
  /** Customer's stars for the driver, when rated. */
  driverStars: number | null;
};

export type DriverHistoryPage = {
  items: DriverHistoryItem[];
  nextCursor: string | null;
};

export type DriverDaySummary = {
  /** YYYY-MM-DD in Asia/Ho_Chi_Minh. */
  date: string;
  completedJobs: number;
  grossVnd: number;
  feeVnd: number;
  /** Net = gross - fee. */
  earningsVnd: number;
};

export type DriverHistorySummary = {
  today: DriverDaySummary;
  days: DriverDaySummary[];
  week: {
    completedJobs: number;
    cancelledJobs: number;
    grossVnd: number;
    feeVnd: number;
    earningsVnd: number;
    rideEarningsVnd: number;
    foodEarningsVnd: number;
  };
  rating: DriverRatingSummary;
};

type Cursor = { t: number; k: string };

function fail(status: number, errorCode: string, message: string): never {
  throw new HttpException({ message, errorCode }, status);
}

function itemKey(item: Pick<DriverHistoryItem, 'kind' | 'id'>): string {
  return `${item.kind}:${item.id}`;
}

/** Newest first, ties broken by key descending (stable across pages). */
function compareDesc(left: DriverHistoryItem, right: DriverHistoryItem): number {
  const byTime = Date.parse(right.finishedAt) - Date.parse(left.finishedAt);
  if (byTime !== 0) {
    return byTime;
  }
  const leftKey = itemKey(left);
  const rightKey = itemKey(right);
  return leftKey < rightKey ? 1 : leftKey > rightKey ? -1 : 0;
}

function encodeCursor(item: DriverHistoryItem): string {
  const cursor: Cursor = { t: Date.parse(item.finishedAt), k: itemKey(item) };
  return Buffer.from(JSON.stringify(cursor)).toString('base64url');
}

function decodeCursor(raw: string): Cursor {
  try {
    const parsed = JSON.parse(Buffer.from(raw, 'base64url').toString('utf8')) as Partial<Cursor>;
    if (typeof parsed.t === 'number' && Number.isFinite(parsed.t) && typeof parsed.k === 'string') {
      return { t: parsed.t, k: parsed.k };
    }
  } catch {
    // fall through
  }
  return fail(HttpStatus.BAD_REQUEST, 'DRIVER_HISTORY_CURSOR_INVALID', 'cursor is invalid');
}

function isAfterCursor(item: DriverHistoryItem, cursor: Cursor): boolean {
  const time = Date.parse(item.finishedAt);
  return time < cursor.t || (time === cursor.t && itemKey(item) < cursor.k);
}

export function vnDate(at: Date): string {
  return new Date(at.getTime() + VN_OFFSET_MS).toISOString().slice(0, 10);
}

/** UTC instant of 00:00 Asia/Ho_Chi_Minh on the day of [at]. */
export function vnStartOfDay(at: Date): Date {
  const shifted = at.getTime() + VN_OFFSET_MS;
  return new Date(shifted - (shifted % DAY_MS) - VN_OFFSET_MS);
}

function fromRide(ride: RideSnapshot): DriverHistoryItem {
  const outcome: DriverJobOutcome = ride.status === 'COMPLETED' ? 'COMPLETED' : 'CANCELLED';
  const fareVnd = ride.agreedFareVnd ?? 0;
  return {
    kind: 'RIDE',
    id: ride.id,
    status: ride.status,
    outcome,
    fareVnd,
    feePercent: null,
    feeVnd: 0,
    earningsVnd: outcome === 'COMPLETED' ? fareVnd : 0,
    pickupLabel: ride.pickup.label,
    dropoffLabel: ride.dropoff.label,
    storeName: null,
    finishedAt: ride.updatedAt.toISOString(),
    driverStars: null,
  };
}

function fromFood(order: FoodOrderView): DriverHistoryItem {
  const outcome: DriverJobOutcome =
    order.status === 'DELIVERED' ? 'COMPLETED' : order.status === 'FAILED' ? 'FAILED' : 'CANCELLED';
  return {
    kind: 'FOOD_ORDER',
    id: order.id,
    status: order.status,
    outcome,
    fareVnd: order.deliveryFareVnd,
    feePercent: null,
    feeVnd: 0,
    earningsVnd: outcome === 'COMPLETED' ? order.deliveryFareVnd : 0,
    pickupLabel: order.storeName,
    dropoffLabel: order.dropoff.label,
    storeName: order.storeName,
    finishedAt: order.updatedAt.toISOString(),
    driverStars: null,
  };
}

@Injectable()
export class DriverHistoryService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(RATING_REPOSITORY) private readonly ratings: RatingRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly earnings: EarningsService,
  ) {}

  async list(driverId: string, query: DriverHistoryQueryDto = {}): Promise<DriverHistoryPage> {
    await this.requireDriver(driverId);
    const limit = query.limit ?? DEFAULT_LIMIT;
    const cursor = query.cursor ? decodeCursor(query.cursor) : null;
    const window = {
      before: cursor ? new Date(cursor.t) : undefined,
      limit: limit + 1 + TIE_PADDING,
    };
    const merged = (await this.collect(driverId, query.kind ?? 'ALL', window))
      .filter((item) => !cursor || isAfterCursor(item, cursor))
      .sort(compareDesc);
    const page = merged.slice(0, limit);
    await this.attachStars(driverId, page);
    const last = page.at(-1);
    return {
      items: page,
      nextCursor: merged.length > limit && last ? encodeCursor(last) : null,
    };
  }

  async summary(driverId: string, now: Date = new Date()): Promise<DriverHistorySummary> {
    await this.requireDriver(driverId);
    const todayStart = vnStartOfDay(now);
    const since = new Date(todayStart.getTime() - (SUMMARY_DAYS - 1) * DAY_MS);
    const [items, rating] = await Promise.all([
      this.collect(driverId, 'ALL', { since, limit: SUMMARY_SCAN_LIMIT }),
      this.ratings.driverSummary(driverId),
    ]);
    const days: DriverDaySummary[] = Array.from({ length: SUMMARY_DAYS }, (_, index) => ({
      date: vnDate(new Date(since.getTime() + index * DAY_MS)),
      completedJobs: 0,
      grossVnd: 0,
      feeVnd: 0,
      earningsVnd: 0,
    }));
    const byDate = new Map(days.map((day) => [day.date, day]));
    const week = {
      completedJobs: 0,
      cancelledJobs: 0,
      grossVnd: 0,
      feeVnd: 0,
      earningsVnd: 0,
      rideEarningsVnd: 0,
      foodEarningsVnd: 0,
    };
    for (const item of items) {
      if (item.outcome !== 'COMPLETED') {
        week.cancelledJobs += 1;
        continue;
      }
      const day = byDate.get(vnDate(new Date(item.finishedAt)));
      if (day) {
        day.completedJobs += 1;
        day.grossVnd += item.fareVnd;
        day.feeVnd += item.feeVnd;
        day.earningsVnd += item.earningsVnd;
      }
      week.completedJobs += 1;
      week.grossVnd += item.fareVnd;
      week.feeVnd += item.feeVnd;
      week.earningsVnd += item.earningsVnd;
      if (item.kind === 'RIDE') {
        week.rideEarningsVnd += item.earningsVnd;
      } else {
        week.foodEarningsVnd += item.earningsVnd;
      }
    }
    const today = days.at(-1) ?? {
      date: vnDate(now),
      completedJobs: 0,
      grossVnd: 0,
      feeVnd: 0,
      earningsVnd: 0,
    };
    return { today, days, week, rating };
  }

  private async collect(
    driverId: string,
    kind: DriverHistoryKind,
    window: { before?: Date; since?: Date; limit: number },
  ): Promise<DriverHistoryItem[]> {
    const [rides, orders] = await Promise.all([
      kind === 'FOOD_ORDER' ? [] : this.rides.listFinishedForDriver(driverId, window),
      kind === 'RIDE' ? [] : this.food.listFinishedForDriver(driverId, window),
    ]);
    const items = [...rides.map(fromRide), ...orders.map(fromFood)];
    await this.attachEarnings(items);
    return items;
  }

  /** Completed jobs use the fee snapshot taken at completion (none = no fee at that time). */
  private async attachEarnings(items: DriverHistoryItem[]): Promise<void> {
    const completed = items.filter((item) => item.outcome === 'COMPLETED');
    if (completed.length === 0) {
      return;
    }
    const snapshots = await this.earnings.findMany(
      completed.map((item) => ({ entityType: item.kind, entityId: item.id })),
    );
    for (const item of completed) {
      const snapshot = snapshots.get(earningKey(item.kind, item.id));
      item.feePercent = snapshot ? snapshot.feeBps / 100 : 0;
      item.feeVnd = snapshot?.feeVnd ?? 0;
      item.earningsVnd = item.fareVnd - item.feeVnd;
    }
  }

  private async attachStars(driverId: string, items: DriverHistoryItem[]): Promise<void> {
    if (items.length === 0) {
      return;
    }
    const stars = await this.ratings.driverStarsFor(
      driverId,
      items.map((item) => ({ subjectType: item.kind, subjectId: item.id })),
    );
    for (const item of items) {
      item.driverStars = stars.get(ratingKey(item.kind, item.id)) ?? null;
    }
  }

  private async requireDriver(userId: string): Promise<void> {
    const grants = await this.identity.listGrants(userId);
    if (!grants.some((grant) => grant.role === 'DRIVER' && grant.status === 'ACTIVE')) {
      fail(HttpStatus.FORBIDDEN, 'ROLE_NOT_ACTIVE', 'An active driver role is required');
    }
  }
}
