import {
  Injectable,
  InternalServerErrorException,
  Logger,
  type OnModuleInit,
} from '@nestjs/common';
import {
  activeServiceRegionsLabel,
  getServiceRegion,
} from '../service-area/service-regions.js';
import { Prisma } from '../../generated/prisma/client.js';
import type { PrismaClient } from '../../generated/prisma/client.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import {
  FOOD_IN_FLIGHT_STATUSES,
  RIDE_OPEN_STATUSES,
} from './ops-overview.constants.js';
import {
  statusCount,
  statusCountMap,
  sumStatuses,
  type StatusCountRow,
} from './ops-overview.aggregates.js';
import { startOfTodayHoChiMinh, todayTimezoneLabel } from './ops-overview.day.js';
import {
  EMPTY_MONITOR_PANELS,
  EMPTY_OVERVIEW_PANELS,
  activityFromExceptionRow,
  activityFromFoodRow,
  activityFromRideRow,
  buildHourlyTrendBuckets,
  buildMonitorQueue,
  deriveSystemAlerts,
  hoursAgoUtc,
  mergeAreaDemand,
  mergeRecentActivityItems,
  mergeCountRowsByName,
  normalizeShortAreaLabel,
  withShare,
  type HourlyCountRow,
  type OpsMapMarker,
  type OpsMonitorPanels,
  type OpsOverviewPanels,
  type OpsRecentActivityItem,
} from './ops-overview.enrichment.js';
import { OpsExceptionsService } from './ops-exceptions.service.js';

export type OpsOverviewSummary = {
  ridesTotal: number;
  ridesNegotiating: number;
  ridesAssigned: number;
  ridesCompletedToday: number;
  ridesCancelledToday: number;
  foodOrdersTotal: number;
  foodPlaced: number;
  foodPreparing: number;
  /** Sum of FOOD_IN_FLIGHT_STATUSES (PLACED|PREPARING|READY|ASSIGNED|PICKED_UP). */
  foodInFlight: number;
  foodDeliveredToday: number;
  customersTotal: number;
  driversTotal: number;
  driversOnline: number;
  storesTotal: number;
  exceptionsOpen: number;
  /** Explicitly unavailable — no ledger aggregate for ops KPIs yet. */
  revenueVnd: null;
  commissionVnd: null;
  todayTimezone: ReturnType<typeof todayTimezoneLabel>;
  generatedAt: string;
} & OpsOverviewPanels;

export type OpsMonitorSnapshot = {
  ridesOpen: number;
  ridesNegotiating: number;
  foodReady: number;
  foodInFlight: number;
  driversOnline: number;
  exceptionsOpen: number;
  generatedAt: string;
} & OpsMonitorPanels;

const EMPTY_OVERVIEW: Omit<
  OpsOverviewSummary,
  'generatedAt' | 'todayTimezone' | keyof OpsOverviewPanels
> = {
  ridesTotal: 0,
  ridesNegotiating: 0,
  ridesAssigned: 0,
  ridesCompletedToday: 0,
  ridesCancelledToday: 0,
  foodOrdersTotal: 0,
  foodPlaced: 0,
  foodPreparing: 0,
  foodInFlight: 0,
  foodDeliveredToday: 0,
  customersTotal: 0,
  driversTotal: 0,
  driversOnline: 0,
  storesTotal: 0,
  exceptionsOpen: 0,
  revenueVnd: null,
  commissionVnd: null,
};

type QueryClient = PrismaClient | Prisma.TransactionClient;

const OPS_OVERVIEW_STATEMENT_TIMEOUT_SQL =
  `SET LOCAL statement_timeout = '15s'` as const;

const OPS_OVERVIEW_TX_TIMEOUT_MS = 15_000;

/** Per-status sample before GROUP BY — uses (status, updatedAt) index and stops early. */
const AREA_PER_STATUS_CAP = 400;
const ACTIVITY_SOURCE_LIMIT = 8;
const OVERVIEW_ACTIVITY_LIMIT = 8;
const MONITOR_ACTIVITY_LIMIT = 10;
/** Keep monitor map payload small — client clusters further if needed. */
const MAP_DRIVER_CAP = 40;
const MAP_RIDE_CAP = 30;
const MAP_FOOD_CAP = 30;
/** Fresh window — after this, serve stale and refresh in background. */
const OVERVIEW_CACHE_TTL_MS = 30_000;
/** Absolute max age before a stale response is refused (force rebuild). */
const OVERVIEW_STALE_MAX_MS = 120_000;
/**
 * Hourly trend scans dense seed/history windows. Cache longer so overview
 * rebuilds stay on the fast KPI path.
 */
const HOURLY_TREND_CACHE_TTL_MS = 300_000;

const FOOD_MAP_STATUSES = ['READY', 'ASSIGNED', 'PICKED_UP'] as const;

/**
 * Hourly volume uses terminal statuses only so each arm hits
 * (status, createdAt) instead of scanning the whole 24h window.
 */
