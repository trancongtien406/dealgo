import { BadRequestException, Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { OPS_KPI_TODAY_TIMEZONE } from './ops-overview.constants.js';
import { hoChiMinhDayRange, type HoChiMinhDayRange } from './ops-overview.day.js';

type QueryClient = PrismaClient | Prisma.TransactionClient;

/** One Vietnam business day of completed / cancelled work and the money it produced. */
export type OpsReportDay = {
  day: string;
  ridesCompleted: number;
  ridesCancelled: number;
  foodDelivered: number;
  foodCancelled: number;
  /** Gross booking value: agreed ride fares + food subtotal and delivery fare (before vouchers). */
  revenueVnd: number;
  /** Platform take: driver commission (job_earnings.feeVnd) + merchant commission. */
  commissionVnd: number;
};

export type OpsReportTotals = Omit<OpsReportDay, 'day'> & {
  rideRevenueVnd: number;
  foodRevenueVnd: number;
};

export type OpsReport = {
  from: string;
  to: string;
  timezone: typeof OPS_KPI_TODAY_TIMEZONE;
  generatedAt: string;
  totals: OpsReportTotals;
  daily: OpsReportDay[];
};

type RideDayRow = { day: string; completed: bigint; cancelled: bigint; grossVnd: bigint; commissionVnd: bigint };
type FoodDayRow = RideDayRow;

const EMPTY_TOTALS: OpsReportTotals = {
  ridesCompleted: 0,
  ridesCancelled: 0,
  foodDelivered: 0,
  foodCancelled: 0,
  revenueVnd: 0,
  commissionVnd: 0,
  rideRevenueVnd: 0,
  foodRevenueVnd: 0,
};

/**
 * Period figures per Vietnam business day. A job counts on the day its terminal status was
 * written (`updatedAt`), the same rule the overview "today" KPIs use.
 */
export async function loadPeriodDays(
  db: QueryClient,
  range: Pick<HoChiMinhDayRange, 'start' | 'end' | 'days'>,
): Promise<{ daily: OpsReportDay[]; totals: OpsReportTotals }> {
  const [rides, food] = await Promise.all([
    db.$queryRaw<RideDayRow[]>`
      SELECT
        to_char((r."updatedAt" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS day,
        COUNT(*) FILTER (WHERE r.status = 'COMPLETED'::"RideStatus")::bigint AS completed,
        COUNT(*) FILTER (WHERE r.status = 'CANCELLED'::"RideStatus")::bigint AS cancelled,
        COALESCE(SUM(r."agreedFareVnd") FILTER (WHERE r.status = 'COMPLETED'::"RideStatus"), 0)::bigint AS "grossVnd",
        COALESCE(SUM(e."feeVnd") FILTER (WHERE r.status = 'COMPLETED'::"RideStatus"), 0)::bigint AS "commissionVnd"
      FROM rides r
      LEFT JOIN job_earnings e
        ON e."entityType" = 'RIDE'::"LedgerEntityType" AND e."entityId" = r.id
      WHERE r.status IN ('COMPLETED'::"RideStatus", 'CANCELLED'::"RideStatus")
        AND r."updatedAt" >= ${range.start}
        AND r."updatedAt" < ${range.end}
      GROUP BY 1
    `,
    db.$queryRaw<FoodDayRow[]>`
      SELECT
        to_char((f."updatedAt" AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Ho_Chi_Minh', 'YYYY-MM-DD') AS day,
        COUNT(*) FILTER (WHERE f.status = 'DELIVERED'::"FoodOrderStatus")::bigint AS completed,
        COUNT(*) FILTER (WHERE f.status <> 'DELIVERED'::"FoodOrderStatus")::bigint AS cancelled,
        COALESCE(SUM(f."subtotalVnd" + f."deliveryFareVnd") FILTER (WHERE f.status = 'DELIVERED'::"FoodOrderStatus"), 0)::bigint AS "grossVnd",
        COALESCE(SUM(COALESCE(e."feeVnd", 0) + COALESCE(f."merchantCommissionVnd", 0)) FILTER (WHERE f.status = 'DELIVERED'::"FoodOrderStatus"), 0)::bigint AS "commissionVnd"
      FROM food_orders f
      LEFT JOIN job_earnings e
        ON e."entityType" = 'FOOD_ORDER'::"LedgerEntityType" AND e."entityId" = f.id
      WHERE f.status IN ('DELIVERED'::"FoodOrderStatus", 'CANCELLED'::"FoodOrderStatus", 'FAILED'::"FoodOrderStatus")
        AND f."updatedAt" >= ${range.start}
        AND f."updatedAt" < ${range.end}
      GROUP BY 1
    `,
  ]);
  return foldPeriodRows(range.days, rides, food);
}

export function foldPeriodRows(
  days: string[],
  rides: RideDayRow[],
  food: FoodDayRow[],
): { daily: OpsReportDay[]; totals: OpsReportTotals } {
  const byDay = new Map<string, OpsReportDay>(
    days.map((day) => [
      day,
      { day, ridesCompleted: 0, ridesCancelled: 0, foodDelivered: 0, foodCancelled: 0, revenueVnd: 0, commissionVnd: 0 },
    ]),
  );
  const totals: OpsReportTotals = { ...EMPTY_TOTALS };
  for (const row of rides) {
    const bucket = byDay.get(row.day);
    if (!bucket) continue;
    const gross = Number(row.grossVnd);
    bucket.ridesCompleted += Number(row.completed);
    bucket.ridesCancelled += Number(row.cancelled);
    bucket.revenueVnd += gross;
    bucket.commissionVnd += Number(row.commissionVnd);
    totals.rideRevenueVnd += gross;
  }
  for (const row of food) {
    const bucket = byDay.get(row.day);
    if (!bucket) continue;
    const gross = Number(row.grossVnd);
    bucket.foodDelivered += Number(row.completed);
    bucket.foodCancelled += Number(row.cancelled);
    bucket.revenueVnd += gross;
    bucket.commissionVnd += Number(row.commissionVnd);
    totals.foodRevenueVnd += gross;
  }
  const daily = [...byDay.values()];
  for (const day of daily) {
    totals.ridesCompleted += day.ridesCompleted;
    totals.ridesCancelled += day.ridesCancelled;
    totals.foodDelivered += day.foodDelivered;
    totals.foodCancelled += day.foodCancelled;
    totals.revenueVnd += day.revenueVnd;
    totals.commissionVnd += day.commissionVnd;
  }
  return { daily, totals };
}

@Injectable()
export class OpsReportsService {
  private readonly logger = new Logger(OpsReportsService.name);

  constructor(private readonly prisma: PrismaService) {}

  async report(input: { from?: string; to?: string }, now = new Date()): Promise<OpsReport> {
    const range = hoChiMinhDayRange(input, now);
    if (!range) {
      throw new BadRequestException({
        message: 'from/to must be YYYY-MM-DD, from ≤ to, at most 92 days',
        errorCode: 'REPORT_RANGE_INVALID',
      });
    }
    const base = {
      from: range.from,
      to: range.to,
      timezone: OPS_KPI_TODAY_TIMEZONE,
      generatedAt: now.toISOString(),
    };
    const db = this.prisma.db();
    if (!db) {
      return { ...base, ...foldPeriodRows(range.days, [], []) };
    }
    try {
      return { ...base, ...(await loadPeriodDays(db, range)) };
    } catch (error) {
      this.logger.error(`reports query failed: ${String(error)}`);
      throw new InternalServerErrorException('Ops report query failed');
    }
  }
}