const RIDE_HOURLY_VOLUME_STATUSES = [
  'COMPLETED',
  'CANCELLED',
  'EXPIRED',
] as const;

const FOOD_HOURLY_VOLUME_STATUSES = [
  'DELIVERED',
  'FAILED',
  'CANCELLED',
] as const;

@Injectable()
export class OpsOverviewService implements OnModuleInit {
  private readonly logger = new Logger(OpsOverviewService.name);
  private overviewCache: { atMs: number; value: OpsOverviewSummary } | null =
    null;
  private overviewInFlight: Promise<OpsOverviewSummary> | null = null;
  private hourlyTrendCache: {
    atMs: number;
    rides: HourlyCountRow[];
    food: HourlyCountRow[];
    negotiating: HourlyCountRow[];
  } | null = null;
  private hourlyTrendInFlight: Promise<{
    rides: HourlyCountRow[];
    food: HourlyCountRow[];
    negotiating: HourlyCountRow[];
  }> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly exceptions: OpsExceptionsService,
  ) {}

  onModuleInit(): void {
    // Defer warmup so boot + pool settle before the heavy rebuild.
    setTimeout(() => {
      void this.overview().catch((error: unknown) => {
        this.logOverviewFailure('overview.warmup', error);
      });
    }, 2_000);
  }

  async overview(now = new Date()): Promise<OpsOverviewSummary> {
    const cacheHit = this.overviewCache;
    const ageMs = cacheHit ? now.getTime() - cacheHit.atMs : Number.POSITIVE_INFINITY;

    if (cacheHit && ageMs < OVERVIEW_CACHE_TTL_MS) {
      return cacheHit.value;
    }

    // Stale-while-revalidate: never make the UI wait ~1.5s on a warm process.
    if (cacheHit && ageMs < OVERVIEW_STALE_MAX_MS) {
      if (!this.overviewInFlight) {
        this.overviewInFlight = this.loadOverview(now)
          .then((summary) => {
            this.overviewCache = { atMs: Date.now(), value: summary };
            return summary;
          })
          .finally(() => {
            this.overviewInFlight = null;
          });
      }
      return cacheHit.value;
    }

    if (this.overviewInFlight) {
      return this.overviewInFlight;
    }

    this.overviewInFlight = this.loadOverview(now)
      .then((summary) => {
        this.overviewCache = { atMs: Date.now(), value: summary };
        return summary;
      })
      .finally(() => {
        this.overviewInFlight = null;
      });

    return this.overviewInFlight;
  }

  private async loadOverview(now: Date): Promise<OpsOverviewSummary> {
    const generatedAt = now.toISOString();
    const todayTimezone = todayTimezoneLabel();
    const db = this.prisma.db();
    if (!db) {
      return {
        ...EMPTY_OVERVIEW,
        ...EMPTY_OVERVIEW_PANELS,
        todayTimezone,
        generatedAt,
      };
    }

    const dayStart = startOfTodayHoChiMinh(now);
    const rebuildStarted = Date.now();

    try {
      // Two waves keep the Prisma pool from saturating on ~1M-row tables.
      const [
        totals,
        rideFocus,
        foodFocus,
        rideCompletedToday,
        rideCancelledToday,
        foodToday,
        directory,
        exceptionsOpen,
      ] = await Promise.all([
        db.$queryRaw<Array<{ rides: bigint; food: bigint }>>`
          SELECT
            (SELECT COUNT(*)::bigint FROM rides) AS rides,
            (SELECT COUNT(*)::bigint FROM food_orders) AS food
        `,
        db.$queryRaw<Array<{ negotiating: bigint; assigned: bigint }>>`
          SELECT
            (SELECT COUNT(*)::bigint FROM rides
              WHERE status = 'NEGOTIATING'::"RideStatus") AS negotiating,
            (SELECT COUNT(*)::bigint FROM rides
              WHERE status = 'ASSIGNED'::"RideStatus") AS assigned
        `,
        db.$queryRaw<
          Array<{ placed: bigint; preparing: bigint; inFlight: bigint }>
        >`
          SELECT
            (SELECT COUNT(*)::bigint FROM food_orders
              WHERE status = 'PLACED'::"FoodOrderStatus") AS placed,
            (SELECT COUNT(*)::bigint FROM food_orders
              WHERE status = 'PREPARING'::"FoodOrderStatus") AS preparing,
            (SELECT COUNT(*)::bigint FROM food_orders
              WHERE status IN (
                'PLACED'::"FoodOrderStatus",
                'PREPARING'::"FoodOrderStatus",
                'READY'::"FoodOrderStatus",
                'ASSIGNED'::"FoodOrderStatus",
                'PICKED_UP'::"FoodOrderStatus"
              )) AS "inFlight"
        `,
        db.$queryRaw<Array<{ cnt: bigint }>>`
          SELECT COUNT(*)::bigint AS cnt
          FROM rides
          WHERE status = 'COMPLETED'::"RideStatus"
            AND "updatedAt" >= ${dayStart}
        `,
        db.$queryRaw<Array<{ cnt: bigint }>>`
          SELECT COUNT(*)::bigint AS cnt
          FROM rides
          WHERE status = 'CANCELLED'::"RideStatus"
            AND "updatedAt" >= ${dayStart}
        `,
        db.$queryRaw<Array<{ delivered: bigint }>>`
          SELECT COUNT(*)::bigint AS delivered
          FROM food_orders
          WHERE status = 'DELIVERED'::"FoodOrderStatus"
            AND "updatedAt" >= ${dayStart}
        `,
        db.$queryRaw<
          Array<{
            customers: bigint;
            drivers: bigint;
            online: bigint;
            stores: bigint;
          }>
        >`
          SELECT
            (SELECT COUNT(*)::bigint FROM role_grants
              WHERE role = 'CUSTOMER'::"Role" AND status = 'ACTIVE'::"RoleGrantStatus") AS customers,
            (SELECT COUNT(*)::bigint FROM role_grants
              WHERE role = 'DRIVER'::"Role" AND status = 'ACTIVE'::"RoleGrantStatus") AS drivers,
            (SELECT COUNT(*)::bigint FROM driver_presence WHERE online = true) AS online,
            (SELECT COUNT(*)::bigint FROM food_stores) AS stores
        `,
        this.exceptions.countOpen(now),
      ]);

      const panels = await this.safeOverviewPanels(db, now);
      // Refresh dense hourly scan after the response path — never contend for pool.
      this.scheduleHourlyTrendRefresh(db, hoursAgoUtc(now, 24), now);

      const dir = directory[0];
      const focus = rideFocus[0];
      const food = foodFocus[0];

      const summary: OpsOverviewSummary = {
        ridesTotal: Number(totals[0]?.rides ?? 0n),
        ridesNegotiating: Number(focus?.negotiating ?? 0n),
        ridesAssigned: Number(focus?.assigned ?? 0n),
        ridesCompletedToday: Number(rideCompletedToday[0]?.cnt ?? 0n),
        ridesCancelledToday: Number(rideCancelledToday[0]?.cnt ?? 0n),
        foodOrdersTotal: Number(totals[0]?.food ?? 0n),
        foodPlaced: Number(food?.placed ?? 0n),
        foodPreparing: Number(food?.preparing ?? 0n),
        foodInFlight: Number(food?.inFlight ?? 0n),
        foodDeliveredToday: Number(foodToday[0]?.delivered ?? 0n),
        customersTotal: Number(dir?.customers ?? 0n),
        driversTotal: Number(dir?.drivers ?? 0n),
        driversOnline: Number(dir?.online ?? 0n),
        storesTotal: Number(dir?.stores ?? 0n),
        exceptionsOpen,
        revenueVnd: null,
        commissionVnd: null,
        todayTimezone,
        generatedAt,
        ...panels,
      };
      this.logger.log(`overview.rebuild ${Date.now() - rebuildStarted}ms`);
      return summary;
    } catch (error) {
      this.logOverviewFailure('overview', error);
      throw new InternalServerErrorException('Ops overview query failed');
    }
  }

  async monitorSnapshot(now = new Date()): Promise<OpsMonitorSnapshot> {
    const generatedAt = now.toISOString();
    const emptyCore = {
      ridesOpen: 0,
      ridesNegotiating: 0,
      foodReady: 0,
      foodInFlight: 0,
      driversOnline: 0,
      exceptionsOpen: 0,
    };
    const db = this.prisma.db();
    if (!db) {
      return {
        ...emptyCore,
        generatedAt,
        ...EMPTY_MONITOR_PANELS,
        queue: buildMonitorQueue(emptyCore),
        systemAlerts: deriveSystemAlerts(emptyCore),
      };
    }

    try {
      const [rideOpenRows, foodInFlightRows, driversOnline, exceptionsOpen] =
        await db.$transaction(
          async (tx) => {
            await tx.$executeRawUnsafe(OPS_OVERVIEW_STATEMENT_TIMEOUT_SQL);

            const ridesByStatus = await tx.$queryRaw<StatusCountRow[]>`
            SELECT status::text AS status, COUNT(*)::bigint AS cnt
            FROM rides
            WHERE status IN (
              'NEGOTIATING'::"RideStatus",
              'ASSIGNED'::"RideStatus",
              'DRIVER_EN_ROUTE'::"RideStatus",
              'DRIVER_ARRIVED'::"RideStatus",
              'IN_TRIP'::"RideStatus"
            )
            GROUP BY status
          `;

            const foodByStatus = await tx.$queryRaw<StatusCountRow[]>`
            SELECT status::text AS status, COUNT(*)::bigint AS cnt
            FROM food_orders
            WHERE status IN (
              'PLACED'::"FoodOrderStatus",
              'PREPARING'::"FoodOrderStatus",
              'READY'::"FoodOrderStatus",
              'ASSIGNED'::"FoodOrderStatus",
              'PICKED_UP'::"FoodOrderStatus"
            )
            GROUP BY status
          `;

            const online = await tx.$queryRaw<Array<{ cnt: bigint }>>`
            SELECT COUNT(*)::bigint AS cnt
            FROM driver_presence
            WHERE online = true
          `;

            return [
              ridesByStatus,
              foodByStatus,
              Number(online[0]?.cnt ?? 0n),
              await this.exceptions.countOpen(now, tx),
            ] as const;
          },
          {
            maxWait: 5_000,
            timeout: OPS_OVERVIEW_TX_TIMEOUT_MS,
          },
        );

      const rides = statusCountMap(rideOpenRows);
      const foods = statusCountMap(foodInFlightRows);

      const core = {
        ridesOpen: sumStatuses(rides, RIDE_OPEN_STATUSES),
        ridesNegotiating: statusCount(rides, 'NEGOTIATING'),
        foodReady: statusCount(foods, 'READY'),
        foodInFlight: sumStatuses(foods, FOOD_IN_FLIGHT_STATUSES),
        driversOnline,
        exceptionsOpen,
        generatedAt,
      };

      const panels = await this.safeMonitorPanels(db, now, core);
      return { ...core, ...panels };
    } catch (error) {
      this.logOverviewFailure('monitorSnapshot', error);
      throw new InternalServerErrorException('Ops monitor snapshot query failed');
    }
  }

  private async safeOverviewPanels(
    db: PrismaClient,
    now: Date,
  ): Promise<OpsOverviewPanels> {
    try {
      return await this.loadOverviewPanels(db, now);
    } catch (error) {
      this.logOverviewFailure('overview.enrichment', error);
      return { ...EMPTY_OVERVIEW_PANELS };
    }
  }

  private async safeMonitorPanels(
    db: PrismaClient,
    now: Date,
    core: {
      ridesOpen: number;
      ridesNegotiating: number;
      foodReady: number;
      foodInFlight: number;
      driversOnline: number;
      exceptionsOpen: number;
    },
  ): Promise<OpsMonitorPanels> {
    try {
      return await this.loadMonitorPanels(db, now, core);
    } catch (error) {
      this.logOverviewFailure('monitorSnapshot.enrichment', error);
      return {
        ...EMPTY_MONITOR_PANELS,
        queue: buildMonitorQueue(core),
        systemAlerts: deriveSystemAlerts(core),
      };
    }
  }

  private async loadOverviewPanels(
    db: PrismaClient,
    now: Date,
  ): Promise<OpsOverviewPanels> {
    const [rideAreas, categoryRows, recentRides, recentFood, exceptionItems] =
      await Promise.all([
        this.queryRideRegionDemandFast(db),
        this.queryFoodCategoriesFast(db),
        this.queryRecentOpenRides(db, ACTIVITY_SOURCE_LIMIT),
        this.queryRecentFoodUpdates(db, ACTIVITY_SOURCE_LIMIT),
        this.safeExceptionActivity(now, ACTIVITY_SOURCE_LIMIT),
      ]);

    const activity = mergeRecentActivityItems(
      [
        ...recentRides.map(activityFromRideRow),
        ...recentFood.map(activityFromFoodRow),
        ...exceptionItems,
      ],
      OVERVIEW_ACTIVITY_LIMIT,
    );

    const hourly = this.readHourlyTrendCache();

    return {
      hourlyTrend: {
        buckets: buildHourlyTrendBuckets(
          now,
          hourly.rides,
          hourly.food,
          hourly.negotiating,
        ),
      },
      recentActivity: activity,
      ridesByArea: withShare(rideAreas),
      foodByCategory: withShare(categoryRows),
    };
  }

  private readHourlyTrendCache(): {
    rides: HourlyCountRow[];
    food: HourlyCountRow[];
    negotiating: HourlyCountRow[];
  } {
    const cached = this.hourlyTrendCache;
    if (!cached) {
      return { rides: [], food: [], negotiating: [] };
    }
    return {
      rides: cached.rides,
      food: cached.food,
      negotiating: cached.negotiating,
    };
  }

  private scheduleHourlyTrendRefresh(
    db: QueryClient,
    since: Date,
    now: Date,
  ): void {
    const cached = this.hourlyTrendCache;
    const ageMs = cached
      ? Date.now() - cached.atMs
      : Number.POSITIVE_INFINITY;
    if (ageMs < HOURLY_TREND_CACHE_TTL_MS || this.hourlyTrendInFlight) {
      return;
    }

    this.hourlyTrendInFlight = this.loadHourlyTrend(db, since)
      .then((value) => {
        this.hourlyTrendCache = { atMs: Date.now(), ...value };
        this.patchOverviewHourlyTrend(now, value);
        return value;
      })
      .catch((error: unknown) => {
        this.logOverviewFailure('overview.hourly', error);
        return {
          rides: [] as HourlyCountRow[],
          food: [] as HourlyCountRow[],
          negotiating: [] as HourlyCountRow[],
        };
      })
      .finally(() => {
        this.hourlyTrendInFlight = null;
      });
  }

  private patchOverviewHourlyTrend(
    now: Date,
    hourly: {
      rides: HourlyCountRow[];
      food: HourlyCountRow[];
      negotiating: HourlyCountRow[];
    },
  ): void {
    const cached = this.overviewCache;
    if (!cached) {
      return;
    }
    this.overviewCache = {
      atMs: cached.atMs,
      value: {
        ...cached.value,
        hourlyTrend: {
          buckets: buildHourlyTrendBuckets(
            now,
            hourly.rides,
            hourly.food,
            hourly.negotiating,
          ),
        },
      },
    };
  }

  private async loadHourlyTrend(
    db: QueryClient,
    since: Date,
  ): Promise<{
    rides: HourlyCountRow[];
    food: HourlyCountRow[];
    negotiating: HourlyCountRow[];
  }> {
    const [rideHours, foodHourRows] = await Promise.all([
      this.queryHourlyRideCounts(db, since),
      this.queryHourlyFoodCounts(db, since),
    ]);
    return {
      rides: rideHours.rides,
      food: foodHourRows,
      negotiating: rideHours.negotiating,
    };
  }

  /** Category distribution from store table — O(stores) not O(open food orders). */
  private async queryFoodCategoriesFast(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    const rows = await db.$queryRaw<Array<{ name: string; cnt: bigint }>>`
      SELECT
        COALESCE(NULLIF(BTRIM(category), ''), 'Khác') AS name,
        COUNT(*)::bigint AS cnt
      FROM food_stores
      GROUP BY 1
      ORDER BY cnt DESC, name ASC
      LIMIT 5
    `;
    return mergeCountRowsByName(
      rows.map((row) => ({
        name: row.name || 'Khác',
        count: Number(row.cnt),
      })),
    );
  }

  private async loadMonitorPanels(
    db: PrismaClient,
    now: Date,
    core: {
      ridesOpen: number;
      ridesNegotiating: number;
      foodReady: number;
      foodInFlight: number;
      driversOnline: number;
      exceptionsOpen: number;
    },
  ): Promise<OpsMonitorPanels> {
    const { mapMarkers, rideAreas, foodAreas, recentRides, recentFood } =
      await db.$transaction(
        async (tx) => {
          await tx.$executeRawUnsafe(OPS_OVERVIEW_STATEMENT_TIMEOUT_SQL);
          const markers = await this.queryMapMarkers(tx);
          const [ridesArea, foodsArea] = await this.queryRegionDemandByCode(tx);
          const rides = await this.queryRecentOpenRides(tx, MONITOR_ACTIVITY_LIMIT);
          const foods = await this.queryRecentFoodUpdates(tx, MONITOR_ACTIVITY_LIMIT);
          return {
            mapMarkers: markers,
            rideAreas: ridesArea,
            foodAreas: foodsArea,
            recentRides: rides,
            recentFood: foods,
          };
        },
        { maxWait: 5_000, timeout: OPS_OVERVIEW_TX_TIMEOUT_MS },
      );

    const [exceptionItems, pilotZoneLabel] = await Promise.all([
      this.safeExceptionActivity(now, MONITOR_ACTIVITY_LIMIT),
      this.resolvePilotZoneLabel(),
    ]);

    const recentActivity = mergeRecentActivityItems(
      [
        ...recentRides.map(activityFromRideRow),
        ...recentFood.map(activityFromFoodRow),
        ...exceptionItems,
      ],
      MONITOR_ACTIVITY_LIMIT,
    );

    return {
      mapMarkers,
      queue: buildMonitorQueue(core),
      areaDemand: mergeAreaDemand(rideAreas, foodAreas, 5),
      recentActivity,
      systemAlerts: deriveSystemAlerts(core),
      ...(pilotZoneLabel ? { pilotZoneLabel } : {}),
    };
  }

  private async safeExceptionActivity(
    now: Date,
    limit: number,
  ): Promise<OpsRecentActivityItem[]> {
    try {
      const page = await this.exceptions.list(1, limit, now);
      return page.items.map(activityFromExceptionRow);
    } catch (error) {
      this.logOverviewFailure('recentActivity.exceptions', error);
      return [];
    }
  }

  /** Label comes from ACTIVE service zones (no separate free-text setting to drift). */
  private resolvePilotZoneLabel(): Promise<string | undefined> {
    const label = activeServiceRegionsLabel();
    return Promise.resolve(label.length > 0 ? label : undefined);
  }

  /**
   * Overview ride-area chart: per-status recent samples (index on status, updatedAt)
   * instead of counting every open ride (~500k seed rows).
   */
  private async queryRideRegionDemandFast(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    const arms = RIDE_OPEN_STATUSES.map(
      (status) => `
        (
          SELECT "serviceRegionCode" AS code
          FROM rides
          WHERE status = '${status}'::"RideStatus"
            AND "serviceRegionCode" IS NOT NULL
          ORDER BY "updatedAt" DESC
          LIMIT ${AREA_PER_STATUS_CAP}
        )
      `,
    );
    const rows = await db.$queryRawUnsafe<Array<{ code: string; cnt: bigint }>>(
      `
      SELECT code, COUNT(*)::bigint AS cnt
      FROM (
        ${arms.join('\nUNION ALL\n')}
      ) sample
      GROUP BY code
      ORDER BY cnt DESC
      LIMIT 8
      `,
    );
    return rows.map((row) => ({
      name: getServiceRegion(row.code)?.label ?? row.code,
      count: Number(row.cnt),
    }));
  }

  /** Monitor map demand: exact open counts by region (smaller open set on food). */
  private async queryRegionDemandByCode(
    db: QueryClient,
  ): Promise<
    [Array<{ name: string; count: number }>, Array<{ name: string; count: number }>]
  > {
    const rideStatuses = RIDE_OPEN_STATUSES.map(
      (s) => `'${s}'::"RideStatus"`,
    ).join(',');
    const foodStatuses = FOOD_MAP_STATUSES.map(
      (s) => `'${s}'::"FoodOrderStatus"`,
    ).join(',');
    const [rideRows, foodRows] = await Promise.all([
      db.$queryRawUnsafe<Array<{ code: string | null; cnt: bigint }>>(
        `
        SELECT "serviceRegionCode" AS code, COUNT(*)::bigint AS cnt
        FROM rides
        WHERE status IN (${rideStatuses})
          AND "serviceRegionCode" IS NOT NULL
        GROUP BY "serviceRegionCode"
        ORDER BY cnt DESC
        LIMIT 8
        `,
      ),
      db.$queryRawUnsafe<Array<{ code: string | null; cnt: bigint }>>(
        `
        SELECT "serviceRegionCode" AS code, COUNT(*)::bigint AS cnt
        FROM food_orders
        WHERE status IN (${foodStatuses})
          AND "serviceRegionCode" IS NOT NULL
        GROUP BY "serviceRegionCode"
        ORDER BY cnt DESC
        LIMIT 8
        `,
      ),
    ]);
    const toNamed = (rows: Array<{ code: string | null; cnt: bigint }>) =>
      rows
        .filter((r): r is { code: string; cnt: bigint } => !!r.code)
        .map((r) => ({
          name: getServiceRegion(r.code)?.label ?? r.code,
          count: Number(r.cnt),
        }));
    return [toNamed(rideRows), toNamed(foodRows)];
  }

  /**
   * Per-status hourly buckets via (status, createdAt) index — avoids a
   * full-table 24h scan when nearly all seed rows fall in the window.
   */
  private async queryHourlyRideCounts(
    db: QueryClient,
    since: Date,
  ): Promise<{ rides: HourlyCountRow[]; negotiating: HourlyCountRow[] }> {
    const [volumeParts, negotiating] = await Promise.all([
      Promise.all(
        RIDE_HOURLY_VOLUME_STATUSES.map((status) =>
          this.queryHourlyCountsForRideStatus(db, status, since),
        ),
      ),
      this.queryHourlyCountsForRideStatus(db, 'NEGOTIATING', since),
    ]);

    return {
      rides: this.mergeHourlyCountParts(volumeParts),
      negotiating,
    };
  }

  private async queryHourlyFoodCounts(
    db: QueryClient,
    since: Date,
  ): Promise<HourlyCountRow[]> {
    const parts = await Promise.all(
      FOOD_HOURLY_VOLUME_STATUSES.map((status) =>
        this.queryHourlyCountsForFoodStatus(db, status, since),
      ),
    );
    return this.mergeHourlyCountParts(parts);
  }

  private async queryHourlyCountsForRideStatus(
    db: QueryClient,
    status: string,
    since: Date,
  ): Promise<HourlyCountRow[]> {
    return db.$queryRawUnsafe<HourlyCountRow[]>(
      `
      SELECT
        to_char(
          date_trunc('hour', "createdAt" AT TIME ZONE 'Asia/Ho_Chi_Minh'),
          'YYYY-MM-DD"T"HH24:00'
        ) || '+07:00' AS "hourKey",
        COUNT(*)::bigint AS cnt
      FROM rides
      WHERE status = '${status}'::"RideStatus"
        AND "createdAt" >= $1
      GROUP BY 1
      ORDER BY 1
      `,
      since,
    );
  }

  private async queryHourlyCountsForFoodStatus(
    db: QueryClient,
    status: string,
    since: Date,
  ): Promise<HourlyCountRow[]> {
    return db.$queryRawUnsafe<HourlyCountRow[]>(
      `
      SELECT
        to_char(
          date_trunc('hour', "createdAt" AT TIME ZONE 'Asia/Ho_Chi_Minh'),
          'YYYY-MM-DD"T"HH24:00'
        ) || '+07:00' AS "hourKey",
        COUNT(*)::bigint AS cnt
      FROM food_orders
      WHERE status = '${status}'::"FoodOrderStatus"
        AND "createdAt" >= $1
      GROUP BY 1
      ORDER BY 1
      `,
      since,
    );
  }

  private mergeHourlyCountParts(parts: HourlyCountRow[][]): HourlyCountRow[] {
    const merged = new Map<string, number>();
    for (const rows of parts) {
      for (const row of rows) {
        merged.set(
          row.hourKey,
          (merged.get(row.hourKey) ?? 0) + Number(row.cnt),
        );
      }
    }
    return [...merged.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([hourKey, cnt]) => ({ hourKey, cnt }));
  }

  /** Top areas from per-status open-ride samples (status+updatedAt index). */
  private async queryRideAreas(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    return this.aggregateLabelShares(
      db,
      this.buildRideAreaSampleSql(RIDE_OPEN_STATUSES, 'pickupLabel', 5),
    );
  }

  /** Top categories from per-status in-flight food samples. */
  private async queryFoodCategories(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    const arms = FOOD_IN_FLIGHT_STATUSES.map(
      (status) => `
        (
          SELECT "storeId"
          FROM food_orders
          WHERE status = '${status}'::"FoodOrderStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${AREA_PER_STATUS_CAP}
        )
      `,
    );
    const rows = await db.$queryRawUnsafe<
      Array<{ name: string; cnt: bigint }>
    >(
      `
      SELECT name, COUNT(*)::bigint AS cnt
      FROM (
        SELECT
          COALESCE(NULLIF(BTRIM(s.category), ''), 'Khác') AS name
        FROM (
          ${arms.join('\nUNION ALL\n')}
        ) o
        INNER JOIN food_stores s ON s.id = o."storeId"
      ) sample
      GROUP BY name
      ORDER BY cnt DESC, name ASC
      LIMIT 5
      `,
    );
    return mergeCountRowsByName(
      rows.map((row) => ({
        name: row.name || 'Khác',
        count: Number(row.cnt),
      })),
    );
  }

  private async queryOpenRideAreas(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    return this.aggregateLabelShares(
      db,
      this.buildRideAreaSampleSql(RIDE_OPEN_STATUSES, 'pickupLabel', 8),
    );
  }

  private async queryOpenFoodAreas(
    db: QueryClient,
  ): Promise<Array<{ name: string; count: number }>> {
    const labelExpr = this.sqlNormalizeAreaLabelExpr('"dropoffLabel"');
    const arms = FOOD_MAP_STATUSES.map(
      (status) => `
        (
          SELECT ${labelExpr} AS name
          FROM food_orders
          WHERE status = '${status}'::"FoodOrderStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${AREA_PER_STATUS_CAP}
        )
      `,
    );
    return this.aggregateLabelShares(
      db,
      `
      SELECT name, COUNT(*)::bigint AS cnt
      FROM (
        ${arms.join('\nUNION ALL\n')}
      ) sample
      GROUP BY name
      ORDER BY cnt DESC, name ASC
      LIMIT 8
      `,
    );
  }

  private buildRideAreaSampleSql(
    statuses: readonly string[],
    labelColumn: 'pickupLabel' | 'dropoffLabel',
    limit: number,
  ): string {
    const labelExpr = this.sqlNormalizeAreaLabelExpr(`"${labelColumn}"`);
    const arms = statuses.map(
      (status) => `
        (
          SELECT ${labelExpr} AS name
          FROM rides
          WHERE status = '${status}'::"RideStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${AREA_PER_STATUS_CAP}
        )
      `,
    );
    return `
      SELECT name, COUNT(*)::bigint AS cnt
      FROM (
        ${arms.join('\nUNION ALL\n')}
      ) sample
      GROUP BY name
      ORDER BY cnt DESC, name ASC
      LIMIT ${limit}
    `;
  }

  /**
   * Mirrors `normalizeShortAreaLabel` so Perf seed labels collapse before
   * GROUP BY / LIMIT (otherwise top-N is wasted on unique Perf pickup* rows).
   */
  private sqlNormalizeAreaLabelExpr(columnSql: string): string {
    return `CASE
      WHEN NULLIF(BTRIM(SPLIT_PART(${columnSql}, ',', 1)), '') IS NULL THEN 'Khác'
      WHEN BTRIM(SPLIT_PART(${columnSql}, ',', 1)) ~* '^perf([^[:alnum:]_]|$)'
        THEN 'Khu vực thử nghiệm'
      ELSE LEFT(BTRIM(SPLIT_PART(${columnSql}, ',', 1)), 48)
    END`;
  }

  private async aggregateLabelShares(
    db: QueryClient,
    sql: string,
  ): Promise<Array<{ name: string; count: number }>> {
    const rows = await db.$queryRawUnsafe<Array<{ name: string; cnt: bigint }>>(
      sql,
    );
    return mergeCountRowsByName(
      rows.map((row) => ({
        name: normalizeShortAreaLabel(row.name),
        count: Number(row.cnt),
      })),
    );
  }

  private async queryRecentOpenRides(
    db: QueryClient,
    limit: number,
  ): Promise<
    Array<{
      id: string;
      status: string;
      pickupLabel: string | null;
      updatedAt: Date;
    }>
  > {
    const arms = RIDE_OPEN_STATUSES.map(
      (status) => `
        (
          SELECT id::text AS id, status::text AS status, "pickupLabel", "updatedAt"
          FROM rides
          WHERE status = '${status}'::"RideStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${limit}
        )
      `,
    );
    return db.$queryRawUnsafe(
      `
      SELECT id, status, "pickupLabel", "updatedAt"
      FROM (
        ${arms.join('\nUNION ALL\n')}
      ) candidates
      ORDER BY "updatedAt" DESC
      LIMIT ${limit}
      `,
    );
  }

  private async queryRecentFoodUpdates(
    db: QueryClient,
    limit: number,
  ): Promise<
    Array<{
      id: string;
      status: string;
      dropoffLabel: string | null;
      updatedAt: Date;
    }>
  > {
    return db.$queryRaw`
      SELECT id::text AS id, status::text AS status, "dropoffLabel", "updatedAt"
      FROM food_orders
      WHERE status IN (
        'PLACED'::"FoodOrderStatus",
        'PREPARING'::"FoodOrderStatus",
        'READY'::"FoodOrderStatus",
        'ASSIGNED'::"FoodOrderStatus",
        'PICKED_UP'::"FoodOrderStatus"
      )
      ORDER BY "updatedAt" DESC
      LIMIT ${limit}
    `;
  }

  private async queryMapMarkers(db: QueryClient): Promise<OpsMapMarker[]> {
    const drivers = await db.$queryRaw<
      Array<{ id: string; lat: number; lng: number }>
    >`
      SELECT "userId"::text AS id, lat, lng
      FROM driver_presence
      WHERE online = true
        AND lat IS NOT NULL
        AND lng IS NOT NULL
      ORDER BY "updatedAt" DESC
      LIMIT ${MAP_DRIVER_CAP}
    `;

    const rideArms = RIDE_OPEN_STATUSES.map(
      (status) => `
        (
          SELECT
            id::text AS id,
            "pickupLat" AS lat,
            "pickupLng" AS lng,
            "pickupLabel" AS label,
            "updatedAt"
          FROM rides
          WHERE status = '${status}'::"RideStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${MAP_RIDE_CAP}
        )
      `,
    );
    const rides = await db.$queryRawUnsafe<
      Array<{ id: string; lat: number; lng: number; label: string }>
    >(
      `
      SELECT id, lat, lng, label
      FROM (
        ${rideArms.join('\nUNION ALL\n')}
      ) candidates
      ORDER BY "updatedAt" DESC
      LIMIT ${MAP_RIDE_CAP}
      `,
    );

    const foodArms = FOOD_MAP_STATUSES.map(
      (status) => `
        (
          SELECT
            id::text AS id,
            "dropoffLat" AS lat,
            "dropoffLng" AS lng,
            "dropoffLabel" AS label,
            "updatedAt"
          FROM food_orders
          WHERE status = '${status}'::"FoodOrderStatus"
          ORDER BY "updatedAt" DESC
          LIMIT ${MAP_FOOD_CAP}
        )
      `,
    );
    const foods = await db.$queryRawUnsafe<
      Array<{ id: string; lat: number; lng: number; label: string }>
    >(
      `
      SELECT id, lat, lng, label
      FROM (
        ${foodArms.join('\nUNION ALL\n')}
      ) candidates
      ORDER BY "updatedAt" DESC
      LIMIT ${MAP_FOOD_CAP}
      `,
    );

    return [
      ...drivers.map((row) => ({
        id: row.id,
        kind: 'driver' as const,
        lat: row.lat,
        lng: row.lng,
        label: 'Tài xế online',
      })),
      ...rides.map((row) => ({
        id: row.id,
        kind: 'ride' as const,
        lat: row.lat,
        lng: row.lng,
        label: `Chuyến · ${normalizeShortAreaLabel(row.label)}`,
      })),
      ...foods.map((row) => ({
        id: row.id,
        kind: 'food' as const,
        lat: row.lat,
        lng: row.lng,
        label: `Đồ ăn · ${normalizeShortAreaLabel(row.label)}`,
      })),
    ];
  }

  private logOverviewFailure(operation: string, error: unknown): void {
    if (error instanceof Error) {
      this.logger.error(
        `ops.${operation} failed: ${error.message}`,
        error.stack,
      );
      return;
    }
    this.logger.error(`ops.${operation} failed: ${String(error)}`);
  }
}
