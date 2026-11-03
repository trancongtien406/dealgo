import {
  type OpsDateWindow,
  prismaDateFilter,
} from '../operations/ops-date-window.js';
import { cancellationCountsAgainstDriver } from '../../shared/cancel-actor.js';
import type { CancelActorName } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import type {
  CompletionHook,
  TxHandle,
} from '../../shared/tx/completion-hook.js';
import { randomUUID } from 'node:crypto';
import {
  normalizeRegionFilter,
  regionCodeOrLabelFallbackWhere,
  resolveServiceRegionCode,
} from '../service-area/service-regions.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { paymentFilterMatchers } from '../payment/ops-payment-filter.js';
import {
  writeFoodChangeOutbox,
  writeFoodFareOutbox,
  writeOpsActionOutbox,
  writeStatusOutbox,
} from '../communication/outbox/outbox.write.js';
import { FoodRuleError } from './food.error.js';
import {
  effectiveServiceMode,
  type StoreServiceMode,
} from './store-service-mode.js';
import {
  acceptSettingsFromRow,
  atCapacity,
  estimatedReadyAt,
  KITCHEN_ACTIVE_STATUSES,
  placementStatus,
  prepMinutesFor,
  type StoreAcceptMode,
} from './store-accept.js';
import {
  closesAtToday,
  formatClock,
  scheduleView,
  storeAvailability,
  vnClock,
  type StoreSchedule,
} from './store-schedule.js';
import {
  likePattern,
  pickFeaturedItems,
  shownOriginalPrice,
} from './food.repository.js';
import type {
  StoreFeaturedItem,
  CatalogItemInput,
  FoodFailInput,
  MerchantSettlementView,
  MerchantStatementRow,
  RecordMerchantSettlementInput,
  CreateCatalogItemInput,
  FoodDriverHistoryWindow,
  FoodOrderView,
  FoodRepository,
  OpsCatalogModerationPage,
  OpsFoodInterveneResult,
  OpsFoodOrderPage,
  OpsStoreDetail,
  OpsStorePage,
  PlaceFoodInput,
  ReplaceItemOptionsInput,
  QueueOrderSummary,
  MerchantStatsRows,
  ReadyNearFilter,
  ReadyOrderSummary,
  SetItemAvailabilityInput,
  ListFoodStoresQuery,
  StoreBrowsePage,
  DishSearchPage,
  DishSearchQuery,
  ItemSuggestionsQuery,
  StoreItemSuggestion,
  StoreDetail,
  StoreItemView,
  UpdateCatalogItemInput,
  UpdateStoreLocationInput,
  UpdateStoreProfileInput,
  UpdateStoreScheduleInput,
  UpdateStoreServiceModeInput,
  UpdateStoreAcceptSettingsInput,
  FoodCancelReason,
  FoodEarlyClaim,
  FoodTimeoutPolicy,
  FoodTimedOut,
} from './food.repository.js';
import {
  FIXTURE_STORE_PIN,
  FOOD_CHANGE_EDITABLE_STATUSES,
  counterCeilingVnd,
  type FoodClaimFare,
  type FoodDeliveryOfferView,
  type RaiseFoodDeliveryFareInput,
  type SubmitFoodDeliveryOfferInput,
  planFoodOrderChange,
  type FoodOrderChangeLine,
  type FoodOrderChangeResult,
  type FoodOrderChangeStatusName,
  type FoodOrderChangeView,
  type ProposeFoodOrderChangeInput,
} from './food.repository.js';
import {
  FOOD_REJECT_REASONS,
  FOOD_SYSTEM_CANCEL_REASONS,
  FOOD_CHANGE_CANCEL_REASONS,
  type FoodCancelReasonCode,
  type FoodSystemCancelReason,
} from './food.constants.js';
import { lockDriverAssignment } from '../../shared/tx/driver-assignment-lock.js';
import {
  DRIVER_HISTORY_FOOD_STATUSES,
  assertFailWaitOver,
  earlyClaimOpensAt,
  UNCATEGORIZED_STORE_CATEGORY_NAME,
  snapshotFoodLines,
} from './food.repository.js';
import {
  normalizeOptionGroups,
  parseLineOptions,
  type FoodOptionGroupView,
} from './food-options.js';
import {
  redeemVoucherInTx,
  releaseVoucherInTx,
  VoucherRejectedError,
} from '../promotion/promotion-redemption.js';

const OPEN_STATUSES = [
  'PLACED',
  'PREPARING',
  'READY',
  'ASSIGNED',
  'PICKED_UP',
] as const;

type OrderRow = {
  id: string;
  customerId: string;
  storeId: string;
  status: FoodOrderView['status'];
  deliveryFareVnd: number;
  subtotalVnd: number;
  discountVnd: number;
  voucherCode: string | null;
  voucherSponsor: FoodOrderView['voucherSponsor'];
  totalVnd: number;
  dropoffLat: number;
  dropoffLng: number;
  dropoffLabel: string;
  pickupLat: number | null;
  pickupLng: number | null;
  pickupLabel: string | null;
  serviceRegionCode: string | null;
  assignedDriverId: string | null;
  cancelReasonCode: string | null;
  cancelNote: string | null;
  cancelledBy?: CancelActorName | null;
  note: string | null;
  utensils: boolean;
  prepMinutes: number | null;
  pickedUpAt?: Date | null;
  failReasonCode?: string | null;
  failNote?: string | null;
  merchantCashVnd?: number | null;
  suggestedDeliveryFareVnd?: number | null;
  deliveryFareAgreedAt?: Date | null;
  deliveryFareRaiseCount?: number;
  createdAt: Date;
  updatedAt: Date;
  store: {
    ownerId: string;
    name: string;
    serviceRegionCode: string | null;
    lat: number | null;
    lng: number | null;
    addressLabel: string | null;
  };
  lines: {
    id: string;
    itemId: string;
    name: string;
    unitPriceVnd: number;
    quantity: number;
    imageUrl: string | null;
    note: string | null;
    options: Prisma.JsonValue;
  }[];
};

const orderInclude = {
  lines: true,
  store: {
    select: {
      ownerId: true,
      name: true,
      serviceRegionCode: true,
      lat: true,
      lng: true,
      addressLabel: true,
    },
  },
} as const;

export class PrismaFoodRepository implements FoodRepository {
  constructor(private readonly db: PrismaClient) {}

  async hasStore(): Promise<boolean> {
    const count = await this.db.foodStore.count();
    return count > 0;
  }

  async createFixtureStore(
    ownerId: string,
    items: CatalogItemInput[],
  ): Promise<void> {
    await this.db.$transaction(async (tx) => {
      const existing = await tx.foodStore.count();
      if (existing > 0) {
        return;
      }
      await tx.foodStore.create({
        data: {
          ownerId,
          name: 'Bún Bò Huế',
          category: 'pho',
          // Stores need coordinates to take delivery orders (sandbox demo: Hải Châu).
          lat: FIXTURE_STORE_PIN.lat,
          lng: FIXTURE_STORE_PIN.lng,
          addressLabel: FIXTURE_STORE_PIN.label,
          serviceRegionCode: resolveServiceRegionCode(FIXTURE_STORE_PIN),
          items: {
            create: items.map((item) => ({
              name: item.name,
              priceVnd: item.priceVnd,
              available: true,
              moderationStatus: 'APPROVED',
            })),
          },
        },
      });
    });
  }

  async listStores(query: ListFoodStoresQuery): Promise<StoreBrowsePage> {
    const search = query.search?.trim() || undefined;
    const category = query.category?.trim() || undefined;
    const hasGeo = query.lat !== undefined && query.lng !== undefined;
    const sortBy =
      query.sortBy === 'distance' && !hasGeo ? 'createdAt' : query.sortBy;
    const skip = (query.page - 1) * query.limit;
    const now = new Date();

    const distanceSql = hasGeo
      ? distanceKmSql(query.lat!, query.lng!)
      : Prisma.sql`NULL::double precision`;

    // A store without coordinates cannot take delivery orders, so it is not listed.
    const filters: Prisma.Sql[] = [
      Prisma.sql`s."lat" IS NOT NULL`,
      Prisma.sql`s."lng" IS NOT NULL`,
    ];
    if (hasGeo) {
      filters.push(Prisma.sql`${distanceSql} <= ${query.radiusKm}`);
    }
    if (search) {
      const like = '%' + search + '%';
      // Store name or any dish/drink on its menu.
      filters.push(Prisma.sql`(s."name" ILIKE ${like} OR EXISTS (
        SELECT 1 FROM "food_items" fi WHERE fi."storeId" = s."id" AND fi."name" ILIKE ${like}
      ))`);
    }
    if (category) {
      filters.push(Prisma.sql`LOWER(s."category") = LOWER(${category})`);
    }
    const whereSql = Prisma.join(filters, ' AND ');
    const openSql = openNowSql(now);

    const minRatingCount = Math.max(1, query.minRatingCount ?? 1);
    const orderSql =
      sortBy === 'name'
        ? Prisma.sql`s."name" ASC, s."id" ASC`
        : sortBy === 'createdAt'
          ? Prisma.sql`s."createdAt" DESC, s."id" ASC`
          : sortBy === 'rating'
            ? Prisma.sql`(CASE WHEN rt.rating_count >= ${minRatingCount} THEN rt.rating_avg END) DESC NULLS LAST, rt.rating_count DESC, s."id" ASC`
            : Prisma.sql`distance_km ASC, s."id" ASC`;

    const countRows = await this.db.$queryRaw<Array<{ total: bigint }>>`
      SELECT COUNT(*)::bigint AS total
      FROM "food_stores" s
      WHERE ${whereSql}
    `;
    const total = Number(countRows[0]?.total ?? 0);

    const rows = await this.db.$queryRaw<
      Array<{
        id: string;
        name: string;
        ownerId: string;
        lat: number | null;
        lng: number | null;
        category: string | null;
        createdAt: Date;
        serviceMode: StoreServiceMode;
        serviceModeUntil: Date | null;
        open_now: boolean;
        closes_minute: number | null;
        distance_km: number | null;
        imageUrl: string | null;
        logoUrl: string | null;
        minOrderVnd: number;
        defaultPrepMinutes: number;
        busyExtraMinutes: number;
        rating_count: number;
        rating_avg: number | null;
      }>
    >`
      SELECT
        s."id",
        s."name",
        s."ownerId",
        s."lat",
        s."lng",
        s."category",
        s."createdAt",
        s."serviceMode"::text AS "serviceMode",
        s."serviceModeUntil",
        ${openSql} AS open_now,
        shift_today.closes_minute,
        ${distanceSql} AS distance_km,
        COALESCE(s."coverUrl", cover."imageUrl") AS "imageUrl",
        s."logoUrl",
        s."minOrderVnd",
        s."defaultPrepMinutes",
        s."busyExtraMinutes",
        rt.rating_count,
        rt.rating_avg
      FROM "food_stores" s
      LEFT JOIN LATERAL (
        SELECT COUNT(*)::int AS rating_count, AVG(r."storeStars")::float8 AS rating_avg
        FROM "service_ratings" r
        WHERE r."storeId" = s."id" AND r."storeStars" IS NOT NULL AND r."hiddenAt" IS NULL
      ) rt ON TRUE
      LEFT JOIN LATERAL (
        SELECT i."imageUrl"
        FROM "food_items" i
        WHERE i."storeId" = s."id"
          AND i."imageUrl" IS NOT NULL
          AND i."imageUrl" <> ''
        ORDER BY i."available" DESC, i."id" ASC
        LIMIT 1
      ) cover ON TRUE
      LEFT JOIN LATERAL (
        SELECT h."closesMinute" AS closes_minute
        FROM "food_store_hours" h
        WHERE h."storeId" = s."id"
          AND ${takingOrdersShiftSql(now)}
        ORDER BY ${shiftCloseOffsetSql(now)} ASC
        LIMIT 1
      ) shift_today ON TRUE
      WHERE ${whereSql}
      ORDER BY open_now DESC, ${orderSql}
      LIMIT ${query.limit}
      OFFSET ${skip}
    `;

    return {
      total,
      items: rows.map((row) => {
        const mode = effectiveServiceMode(
          row.serviceMode,
          row.serviceModeUntil,
          now,
        ).serviceMode;
        return {
          id: row.id,
          name: row.name,
          ownerId: row.ownerId,
          lat: row.lat,
          lng: row.lng,
          category: row.category,
          createdAt: row.createdAt,
          distanceKm: row.distance_km === null ? null : Number(row.distance_km),
          serviceMode: mode,
          openNow: row.open_now,
          closedReason: row.open_now
            ? null
            : mode === 'PAUSED'
              ? 'PAUSED'
              : 'CLOSED',
          closesAtToday:
            row.open_now && row.closes_minute !== null
              ? formatClock(row.closes_minute % 1440)
              : null,
          imageUrl: row.imageUrl,
          logoUrl: row.logoUrl,
          minOrderVnd: Number(row.minOrderVnd ?? 0),
          estimatedPrepMinutes:
            row.defaultPrepMinutes +
            (mode === 'BUSY' ? row.busyExtraMinutes : 0),
          ratingCount: Number(row.rating_count ?? 0),
          ratingAverage:
            row.rating_avg === null ? null : Number(row.rating_avg),
        };
      }),
    };
  }

  async searchDishes(query: DishSearchQuery): Promise<DishSearchPage> {
    const hasGeo = query.lat !== undefined && query.lng !== undefined;
    const skip = (query.page - 1) * query.limit;
    const now = new Date();
    const like = likePattern(query.q.trim());
    const distanceSql = hasGeo
      ? distanceKmSql(query.lat!, query.lng!)
      : Prisma.sql`NULL::double precision`;
    const openSql = openNowSql(now);
    const filters: Prisma.Sql[] = [
      Prisma.sql`i."available" = TRUE`,
      Prisma.sql`i."moderationStatus" = 'APPROVED'`,
      Prisma.sql`i."name" ILIKE ${like} ESCAPE '\\'`,
      Prisma.sql`s."lat" IS NOT NULL`,
      Prisma.sql`s."lng" IS NOT NULL`,
      openSql,
    ];
    if (hasGeo) {
      filters.push(Prisma.sql`${distanceSql} <= ${query.radiusKm}`);
    }
    const whereSql = Prisma.join(filters, ' AND ');

    const countRows = await this.db.$queryRaw<Array<{ total: bigint }>>`
      SELECT COUNT(*)::bigint AS total
      FROM "food_items" i
      JOIN "food_stores" s ON s."id" = i."storeId"
      WHERE ${whereSql}
    `;
    const total = Number(countRows[0]?.total ?? 0);

    const rows = await this.db.$queryRaw<
      Array<{
        id: string;
        name: string;
        priceVnd: number;
        originalPriceVnd: number | null;
        imageUrl: string | null;
        soldCount: number;
        prepMinutes: number;
        storeId: string;
        storeName: string;
        serviceMode: StoreServiceMode;
        serviceModeUntil: Date | null;
        open_now: boolean;
        distance_km: number | null;
      }>
    >`
      SELECT
        i."id",
        i."name",
        i."priceVnd",
        i."originalPriceVnd",
        i."imageUrl",
        i."soldCount",
        COALESCE(i."prepMinutes", s."defaultPrepMinutes") AS "prepMinutes",
        s."id" AS "storeId",
        s."name" AS "storeName",
        s."serviceMode"::text AS "serviceMode",
        s."serviceModeUntil",
        ${openSql} AS open_now,
        ${distanceSql} AS distance_km
      FROM "food_items" i
      JOIN "food_stores" s ON s."id" = i."storeId"
      WHERE ${whereSql}
      ORDER BY i."soldCount" DESC, i."name" ASC, i."id" ASC
      LIMIT ${query.limit}
      OFFSET ${skip}
    `;

    return {
      total,
      items: rows.map((row) => {
        const mode = effectiveServiceMode(
          row.serviceMode,
          row.serviceModeUntil,
          now,
        ).serviceMode;
        return {
          item: {
            id: row.id,
            name: row.name,
            priceVnd: row.priceVnd,
            originalPriceVnd: shownOriginalPrice(
              row.priceVnd,
              row.originalPriceVnd,
            ),
            imageUrl: row.imageUrl,
            soldCount: row.soldCount,
            prepMinutes: row.prepMinutes,
          },
          store: {
            id: row.storeId,
            name: row.storeName,
            distanceKm: row.distance_km === null ? null : Number(row.distance_km),
            openNow: row.open_now,
            closedReason: row.open_now
              ? null
              : mode === 'PAUSED'
                ? 'PAUSED'
                : 'CLOSED',
          },
        };
      }),
    };
  }

  async listStoresPage(
    page: number,
    limit: number,
    filter?: {
      q?: string;
      status?: string;
      sale?: string;
      region?: string;
      category?: string;
      kyb?: string;
      /** MISSING = stores without map coordinates. */
      location?: string;
    },
  ): Promise<OpsStorePage> {
    const and: Prisma.FoodStoreWhereInput[] = [];
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim();
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          q,
        );
      const orConditions: Prisma.FoodStoreWhereInput[] = [
        { name: { contains: q, mode: 'insensitive' } },
        { owner: { displayName: { contains: q, mode: 'insensitive' } } },
        { owner: { email: { contains: q, mode: 'insensitive' } } },
      ];
      if (isUuid) {
        orConditions.push({ id: q }, { ownerId: q });
      }
      and.push({ OR: orConditions });
    }
    const regionCode = normalizeRegionFilter(filter?.region);
    if (regionCode) {
      and.push(
        regionCodeOrLabelFallbackWhere(regionCode, [
          'name',
        ]) as Prisma.FoodStoreWhereInput,
      );
    }
    if (filter?.category && filter.category !== 'ALL') {
      and.push({ category: filter.category });
    }
    // sale / status: OPEN ≈ available items; CLOSED ≈ none available; SUSPENDED ≈ merchant grant
    const saleOrStatus =
      filter?.sale && filter.sale !== 'ALL'
        ? filter.sale.toUpperCase()
        : filter?.status && filter.status !== 'ALL'
          ? filter.status.toUpperCase()
          : undefined;
    if (saleOrStatus === 'OPEN' || saleOrStatus === 'ACTIVE') {
      and.push({ items: { some: { available: true } } });
    } else if (saleOrStatus === 'PAUSED' || saleOrStatus === 'BUSY') {
      // DEC-PROD-026: merchant-set intake mode that has not auto-resumed yet.
      and.push({
        serviceMode: saleOrStatus,
        OR: [
          { serviceModeUntil: null },
          { serviceModeUntil: { gt: new Date() } },
        ],
      });
    } else if (saleOrStatus === 'CLOSED') {
      and.push({
        OR: [
          { items: { none: {} } },
          { items: { every: { available: false } } },
        ],
      });
    } else if (saleOrStatus === 'SUSPENDED') {
      and.push({
        owner: {
          roleGrants: { some: { role: 'MERCHANT', status: 'SUSPENDED' } },
        },
      });
    }
    if (filter?.kyb && filter.kyb !== 'ALL') {
      const kybStatus = mapKybFilterToPartnerStatus(filter.kyb);
      if (kybStatus) {
        and.push({
          owner: {
            partnerApplications: {
              some: {
                role: 'MERCHANT',
                status:
                  kybStatus === 'PENDING'
                    ? { in: ['DRAFT', 'SUBMITTED'] }
                    : kybStatus,
              },
            },
          },
        });
      }
    }
    if (filter?.location === 'MISSING') {
      and.push({ OR: [{ lat: null }, { lng: null }] });
    }
    const where: Prisma.FoodStoreWhereInput =
      and.length > 0 ? { AND: and } : {};
    const [total, stores] = await Promise.all([
      this.db.foodStore.count({ where }),
      this.db.foodStore.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          name: true,
          ownerId: true,
          lat: true,
          lng: true,
          category: true,
          serviceRegionCode: true,
          createdAt: true,
          serviceMode: true,
          serviceModeUntil: true,
          hoursConfigured: true,
          lastOrderMinutes: true,
          acceptMode: true,
          maxActiveOrders: true,
          defaultPrepMinutes: true,
          busyExtraMinutes: true,
          hours: true,
          closures: true,
          _count: { select: { items: true } },
        },
      }),
    ]);
    return {
      total,
      items: stores.map((store) => ({
        ...acceptFromRow(store),
        ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
        ...storeAvailability(
          store.serviceMode,
          store.serviceModeUntil,
          scheduleFromRow(store),
        ),
        id: store.id,
        name: store.name,
        ownerId: store.ownerId,
        lat: store.lat,
        lng: store.lng,
        category: store.category,
        serviceRegionCode: store.serviceRegionCode,
        createdAt: store.createdAt,
        itemCount: store._count.items,
      })),
    };
  }

  async listCatalogModeration(query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
    window?: OpsDateWindow;
  }): Promise<OpsCatalogModerationPage> {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.max(1, Math.min(50, query.limit ?? 10));

    const where: Prisma.FoodItemWhereInput = {};
    if (query.q?.trim()) {
      const q = query.q.trim();
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { store: { name: { contains: q, mode: 'insensitive' } } },
      ];
    }
    const storeFilter: Prisma.FoodStoreWhereInput = {};
    if (query.store && query.store !== 'ALL') {
      storeFilter.name = { contains: query.store, mode: 'insensitive' };
    }
    if (query.category && query.category !== 'ALL') {
      storeFilter.category = query.category;
    }
    if (Object.keys(storeFilter).length > 0) {
      where.store = storeFilter;
    }
    if (query.status && query.status !== 'ALL') {
      const status = query.status.toUpperCase();
      if (
        status === 'APPROVED' ||
        status === 'PENDING' ||
        status === 'REJECTED'
      ) {
        where.moderationStatus = status;
      }
    }
    const createdAt = prismaDateFilter(query.window);
    if (createdAt) {
      where.createdAt = createdAt;
    }

    const [total, rows] = await Promise.all([
      this.db.foodItem.count({ where }),
      this.db.foodItem.findMany({
        where,
        include: {
          store: { include: { categoryRef: { select: { nameVi: true } } } },
        },
        orderBy: [{ name: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

    return {
      items: rows.map((r) => ({
        id: r.id,
        code: `SP-${r.id.slice(0, 5).toUpperCase()}`,
        name: r.name,
        category:
          r.store.categoryRef?.nameVi ?? UNCATEGORIZED_STORE_CATEGORY_NAME,
        store: r.store.name,
        price: r.priceVnd,
        submittedAt: r.createdAt.toISOString(),
        status: r.moderationStatus,
        nameReady: true,
        imageReady: true,
      })),
      total,
      page,
      limit,
    };
  }

  async findStore(storeId: string): Promise<StoreDetail | null> {
    const store = await this.db.foodStore.findUnique({
      where: { id: storeId },
      include: storeDetailInclude,
    });
    if (!store) {
      return null;
    }
    return toStoreDetail(store);
  }

  async findStoreForOps(storeId: string): Promise<OpsStoreDetail | null> {
    const store = await this.db.foodStore.findUnique({
      where: { id: storeId },
      include: storeDetailInclude,
    });
    if (!store) {
      return null;
    }

    let kybDetail: OpsStoreDetail['kybDetail'] = null;
    let stats: OpsStoreDetail['stats'] = null;
    let recentOrders: OpsStoreDetail['recentOrders'] = [];
    let recentReviews: OpsStoreDetail['recentReviews'] = [];

    try {
      const [merchantApp, completedOrders, terminalOrders, ratingAgg, orders, reviews] = await Promise.all([
        this.db.partnerApplication.findFirst({
          where: { userId: store.ownerId, role: 'MERCHANT' },
          orderBy: { updatedAt: 'desc' },
        }),
        this.db.foodOrder.count({
          where: { storeId, status: 'DELIVERED' },
        }),
        this.db.foodOrder.count({
          where: { storeId, status: { in: ['DELIVERED', 'CANCELLED', 'FAILED'] } },
        }),
        this.db.serviceRating.aggregate({
          where: { storeId, storeStars: { not: null } },
          _avg: { storeStars: true },
          _count: { storeStars: true },
        }),
        this.db.foodOrder.findMany({
          where: { storeId },
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { customer: { select: { displayName: true } } },
        }),
        this.db.serviceRating.findMany({
          where: { storeId },
          orderBy: { createdAt: 'desc' },
          take: 10,
          include: { rater: { select: { displayName: true } } },
        }),
      ]);

      if (merchantApp) {
        const meta = (merchantApp.metadata as Record<string, any>) ?? {};
        const docs = Array.isArray(merchantApp.documents) ? merchantApp.documents : [];
        kybDetail = {
          applicationId: merchantApp.id,
          status: merchantApp.status,
          representativeName: meta.representativeName || meta.fullName || '',
          businessType: meta.businessType || '',
          registrationSubject: meta.registrationSubject || '',
          bankName: meta.bankName || '',
          bankAccountNumber: meta.bankAccountNumber || '',
          bankAccountHolder: meta.bankAccountHolder || '',
          documentsWaived: meta.documentsWaived === true,
          documentCount: docs.length,
          submittedAt: merchantApp.submittedAt?.toISOString() ?? null,
          reviewedAt: merchantApp.reviewedAt?.toISOString() ?? null,
        };
      }

      const statusLabels: Record<string, string> = {
        PLACED: 'Mới đặt',
        PREPARING: 'Đang chuẩn bị',
        READY: 'Sẵn sàng giao',
        ASSIGNED: 'Đã gán tài xế',
        PICKED_UP: 'Đang giao hàng',
        DELIVERED: 'Đã giao hàng',
        CANCELLED: 'Đã hủy',
        FAILED: 'Giao thất bại',
      };

      stats = {
        completedOrders,
        cancelledOrders: terminalOrders - completedOrders,
        totalOrders: terminalOrders,
        completionRate: terminalOrders > 0 ? Math.round((completedOrders / terminalOrders) * 1000) / 1000 : null,
        ratingAverage: ratingAgg._avg.storeStars ? Math.round(ratingAgg._avg.storeStars * 10) / 10 : null,
        ratingCount: ratingAgg._count.storeStars ?? 0,
      };

      recentOrders = orders.map((o) => ({
        id: o.id,
        code: `FA-${o.id.slice(0, 8).toUpperCase()}`,
        status: o.status,
        statusLabel: statusLabels[o.status] ?? o.status,
        totalVnd: o.totalVnd,
        dropoffLabel: o.dropoffLabel,
        customerName: o.customer?.displayName ?? 'Khách hàng',
        createdAt: o.createdAt.toISOString(),
      }));

      recentReviews = reviews.map((r) => ({
        id: r.id,
        stars: r.storeStars ?? 5,
        comment: r.comment ?? null,
        raterName: r.rater?.displayName ?? 'Khách hàng',
        createdAt: r.createdAt.toISOString(),
      }));
    } catch {
      // Non-blocking
    }

    return {
      ...acceptFromRow(store),
      ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
      ...storeAvailability(
        store.serviceMode,
        store.serviceModeUntil,
        scheduleFromRow(store),
      ),
      id: store.id,
      name: store.name,
      ownerId: store.ownerId,
      lat: store.lat,
      lng: store.lng,
      category: store.category,
      serviceRegionCode: store.serviceRegionCode ?? null,
      addressLabel: store.addressLabel ?? null,
      createdAt: store.createdAt,
      itemCount: store.items.length,
      items: store.items.map(prismaItemView),
      kybDetail,
      stats,
      recentOrders,
      recentReviews,
    };
  }

  async findStoreByOwner(ownerId: string): Promise<StoreDetail | null> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId },
      include: storeDetailInclude,
      orderBy: { createdAt: 'asc' },
    });
    return store ? toStoreDetail(store) : null;
  }

  async ensureOwnedStore(ownerId: string, name: string): Promise<StoreDetail> {
    const existing = await this.findStoreByOwner(ownerId);
    if (existing) {
      return existing;
    }
    // The merchant home + menu screens call this concurrently on first
    // open; check-then-create created two stores 6 ms apart. Serialize per owner
    // with a transaction advisory lock and re-check inside it.
    const created = await this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(hashtext(${`food-store-owner:${ownerId}`}))`;
      const again = await tx.foodStore.findFirst({
        where: { ownerId },
        include: storeDetailInclude,
        orderBy: { createdAt: 'asc' },
      });
      if (again) {
        return again;
      }
      // DEC-PROD-048 polish: seed the first store from the approved MERCHANT
      // application (shop name/address typed at registration) instead of the
      // generic fallback name.
      const app = await tx.partnerApplication.findFirst({
        where: { userId: ownerId, role: 'MERCHANT', status: 'APPROVED' },
        orderBy: { reviewedAt: 'desc' },
        select: { metadata: true },
      });
      const meta = (app?.metadata ?? {}) as Record<string, unknown>;
      const shopName =
        typeof meta.shopName === 'string' && meta.shopName.trim()
          ? meta.shopName.trim().slice(0, 120)
          : name;
      const shopAddress =
        typeof meta.shopAddress === 'string' && meta.shopAddress.trim()
          ? meta.shopAddress.trim().slice(0, 200)
          : undefined;
      // DEC-PROD-067: category picked at registration, if still offered.
      const shopCategory =
        typeof meta.shopCategory === 'string'
          ? await tx.foodCategory.findFirst({
              where: { code: meta.shopCategory, active: true },
              select: { code: true },
            })
          : null;
      return tx.foodStore.create({
        data: {
          ownerId,
          name: shopName,
          addressLabel: shopAddress,
          category: shopCategory?.code,
        },
        include: storeDetailInclude,
      });
    });
    return toStoreDetail(created);
  }

  async updateStoreSchedule(
    input: UpdateStoreScheduleInput,
  ): Promise<StoreDetail> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const { schedule } = input;
    const updated = await this.db.$transaction(async (tx) => {
      await tx.foodStoreHour.deleteMany({ where: { storeId: store.id } });
      await tx.foodStoreClosure.deleteMany({ where: { storeId: store.id } });
      if (schedule.hours.length > 0) {
        await tx.foodStoreHour.createMany({
          data: schedule.hours.map((row) => ({ storeId: store.id, ...row })),
        });
      }
      if (schedule.closures.length > 0) {
        await tx.foodStoreClosure.createMany({
          data: schedule.closures.map((row) => ({
            storeId: store.id,
            date: new Date(`${row.date}T00:00:00.000Z`),
            note: row.note,
          })),
        });
      }
      return tx.foodStore.update({
        where: { id: store.id },
        data: {
          hoursConfigured: schedule.hoursConfigured,
          lastOrderMinutes: schedule.lastOrderMinutes,
        },
        include: storeDetailInclude,
      });
    });
    return toStoreDetail(updated);
  }

  async updateStoreAcceptSettings(
    input: UpdateStoreAcceptSettingsInput,
  ): Promise<StoreDetail> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const updated = await this.db.foodStore.update({
      where: { id: store.id },
      data: {
        acceptMode: input.acceptMode,
        maxActiveOrders: input.maxActiveOrders,
        defaultPrepMinutes: input.defaultPrepMinutes,
        lastOrderMinutes: input.lastOrderMinutes,
      },
      include: storeDetailInclude,
    });
    return toStoreDetail(updated);
  }

  async updateStoreServiceMode(
    input: UpdateStoreServiceModeInput,
  ): Promise<StoreDetail> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const updated = await this.db.foodStore.update({
      where: { id: store.id },
      data: {
        serviceMode: input.mode,
        serviceModeUntil: input.until,
        ...(input.busyExtraMinutes !== undefined
          ? { busyExtraMinutes: input.busyExtraMinutes }
          : {}),
      },
      include: storeDetailInclude,
    });
    return toStoreDetail(updated);
  }

  async updateStoreProfile(
    input: UpdateStoreProfileInput,
  ): Promise<StoreDetail> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const updated = await this.db.foodStore.update({
      where: { id: store.id },
      data: {
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.logoUrl !== undefined ? { logoUrl: input.logoUrl } : {}),
        ...(input.coverUrl !== undefined ? { coverUrl: input.coverUrl } : {}),
        ...(input.description !== undefined
          ? { description: input.description }
          : {}),
        ...(input.category !== undefined ? { category: input.category } : {}),
        ...(input.minOrderVnd !== undefined
          ? { minOrderVnd: input.minOrderVnd }
          : {}),
      },
      include: storeDetailInclude,
    });
    return toStoreDetail(updated);
  }

  async findStoreLogoUrl(storeId: string): Promise<string | null> {
    const row = await this.db.foodStore.findUnique({
      where: { id: storeId },
      select: { logoUrl: true },
    });
    return row?.logoUrl ?? null;
  }

  async findStoreCoverUrl(storeId: string): Promise<string | null> {
    const row = await this.db.foodStore.findUnique({
      where: { id: storeId },
      select: { coverUrl: true },
    });
    return row?.coverUrl ?? null;
  }

  async updateStoreLocation(
    input: UpdateStoreLocationInput,
  ): Promise<StoreDetail> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const updated = await this.db.foodStore.update({
      where: { id: store.id },
      data: {
        lat: input.lat,
        lng: input.lng,
        ...(input.addressLabel !== undefined
          ? { addressLabel: input.addressLabel?.trim() || null }
          : {}),
        serviceRegionCode: resolveServiceRegionCode({
          lat: input.lat,
          lng: input.lng,
          label: store.name,
        }),
      },
      include: storeDetailInclude,
    });
    return toStoreDetail(updated);
  }

  async createItem(input: CreateCatalogItemInput): Promise<StoreItemView> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const available = input.available ?? true;
    const item = await this.db.foodItem.create({
      data: {
        storeId: store.id,
        name: input.name,
        priceVnd: input.priceVnd,
        originalPriceVnd: shownOriginalPrice(
          input.priceVnd,
          input.originalPriceVnd,
        ),
        available,
        moderationStatus: input.moderationStatus ?? 'PENDING',
        description: input.description ?? null,
        prepMinutes: input.prepMinutes ?? null,
        imageUrl: input.imageUrl ?? null,
        menuCategoryId: input.menuCategoryId ?? null,
      },
      include: itemOptionsInclude,
    });
    return prismaItemView(item);
  }

  async updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView> {
    const item = await this.requireOwnedItem(input.ownerId, input.itemId);
    const current = await this.db.foodItem.findUniqueOrThrow({
      where: { id: item.id },
      select: { priceVnd: true, originalPriceVnd: true },
    });
    const nextPrice = input.priceVnd ?? current.priceVnd;
    const nextOriginal = shownOriginalPrice(
      nextPrice,
      input.originalPriceVnd !== undefined
        ? input.originalPriceVnd
        : current.originalPriceVnd,
    );
    const updated = await this.db.foodItem.update({
      where: { id: item.id },
      data: {
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.priceVnd !== undefined ? { priceVnd: input.priceVnd } : {}),
        ...(nextOriginal !== current.originalPriceVnd
          ? { originalPriceVnd: nextOriginal }
          : {}),
        ...(input.available !== undefined
          ? { available: input.available }
          : {}),
        ...(input.description !== undefined
          ? { description: input.description }
          : {}),
        ...(input.prepMinutes !== undefined
          ? { prepMinutes: input.prepMinutes }
          : {}),
        ...(input.imageUrl !== undefined ? { imageUrl: input.imageUrl } : {}),
        ...(input.imageUrls !== undefined
          ? { imageUrls: input.imageUrls, imageUrl: input.imageUrls[0] ?? null }
          : input.imageUrl !== undefined
            ? { imageUrls: input.imageUrl ? [input.imageUrl] : [] }
            : {}),
        ...(input.menuCategoryId !== undefined
          ? { menuCategoryId: input.menuCategoryId }
          : {}),
      },
      include: itemOptionsInclude,
    });
    return prismaItemView(updated);
  }

  async findItemImageUrls(itemId: string): Promise<string[]> {
    const row = await this.db.foodItem.findUnique({
      where: { id: itemId },
      select: { imageUrl: true, imageUrls: true },
    });
    if (!row) return [];
    const rawUrls = row.imageUrls as unknown;
    const fromJson = Array.isArray(rawUrls)
      ? rawUrls.filter(
          (u): u is string => typeof u === 'string' && u.length > 0,
        )
      : [];
    if (fromJson.length) return fromJson;
    return row.imageUrl ? [row.imageUrl] : [];
  }

  async findItemImageUrl(itemId: string): Promise<string | null> {
    const row = await this.db.foodItem.findUnique({
      where: { id: itemId },
      select: { imageUrl: true },
    });
    return row?.imageUrl ?? null;
  }

  async listFeaturedItems(
    storeIds: string[],
  ): Promise<Map<string, StoreFeaturedItem[]>> {
    const unique = [...new Set(storeIds)];
    const byStore = new Map<string, StoreFeaturedItem[]>();
    if (unique.length === 0) return byStore;
    const rows = await this.db.foodItem.findMany({
      where: {
        storeId: { in: unique },
        available: true,
        moderationStatus: 'APPROVED',
      },
      select: {
        id: true,
        storeId: true,
        name: true,
        priceVnd: true,
        originalPriceVnd: true,
        imageUrl: true,
        soldCount: true,
        createdAt: true,
      },
    });
    const grouped = new Map<string, StoreFeaturedItem[]>();
    for (const row of rows) {
      const list = grouped.get(row.storeId) ?? [];
      list.push({
        id: row.id,
        name: row.name,
        priceVnd: row.priceVnd,
        originalPriceVnd: shownOriginalPrice(
          row.priceVnd,
          row.originalPriceVnd,
        ),
        imageUrl: row.imageUrl,
        soldCount: row.soldCount,
        addedAt: row.createdAt.toISOString(),
      });
      grouped.set(row.storeId, list);
    }
    for (const [storeId, list] of grouped) {
      byStore.set(storeId, pickFeaturedItems(list));
    }
    return byStore;
  }

  async listItemSuggestions(
    query: ItemSuggestionsQuery,
  ): Promise<StoreItemSuggestion[]> {
    const store = await this.db.foodStore.findUnique({
      where: { id: query.storeId },
      select: {
        serviceMode: true,
        serviceModeUntil: true,
        hoursConfigured: true,
        lastOrderMinutes: true,
        hours: true,
        closures: true,
      },
    });
    if (!store) {
      return [];
    }
    const availability = storeAvailability(
      store.serviceMode,
      store.serviceModeUntil,
      scheduleFromRow(store),
      new Date(),
    );
    if (!availability.openNow) {
      return [];
    }

    const excludedCategories = query.exclude.length
      ? (
          await this.db.foodItem.findMany({
            where: { storeId: query.storeId, id: { in: query.exclude } },
            select: { menuCategoryId: true },
          })
        )
          .map((row) => row.menuCategoryId)
          .filter((categoryId): categoryId is string => categoryId !== null)
      : [];

    const rows = await this.db.foodItem.findMany({
      where: {
        storeId: query.storeId,
        ...(query.exclude.length ? { id: { notIn: query.exclude } } : {}),
        available: true,
        ...(query.moderationRequired ? { moderationStatus: 'APPROVED' } : {}),
        menuCategoryId: excludedCategories.length
          ? { not: null, notIn: excludedCategories }
          : { not: null },
      },
      orderBy: [{ soldCount: 'desc' }, { createdAt: 'desc' }, { id: 'asc' }],
      take: query.limit,
      select: {
        id: true,
        name: true,
        priceVnd: true,
        originalPriceVnd: true,
        imageUrl: true,
        soldCount: true,
        createdAt: true,
        available: true,
        menuCategoryId: true,
      },
    });
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      priceVnd: row.priceVnd,
      originalPriceVnd: shownOriginalPrice(
        row.priceVnd,
        row.originalPriceVnd,
      ),
      imageUrl: row.imageUrl,
      soldCount: row.soldCount,
      addedAt: row.createdAt.toISOString(),
      available: row.available,
      menuCategoryId: row.menuCategoryId,
    }));
  }

  async listStoreMenuSections(
    storeId: string,
    approvedOnly = true,
  ): Promise<import('./food.repository.js').StoreMenuSection[]> {
    return this.db.foodMenuCategory.findMany({
      where: {
        storeId,
        items: {
          some: approvedOnly ? { moderationStatus: 'APPROVED' } : {},
        },
      },
      orderBy: [{ position: 'asc' }, { name: 'asc' }],
      select: { id: true, name: true },
    });
  }

  async listMenuCategories(
    ownerId: string,
  ): Promise<import('./food.repository.js').MenuCategoryView[]> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) return [];
    const rows = await this.db.foodMenuCategory.findMany({
      where: { storeId: store.id },
      orderBy: [{ position: 'asc' }, { name: 'asc' }],
      include: { _count: { select: { items: true } } },
    });
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      description: row.description,
      position: row.position,
      itemCount: row._count.items,
    }));
  }

  async createMenuCategory(input: {
    ownerId: string;
    name: string;
    description?: string | null;
  }): Promise<import('./food.repository.js').MenuCategoryView> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: input.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const max = await this.db.foodMenuCategory.aggregate({
      where: { storeId: store.id },
      _max: { position: true },
    });
    const row = await this.db.foodMenuCategory.create({
      data: {
        storeId: store.id,
        name: input.name.trim(),
        description: input.description?.trim() || null,
        position: (max._max.position ?? -1) + 1,
      },
    });
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      position: row.position,
      itemCount: 0,
    };
  }

  async updateMenuCategory(input: {
    ownerId: string;
    categoryId: string;
    name?: string;
    description?: string | null;
  }): Promise<import('./food.repository.js').MenuCategoryView> {
    const owned = await this.db.foodMenuCategory.findFirst({
      where: { id: input.categoryId, store: { ownerId: input.ownerId } },
      include: { _count: { select: { items: true } } },
    });
    if (!owned) throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    const row = await this.db.foodMenuCategory.update({
      where: { id: owned.id },
      data: {
        ...(input.name !== undefined ? { name: input.name.trim() } : {}),
        ...(input.description !== undefined
          ? { description: input.description?.trim() || null }
          : {}),
      },
      include: { _count: { select: { items: true } } },
    });
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      position: row.position,
      itemCount: row._count.items,
    };
  }

  async deleteMenuCategory(
    ownerId: string,
    categoryId: string,
  ): Promise<{ deleted: true }> {
    const owned = await this.db.foodMenuCategory.findFirst({
      where: { id: categoryId, store: { ownerId } },
      select: { id: true },
    });
    if (!owned) throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    await this.db.foodMenuCategory.delete({ where: { id: owned.id } });
    return { deleted: true };
  }

  async reorderMenuCategories(
    ownerId: string,
    orderedIds: string[],
  ): Promise<import('./food.repository.js').MenuCategoryView[]> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const existing = await this.db.foodMenuCategory.findMany({
      where: { storeId: store.id },
    });
    const idSet = new Set(existing.map((r) => r.id));
    if (
      orderedIds.length !== existing.length ||
      orderedIds.some((id) => !idSet.has(id))
    ) {
      throw new FoodRuleError('FOOD_CATEGORY_REORDER_INVALID');
    }
    await this.db.$transaction(
      orderedIds.map((id, position) =>
        this.db.foodMenuCategory.update({ where: { id }, data: { position } }),
      ),
    );
    return this.listMenuCategories(ownerId);
  }

  async listMerchantHistory(
    filter: import('./food.repository.js').MerchantHistoryFilter,
  ) {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId: filter.ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) {
      return {
        items: [],
        page: filter.page,
        limit: filter.limit,
        total: 0,
        deliveredCount: 0,
        deliveredRevenueVnd: 0,
      };
    }
    const tab = (filter.tab ?? 'ALL').toUpperCase();
    const statusFilter =
      tab === 'DELIVERED'
        ? ['DELIVERED']
        : tab === 'CANCELLED'
          ? ['CANCELLED']
          : tab === 'FAILED'
            ? ['FAILED']
            : ['DELIVERED', 'CANCELLED', 'FAILED'];
    const where: Record<string, unknown> = {
      storeId: store.id,
      status: { in: statusFilter },
      ...(filter.from || filter.to
        ? {
            updatedAt: {
              ...(filter.from ? { gte: filter.from } : {}),
              ...(filter.to ? { lte: filter.to } : {}),
            },
          }
        : {}),
    };
    const q = filter.q?.trim();
    if (q) {
      where.OR = [
        { id: { contains: q, mode: 'insensitive' } },
        { customer: { displayName: { contains: q, mode: 'insensitive' } } },
        { lines: { some: { name: { contains: q, mode: 'insensitive' } } } },
      ];
    }
    const [total, rows, deliveredAgg] = await Promise.all([
      this.db.foodOrder.count({ where: where as never }),
      this.db.foodOrder.findMany({
        where: where as never,
        orderBy: { updatedAt: 'desc' },
        skip: (filter.page - 1) * filter.limit,
        take: filter.limit,
        include: {
          customer: { select: { displayName: true } },
          lines: {
            select: { name: true, quantity: true },
            orderBy: { name: 'asc' },
            take: 4,
          },
        },
      }),
      this.db.foodOrder.aggregate({
        where: {
          storeId: store.id,
          status: 'DELIVERED',
          ...(filter.from || filter.to
            ? {
                updatedAt: {
                  ...(filter.from ? { gte: filter.from } : {}),
                  ...(filter.to ? { lte: filter.to } : {}),
                },
              }
            : {}),
        },
        _count: true,
        _sum: { subtotalVnd: true },
      }),
    ]);
    return {
      items: rows.map((row) => ({
        id: row.id,
        status: row.status,
        subtotalVnd: row.subtotalVnd,
        totalVnd: row.totalVnd,
        createdAt: row.createdAt,
        finishedAt: row.updatedAt,
        customerName: row.customer.displayName || null,
        lineSummary: row.lines
          .map((l) => (l.quantity > 1 ? `${l.quantity} x ${l.name}` : l.name))
          .join(' · '),
      })),
      page: filter.page,
      limit: filter.limit,
      total,
      deliveredCount: deliveredAgg._count,
      deliveredRevenueVnd: deliveredAgg._sum.subtotalVnd ?? 0,
    };
  }

  async replaceItemOptions(
    input: ReplaceItemOptionsInput,
  ): Promise<StoreItemView> {
    await this.requireOwnedItem(input.ownerId, input.itemId);
    return this.db.$transaction(async (tx) => {
      // Lock the item so two editors cannot interleave delete/create.
      await tx.$queryRaw`SELECT 1 FROM "food_items" WHERE "id" = ${input.itemId}::uuid FOR UPDATE`;
      const current = await tx.foodItem.findUniqueOrThrow({
        where: { id: input.itemId },
        include: itemOptionsInclude,
      });
      const groups = normalizeOptionGroups(
        input.groups,
        prismaItemView(current).optionGroups,
        randomUUID,
      );
      await tx.foodOptionGroup.deleteMany({ where: { itemId: input.itemId } });
      for (const [position, group] of groups.entries()) {
        await tx.foodOptionGroup.create({
          data: {
            id: group.id,
            itemId: input.itemId,
            name: group.name,
            minSelect: group.minSelect,
            maxSelect: group.maxSelect,
            position,
            options: {
              create: group.options.map((option, optionPosition) => ({
                id: option.id,
                name: option.name,
                priceDeltaVnd: option.priceDeltaVnd,
                available: option.available,
                maxQuantity: option.maxQuantity,
                position: optionPosition,
              })),
            },
          },
        });
      }
      const updated = await tx.foodItem.findUniqueOrThrow({
        where: { id: input.itemId },
        include: itemOptionsInclude,
      });
      return prismaItemView(updated);
    });
  }

  async setItemAvailability(
    input: SetItemAvailabilityInput,
  ): Promise<StoreItemView> {
    const item = await this.requireOwnedItem(input.ownerId, input.itemId);
    // FOOD-001: availability never changes moderation; only APPROVED items can go on sale.
    // Conditional write so a concurrent admin reject cannot be raced back on sale.
    const { count } = await this.db.foodItem.updateMany({
      where: {
        id: item.id,
        ...(input.available ? { moderationStatus: 'APPROVED' as const } : {}),
      },
      data: { available: input.available },
    });
    if (count === 0) {
      throw new FoodRuleError('FOOD_ITEM_NOT_APPROVED');
    }
    const updated = await this.db.foodItem.findUniqueOrThrow({
      where: { id: item.id },
      include: itemOptionsInclude,
    });
    return prismaItemView(updated);
  }

  async setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{
    id: string;
    available: boolean;
    moderationStatus: string;
  } | null> {
    const existing = await this.db.foodItem.findUnique({
      where: { id: itemId },
    });
    if (!existing) {
      return null;
    }
    const updated = await this.db.foodItem.update({
      where: { id: itemId },
      data: {
        moderationStatus: decision,
        available: decision === 'APPROVED',
      },
    });
    return {
      id: updated.id,
      available: updated.available,
      moderationStatus: updated.moderationStatus,
    };
  }

  async listOrdersPage(
    page: number,
    limit: number,
    filter?: {
      status?: string;
      statuses?: string[];
      q?: string;
      store?: string;
      payment?: string;
      zone?: string;
      window?: OpsDateWindow;
    },
  ): Promise<OpsFoodOrderPage> {
    const and: Prisma.FoodOrderWhereInput[] = [];
    if (filter?.statuses && filter.statuses.length > 0) {
      const statuses = filter.statuses
        .map((s) => s.trim().toUpperCase())
        .filter(Boolean) as FoodOrderView['status'][];
      if (statuses.length > 0) {
        and.push({ status: { in: statuses } });
      }
    } else if (filter?.status && filter.status !== 'ALL') {
      and.push({
        status: filter.status.toUpperCase() as FoodOrderView['status'],
      });
    }
    if (filter?.store && filter.store !== 'ALL') {
      const store = filter.store.trim();
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          store,
        );
      if (isUuid) {
        and.push({ storeId: store });
      } else {
        and.push({ store: { name: { contains: store, mode: 'insensitive' } } });
      }
    }
    if (filter?.zone && filter.zone !== 'ALL') {
      const code = normalizeRegionFilter(filter.zone);
      if (code) {
        and.push(
          regionCodeOrLabelFallbackWhere(code, [
            'dropoffLabel',
          ]) as Prisma.FoodOrderWhereInput,
        );
      }
    }
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim();
      const isUuid =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
          q,
        );
      const orConditions: Prisma.FoodOrderWhereInput[] = [
        { dropoffLabel: { contains: q, mode: 'insensitive' } },
        { store: { name: { contains: q, mode: 'insensitive' } } },
        { customer: { displayName: { contains: q, mode: 'insensitive' } } },
        { customer: { phone: { contains: q, mode: 'insensitive' } } },
      ];
      if (isUuid) {
        orConditions.push({ id: q }, { customerId: q });
      }
      and.push({ OR: orConditions });
    }
    if (filter?.payment && filter.payment !== 'ALL') {
      const orderIds = await this.foodOrderIdsForPaymentFilter(filter.payment);
      and.push({ id: { in: orderIds } });
    }
    const createdAt = prismaDateFilter(filter?.window);
    if (createdAt) {
      and.push({ createdAt });
    }
    const where: Prisma.FoodOrderWhereInput =
      and.length > 0 ? { AND: and } : {};
    const [total, rows] = await Promise.all([
      this.db.foodOrder.count({ where }),
      this.db.foodOrder.findMany({
        where,
        include: orderInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      items: rows.map(toView),
      total,
    };
  }

  private async foodOrderIdsForPaymentFilter(
    payment: string,
  ): Promise<string[]> {
    const { dbMethods } = paymentFilterMatchers(payment);
    if (dbMethods.length === 0) {
      return [];
    }
    const intents = await this.db.paymentIntent.findMany({
      where: {
        entityType: 'FOOD_ORDER',
        method: { in: dbMethods },
      },
      select: { entityId: true },
    });
    return intents.map((row) => row.entityId);
  }

  async listOrdersForCustomer(
    customerId: string,
    page: number,
    limit: number,
  ): Promise<OpsFoodOrderPage> {
    const where = { customerId };
    const [total, rows] = await Promise.all([
      this.db.foodOrder.count({ where }),
      this.db.foodOrder.findMany({
        where,
        include: orderInclude,
        orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
    return {
      items: rows.map(toView),
      total,
    };
  }

  async countFinishedForDrivers(
    driverIds: readonly string[],
  ): Promise<Map<string, DriverJobCounts>> {
    const counts = new Map<string, DriverJobCounts>();
    if (driverIds.length === 0) {
      return counts;
    }
    const rows = await this.db.foodOrder.groupBy({
      by: ['assignedDriverId', 'status', 'cancelledBy'],
      where: {
        assignedDriverId: { in: [...driverIds] },
        status: { in: [...DRIVER_HISTORY_FOOD_STATUSES] },
      },
      _count: { _all: true },
    });
    for (const row of rows) {
      if (!row.assignedDriverId) continue;
      // DEC-PROD-035: only driver cancellations count against the driver.
      if (!cancellationCountsAgainstDriver(row.status, row.cancelledBy))
        continue;
      const current = counts.get(row.assignedDriverId) ?? {
        completed: 0,
        finished: 0,
      };
      current.finished += row._count._all;
      if (row.status === 'DELIVERED') {
        current.completed += row._count._all;
      }
      counts.set(row.assignedDriverId, current);
    }
    return counts;
  }

  async listIdsForDriverInStatuses(
    driverId: string,
    statuses: readonly string[],
  ): Promise<string[]> {
    const rows = await this.db.foodOrder.findMany({
      where: {
        assignedDriverId: driverId,
        status: { in: [...statuses] as never },
      },
      select: { id: true },
    });
    return rows.map((row) => row.id);
  }

  async listIdsForCustomerInStatuses(
    customerId: string,
    statuses: readonly string[],
  ): Promise<string[]> {
    const rows = await this.db.foodOrder.findMany({
      where: { customerId, status: { in: [...statuses] as never } },
      orderBy: { createdAt: 'desc' },
      take: 1,
      select: { id: true },
    });
    return rows.map((row) => row.id);
  }

  async listFinishedForDriver(
    driverId: string,
    window: FoodDriverHistoryWindow,
  ): Promise<FoodOrderView[]> {
    const rows = await this.db.foodOrder.findMany({
      where: {
        assignedDriverId: driverId,
        status: { in: [...DRIVER_HISTORY_FOOD_STATUSES] },
        updatedAt: {
          ...(window.before ? { lte: window.before } : {}),
          ...(window.since ? { gte: window.since } : {}),
        },
      },
      include: orderInclude,
      orderBy: [{ updatedAt: 'desc' }, { id: 'desc' }],
      take: window.limit,
    });
    return rows.map(toView);
  }

  async place(input: PlaceFoodInput): Promise<FoodOrderView> {
    try {
      return await this.db.$transaction(async (tx) => {
        const replay = await tx.foodOrder.findUnique({
          where: {
            customerId_idempotencyKey: {
              customerId: input.customerId,
              idempotencyKey: input.idempotencyKey,
            },
          },
          include: orderInclude,
        });
        if (replay) {
          return toView(replay);
        }
        const open = await tx.foodOrder.findFirst({
          where: {
            customerId: input.customerId,
            status: { in: [...OPEN_STATUSES] },
          },
          select: { id: true },
        });
        if (open) {
          throw new FoodRuleError('FOOD_ORDER_ALREADY_OPEN');
        }
        const store = await tx.foodStore.findUnique({
          where: { id: input.storeId },
          include: {
            items: { include: itemOptionsInclude },
            hours: true,
            closures: true,
          },
        });
        if (!store) {
          throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
        }
        const availability = storeAvailability(
          store.serviceMode,
          store.serviceModeUntil,
          scheduleFromRow(store),
        );
        if (availability.closedReason === 'PAUSED') {
          throw new FoodRuleError('FOOD_STORE_PAUSED');
        }
        if (availability.closedReason === 'CLOSED') {
          throw new FoodRuleError('FOOD_STORE_CLOSED');
        }
        const { acceptSettings, estimatedPrepMinutes } = acceptFromRow(store);
        if (acceptSettings.maxActiveOrders !== null) {
          // DEC-PROD-028: serialize placements per capped store so two checkouts cannot both see
          // "one slot left"; the count below runs after the lock is held.
          await tx.$queryRaw`SELECT 1 FROM "food_stores" WHERE "id" = ${store.id}::uuid FOR UPDATE`;
          const active = await tx.foodOrder.count({
            where: {
              storeId: store.id,
              status: { in: [...KITCHEN_ACTIVE_STATUSES] },
            },
          });
          if (atCapacity(acceptSettings, active)) {
            throw new FoodRuleError('FOOD_STORE_AT_CAPACITY');
          }
        }
        const lines = snapshotFoodLines(
          store.items.map((row) => ({
            ...prismaItemView(row),
            moderationStatus: row.moderationStatus,
          })),
          input.items,
          input.requireApprovedItems ?? true,
        );
        const subtotalVnd = lines.reduce(
          (sum, line) => sum + line.unitPriceVnd * line.quantity,
          0,
        );
        if (subtotalVnd < store.minOrderVnd) {
          throw new FoodRuleError('FOOD_MIN_ORDER_NOT_MET');
        }
        const orderId = randomUUID();
        const voucher = input.voucherCode
          ? await redeemVoucherInTx(tx, {
              code: input.voucherCode,
              userId: input.customerId,
              serviceType: 'FOOD',
              orderAmount: subtotalVnd,
              deliveryFee: input.deliveryFareVnd,
              storeId: store.id,
              entityType: 'FOOD_ORDER',
              entityId: orderId,
            })
          : null;
        const discountVnd = voucher?.discountVnd ?? 0;
        const created = await tx.foodOrder.create({
          data: {
            id: orderId,
            customerId: input.customerId,
            storeId: store.id,
            status: placementStatus(acceptSettings),
            prepMinutes: estimatedPrepMinutes,
            deliveryFareVnd: input.deliveryFareVnd,
            suggestedDeliveryFareVnd:
              input.suggestedDeliveryFareVnd ?? input.deliveryFareVnd,
            subtotalVnd,
            discountVnd,
            voucherCode: voucher?.code ?? null,
            voucherSponsor: voucher?.sponsor ?? null,
            totalVnd: Math.max(
              0,
              subtotalVnd + input.deliveryFareVnd - discountVnd,
            ),
            dropoffLat: input.dropoff.lat,
            dropoffLng: input.dropoff.lng,
            dropoffLabel: input.dropoff.label,
            // DEC-PROD-034: the driver navigates to where the store was when the order was placed.
            pickupLat:
              store.lat != null && store.lng != null ? store.lat : null,
            pickupLng:
              store.lat != null && store.lng != null ? store.lng : null,
            pickupLabel:
              store.lat != null && store.lng != null
                ? (store.addressLabel ?? null)
                : null,
            serviceRegionCode: resolveServiceRegionCode({
              lat: input.dropoff.lat,
              lng: input.dropoff.lng,
              label: input.dropoff.label,
              fallback: store.serviceRegionCode,
            }),
            note: input.note ?? null,
            utensils: input.utensils ?? true,
            idempotencyKey: input.idempotencyKey,
            lines: {
              create: lines.map((line) => ({
                id: line.id,
                itemId: line.itemId,
                name: line.name,
                unitPriceVnd: line.unitPriceVnd,
                quantity: line.quantity,
                imageUrl: line.imageUrl,
                note: line.note,
                options: line.options as Prisma.InputJsonValue,
              })),
            },
          },
          include: orderInclude,
        });
        await this.writeFoodStatusOutbox(tx, created.id, created.status, {
          storeId: created.storeId,
        });
        return toView(created);
      });
    } catch (error) {
      const ruleError =
        error instanceof FoodRuleError || error instanceof VoucherRejectedError;
      if (!ruleError && !isUniqueConflict(error)) {
        throw error;
      }
      // Idempotency wins: a concurrent request with the same key may have committed while this
      // one waited on the voucher row or the open-order check, so its rule error (already open,
      // voucher used up) is really a replay. Fixes the food-voucher race flake.
      const replay = await this.db.foodOrder.findUnique({
        where: {
          customerId_idempotencyKey: {
            customerId: input.customerId,
            idempotencyKey: input.idempotencyKey,
          },
        },
        include: orderInclude,
      });
      if (replay) {
        return toView(replay);
      }
      if (ruleError) {
        throw error;
      }
      throw new FoodRuleError('FOOD_ORDER_ALREADY_OPEN');
    }
  }

  async findOrder(orderId: string): Promise<FoodOrderView | null> {
    const order = await this.db.foodOrder.findUnique({
      where: { id: orderId },
      include: orderInclude,
    });
    return order ? toView(order) : null;
  }

  async listReady(
    limit?: number,
    near?: ReadyNearFilter,
    early?: FoodEarlyClaim,
  ): Promise<ReadyOrderSummary[]> {
    const take =
      limit !== undefined && Number.isSafeInteger(limit) && limit > 0
        ? limit
        : undefined;
    // Bounding-box prefilter in SQL; the service still applies the exact haversine radius.
    let box: Prisma.FoodOrderWhereInput = {};
    if (near) {
      const dLat = near.radiusKm / 111.32;
      const dLng =
        near.radiusKm /
        (111.32 * Math.max(Math.cos((near.lat * Math.PI) / 180), 0.01));
      const lat = { gte: near.lat - dLat, lte: near.lat + dLat };
      const lng = { gte: near.lng - dLng, lte: near.lng + dLng };
      box = {
        OR: [
          { pickupLat: lat, pickupLng: lng },
          { pickupLat: null, store: { lat, lng } },
          {
            pickupLat: null,
            store: { lat: null },
            dropoffLat: lat,
            dropoffLng: lng,
          },
        ],
      };
    }
    // PREPARING rows are prefiltered in SQL (prep set) and checked exactly below.
    const orders = await this.db.foodOrder.findMany({
      where: {
        assignedDriverId: null,
        ...(early
          ? {
              OR: [
                { status: 'READY' },
                { status: 'PREPARING', prepMinutes: { not: null } },
              ],
            }
          : { status: 'READY' }),
        ...(near ? { AND: [box] } : {}),
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      ...(take !== undefined ? { take } : {}),
      select: {
        id: true,
        storeId: true,
        status: true,
        prepMinutes: true,
        createdAt: true,
        acceptedAt: true,
        deliveryFareVnd: true,
        subtotalVnd: true,
        totalVnd: true,
        dropoffLat: true,
        dropoffLng: true,
        dropoffLabel: true,
        pickupLat: true,
        pickupLng: true,
        pickupLabel: true,
        store: {
          select: { lat: true, lng: true, name: true, addressLabel: true },
        },
        _count: { select: { lines: true } },
      },
    });
    const claimable = orders.filter((order) => {
      if (order.status === 'READY') return true;
      const opensAt = early
        ? earlyClaimOpensAt(order, early.leadMinutes)
        : null;
      return !!early && !!opensAt && opensAt.getTime() <= early.now.getTime();
    });
    return claimable.map((order) => {
      const pickup = orderPickup(order);
      return {
        id: order.id,
        storeId: order.storeId,
        status:
          order.status === 'PREPARING'
            ? ('PREPARING' as const)
            : ('READY' as const),
        estimatedReadyAt: estimatedReadyAt(
          order.acceptedAt ?? order.createdAt,
          order.prepMinutes ?? null,
        ),
        storeName: order.store.name,
        storeAddress: order.store.addressLabel,
        deliveryFareVnd: order.deliveryFareVnd,
        subtotalVnd: order.subtotalVnd,
        totalVnd: order.totalVnd,
        dropoff: {
          lat: order.dropoffLat,
          lng: order.dropoffLng,
          label: order.dropoffLabel,
        },
        store: pickup ? { lat: pickup.lat, lng: pickup.lng } : null,
        pickup,
        lineCount: order._count.lines,
      };
    });
  }

  async listQueue(ownerId: string): Promise<QueueOrderSummary[]> {
    const orders = await this.db.foodOrder.findMany({
      where: {
        status: { in: [...OPEN_STATUSES] },
        store: { ownerId },
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      select: {
        id: true,
        storeId: true,
        status: true,
        deliveryFareVnd: true,
        subtotalVnd: true,
        totalVnd: true,
        dropoffLat: true,
        dropoffLng: true,
        dropoffLabel: true,
        createdAt: true,
        customerId: true,
        assignedDriverId: true,
        _count: { select: { lines: true } },
        lines: { select: { quantity: true } },
      },
    });
    return orders.flatMap((order) => {
      if (!isOpenStatus(order.status)) {
        return [];
      }
      return [
        {
          id: order.id,
          storeId: order.storeId,
          status: order.status,
          deliveryFareVnd: order.deliveryFareVnd,
          subtotalVnd: order.subtotalVnd,
          totalVnd: order.totalVnd,
          dropoff: {
            lat: order.dropoffLat,
            lng: order.dropoffLng,
            label: order.dropoffLabel,
          },
          lineCount: order._count.lines,
          itemCount: order.lines.reduce((sum, line) => sum + line.quantity, 0),
          createdAt: order.createdAt,
          customerId: order.customerId,
          assignedDriverId: order.assignedDriverId,
        },
      ];
    });
  }

  async merchantStats(
    ownerId: string,
    since: Date,
    topLimit: number,
  ): Promise<MerchantStatsRows> {
    const [finished, openCount, top] = await Promise.all([
      this.db.foodOrder.findMany({
        where: {
          store: { ownerId },
          status: { in: ['DELIVERED', 'CANCELLED', 'FAILED'] },
          updatedAt: { gte: since },
        },
        select: { status: true, subtotalVnd: true, updatedAt: true },
      }),
      this.db.foodOrder.count({
        where: { store: { ownerId }, status: { in: [...OPEN_STATUSES] } },
      }),
      this.db.foodOrderLine.groupBy({
        by: ['name'],
        where: {
          order: {
            store: { ownerId },
            status: 'DELIVERED',
            updatedAt: { gte: since },
          },
        },
        _sum: { quantity: true },
        orderBy: [{ _sum: { quantity: 'desc' } }, { name: 'asc' }],
        take: topLimit,
      }),
    ]);
    return {
      finished: finished.map((row) => ({
        status: row.status as 'DELIVERED' | 'CANCELLED' | 'FAILED',
        subtotalVnd: row.subtotalVnd,
        finishedAt: row.updatedAt,
      })),
      openCount,
      topItems: top.map((row) => ({
        name: row.name,
        quantity: row._sum.quantity ?? 0,
      })),
    };
  }

  async deliveredForStatement(
    storeId: string,
    from: Date,
    to: Date,
  ): Promise<MerchantStatementRow[]> {
    const rows = await this.db.foodOrder.findMany({
      where: { storeId, status: 'DELIVERED', updatedAt: { gte: from, lt: to } },
      orderBy: { updatedAt: 'asc' },
      select: {
        id: true,
        updatedAt: true,
        subtotalVnd: true,
        discountVnd: true,
        voucherSponsor: true,
        merchantCashVnd: true,
        merchantCommissionVnd: true,
      },
    });
    return rows.map((row) => ({
      orderId: row.id,
      deliveredAt: row.updatedAt,
      subtotalVnd: row.subtotalVnd,
      discountVnd: row.discountVnd,
      voucherSponsor: (row.voucherSponsor ??
        null) as MerchantStatementRow['voucherSponsor'],
      merchantCashVnd: row.merchantCashVnd ?? null,
      commissionVnd: row.merchantCommissionVnd ?? null,
    }));
  }

  async listMerchantSettlements(
    storeId: string,
    limit: number,
  ): Promise<MerchantSettlementView[]> {
    const rows = await this.db.merchantSettlement.findMany({
      where: { storeId },
      orderBy: { periodEnd: 'desc' },
      take: limit,
    });
    return rows.map(toSettlementView);
  }

  async recordMerchantSettlement(
    input: RecordMerchantSettlementInput,
  ): Promise<MerchantSettlementView> {
    return this.db.$transaction(async (tx) => {
      // Serialise per store so two Ops clicks cannot record overlapping periods.
      const locked = await tx.$queryRaw<Array<{ id: string }>>`
        SELECT id FROM food_stores WHERE id = ${input.storeId}::uuid FOR UPDATE`;
      if (locked.length === 0) {
        throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
      }
      const periodStart = dayDate(input.periodStart);
      const periodEnd = dayDate(input.periodEnd);
      const overlap = await tx.merchantSettlement.findFirst({
        where: {
          storeId: input.storeId,
          periodStart: { lte: periodEnd },
          periodEnd: { gte: periodStart },
        },
        select: { id: true },
      });
      if (overlap) {
        throw new FoodRuleError('FOOD_SETTLEMENT_OVERLAP');
      }
      const row = await tx.merchantSettlement.create({
        data: {
          storeId: input.storeId,
          periodStart,
          periodEnd,
          orderCount: input.orderCount,
          grossVnd: input.grossVnd,
          merchantFundedVnd: input.merchantFundedVnd,
          commissionVnd: input.commissionVnd,
          netVnd: input.netVnd,
          actorUserId: input.actorUserId,
          note: input.note,
        },
      });
      await tx.opsAuditLog.create({
        data: {
          id: randomUUID(),
          actorUserId: input.actorUserId,
          action: 'MERCHANT_PAYOUT_RECORD',
          entityType: 'STORE',
          entityId: input.storeId,
          reason: input.reason,
          metadata: {
            settlementId: row.id,
            periodStart: input.periodStart,
            periodEnd: input.periodEnd,
            commissionVnd: input.commissionVnd,
          },
        },
      });
      return toSettlementView(row);
    });
  }

  async accept(orderId: string, ownerId: string): Promise<FoodOrderView> {
    return this.transition(orderId, ownerId, 'PLACED', 'PREPARING', {
      acceptedAt: new Date(),
    });
  }

  async reject(
    orderId: string,
    ownerId: string,
    reason: FoodCancelReason,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, status: 'PLACED', store: { ownerId } },
        data: {
          status: 'CANCELLED',
          cancelReasonCode: reason.code,
          cancelNote: reason.note,
          cancelledBy: 'MERCHANT',
        },
      });
      if (updated.count === 1) {
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: orderId,
        });
        await this.writeFoodStatusOutbox(tx, orderId, 'CANCELLED');
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        return order;
      }
      const existing = await tx.foodOrder.findFirst({
        where: { id: orderId, store: { ownerId } },
        select: { id: true },
      });
      if (!existing) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  async markReady(orderId: string, ownerId: string): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const readyAt = new Date();
      // An early-claimed order goes straight to ASSIGNED; otherwise it opens for claims.
      // Not while the customer still has to answer a change.
      const pendingChange = await tx.foodOrderChange.findFirst({
        where: { orderId, status: 'PENDING', order: { store: { ownerId } } },
        select: { id: true },
      });
      if (pendingChange) {
        throw new FoodRuleError('FOOD_CHANGE_PENDING');
      }
      const early = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          status: 'PREPARING',
          store: { ownerId },
          assignedDriverId: { not: null },
        },
        data: { status: 'ASSIGNED', readyAt },
      });
      const open =
        early.count === 1
          ? early
          : await tx.foodOrder.updateMany({
              where: {
                id: orderId,
                status: 'PREPARING',
                store: { ownerId },
                assignedDriverId: null,
              },
              data: { status: 'READY', readyAt },
            });
      if (open.count === 1) {
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        await this.writeFoodStatusOutbox(tx, orderId, order.status, {
          storeId: order.storeId,
          ...(order.assignedDriverId
            ? { assignedDriverId: order.assignedDriverId }
            : {}),
        });
        return order;
      }
      const existing = await tx.foodOrder.findFirst({
        where: { id: orderId, store: { ownerId } },
        select: { id: true },
      });
      if (!existing) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  async claim(
    orderId: string,
    driverId: string,
    maxConcurrentJobs = 1,
    early?: FoodEarlyClaim,
    fare?: FoodClaimFare,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      // Serialize every job assignment for this driver (ride select / food claim).
      await lockDriverAssignment(tx, driverId);
      const current = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          customerId: true,
          status: true,
          assignedDriverId: true,
          prepMinutes: true,
          createdAt: true,
          acceptedAt: true,
          subtotalVnd: true,
          discountVnd: true,
          deliveryFareVnd: true,
        },
      });
      if (!current || (fare && current.customerId !== fare.customerId)) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      let selected: { id: string; amountVnd: number } | null = null;
      if (fare) {
        const offer = await tx.foodDeliveryOffer.findUnique({
          where: { id: fare.offerId },
        });
        if (
          !offer ||
          offer.orderId !== orderId ||
          offer.driverId !== driverId
        ) {
          throw new FoodRuleError('FOOD_OFFER_NOT_FOUND');
        }
        if (offer.status !== 'PENDING') {
          // Lost a race (another driver claimed / offer closed): conflict, not missing.
          throw new FoodRuleError(
            current.assignedDriverId ? 'FOOD_ALREADY_ASSIGNED' : 'FOOD_STATUS_CONFLICT',
          );
        }
        if (offer.expiresAt.getTime() <= fare.now.getTime()) {
          throw new FoodRuleError('FOOD_OFFER_EXPIRED');
        }
        selected = { id: offer.id, amountVnd: offer.amountVnd };
      }
      if (current.customerId === driverId) {
        throw new FoodRuleError('FOOD_SELF_CLAIM');
      }
      const isEarly =
        current.status === 'PREPARING' && current.assignedDriverId === null;
      if (isEarly) {
        const opensAt = early
          ? earlyClaimOpensAt(current, early.leadMinutes)
          : null;
        if (!early || !opensAt || opensAt.getTime() > early.now.getTime()) {
          throw new FoodRuleError('FOOD_NOT_YET_CLAIMABLE');
        }
      }

      const [activeFood, activeRides] = await Promise.all([
        tx.foodOrder.count({
          where: {
            assignedDriverId: driverId,
            status: { in: ['PREPARING', 'ASSIGNED', 'PICKED_UP'] },
          },
        }),
        tx.ride.count({
          where: {
            assignedDriverId: driverId,
            status: {
              in: ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'],
            },
          },
        }),
      ]);
      if (activeFood + activeRides >= maxConcurrentJobs) {
        throw new FoodRuleError('DRIVER_AT_CAPACITY');
      }

      // Atomic claim: READY (or early-claimable PREPARING) + unassigned only — concurrent
      // drivers cannot both win.
      // The fare guard makes a concurrent customer raise lose against this claim (or vice versa).
      const agreedFare = selected?.amountVnd ?? current.deliveryFareVnd;
      const fareData = {
        deliveryFareVnd: agreedFare,
        totalVnd: Math.max(
          0,
          current.subtotalVnd + agreedFare - current.discountVnd,
        ),
        deliveryFareAgreedAt: fare?.now ?? new Date(),
      };
      const updated = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          status: isEarly ? 'PREPARING' : 'READY',
          assignedDriverId: null,
          customerId: { not: driverId },
          deliveryFareVnd: current.deliveryFareVnd,
        },
        data: isEarly
          ? { assignedDriverId: driverId, ...fareData }
          : { status: 'ASSIGNED', assignedDriverId: driverId, ...fareData },
      });
      if (updated.count === 1) {
        if (selected) {
          const won = await tx.foodDeliveryOffer.updateMany({
            where: { id: selected.id, status: 'PENDING' },
            data: { status: 'SELECTED' },
          });
          if (won.count !== 1) {
            throw new FoodRuleError('FOOD_OFFER_NOT_FOUND');
          }
        }
        // Drivers whose counter offer lost get a realtime hint (their offer screen closes).
        const losing = await tx.foodDeliveryOffer.findMany({
          where: { orderId, status: 'PENDING', driverId: { not: driverId } },
          select: { driverId: true },
        });
        await tx.foodDeliveryOffer.updateMany({
          where: { orderId, status: 'PENDING' },
          data: { status: 'LOST' },
        });
        const lostDriverIds = [...new Set(losing.map((o) => o.driverId))];
        await this.writeFoodStatusOutbox(
          tx,
          orderId,
          isEarly ? 'PREPARING' : 'ASSIGNED',
          {
            assignedDriverId: driverId,
            ...(lostDriverIds.length ? { lostDriverIds } : {}),
          },
        );
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        return order;
      }
      if (current.status === 'ASSIGNED' || current.assignedDriverId) {
        throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
      }
      const latest = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: { status: true, assignedDriverId: true },
      });
      if (latest?.status === 'ASSIGNED' || latest?.assignedDriverId) {
        throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  async submitDeliveryOffer(
    input: SubmitFoodDeliveryOfferInput,
  ): Promise<FoodDeliveryOfferView> {
    return this.db.$transaction(async (tx) => {
      // Serialize with select / raise on the same order.
      await tx.$queryRaw`SELECT 1 FROM "food_orders" WHERE "id" = ${input.orderId}::uuid FOR UPDATE`;
      const order = await tx.foodOrder.findUnique({
        where: { id: input.orderId },
        select: {
          customerId: true,
          storeId: true,
          status: true,
          assignedDriverId: true,
          deliveryFareVnd: true,
          prepMinutes: true,
          createdAt: true,
          acceptedAt: true,
        },
      });
      if (!order) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (order.customerId === input.driverId) {
        throw new FoodRuleError('FOOD_SELF_CLAIM');
      }
      if (order.assignedDriverId !== null || order.status === 'ASSIGNED') {
        throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
      }
      if (order.status === 'PREPARING') {
        const opensAt = earlyClaimOpensAt(order, input.early.leadMinutes);
        if (!opensAt || opensAt.getTime() > input.early.now.getTime()) {
          throw new FoodRuleError('FOOD_NOT_YET_CLAIMABLE');
        }
      } else if (order.status !== 'READY') {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      const ceiling = counterCeilingVnd(
        order.deliveryFareVnd,
        input.counterMaxPercent,
        input.maxFareVnd,
      );
      if (
        input.amountVnd <= order.deliveryFareVnd ||
        input.amountVnd > ceiling
      ) {
        throw new FoodRuleError('FOOD_OFFER_AMOUNT_INVALID');
      }
      const existing = await tx.foodDeliveryOffer.findUnique({
        where: {
          orderId_driverId: {
            orderId: input.orderId,
            driverId: input.driverId,
          },
        },
      });
      let row;
      if (existing) {
        if (existing.status === 'SELECTED' || existing.status === 'LOST') {
          throw new FoodRuleError('FOOD_STATUS_CONFLICT');
        }
        if (existing.editCount >= input.maxEdits) {
          throw new FoodRuleError('FOOD_OFFER_EDIT_LIMIT');
        }
        row = await tx.foodDeliveryOffer.update({
          where: { id: existing.id },
          data: {
            amountVnd: input.amountVnd,
            status: 'PENDING',
            expiresAt: input.expiresAt,
            editCount: { increment: 1 },
          },
        });
      } else {
        row = await tx.foodDeliveryOffer.create({
          data: {
            orderId: input.orderId,
            driverId: input.driverId,
            amountVnd: input.amountVnd,
            expiresAt: input.expiresAt,
          },
        });
      }
      await writeFoodFareOutbox(tx, {
        orderId: input.orderId,
        kind: 'COUNTER',
        ref: `${row.id}:${row.editCount}`,
        status: order.status,
        storeId: order.storeId,
        amountVnd: row.amountVnd,
      });
      return toOfferView(row);
    });
  }

  async withdrawDeliveryOffer(
    orderId: string,
    driverId: string,
  ): Promise<FoodDeliveryOfferView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodDeliveryOffer.updateMany({
        where: { orderId, driverId, status: 'PENDING' },
        data: { status: 'WITHDRAWN' },
      });
      if (updated.count !== 1) {
        throw new FoodRuleError('FOOD_OFFER_NOT_FOUND');
      }
      const row = await tx.foodDeliveryOffer.findUniqueOrThrow({
        where: { orderId_driverId: { orderId, driverId } },
      });
      return toOfferView(row);
    });
  }

  async listDeliveryOffers(orderId: string): Promise<FoodDeliveryOfferView[]> {
    const rows = await this.db.foodDeliveryOffer.findMany({
      where: { orderId },
      orderBy: { createdAt: 'desc' },
    });
    return rows.map(toOfferView);
  }

  async raiseDeliveryFare(
    input: RaiseFoodDeliveryFareInput,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT 1 FROM "food_orders" WHERE "id" = ${input.orderId}::uuid FOR UPDATE`;
      const order = await tx.foodOrder.findUnique({
        where: { id: input.orderId },
        select: {
          customerId: true,
          storeId: true,
          status: true,
          assignedDriverId: true,
          deliveryFareVnd: true,
          deliveryFareRaiseCount: true,
          subtotalVnd: true,
          discountVnd: true,
        },
      });
      if (!order || order.customerId !== input.customerId) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (
        order.assignedDriverId !== null ||
        !['PLACED', 'PREPARING', 'READY'].includes(order.status)
      ) {
        throw new FoodRuleError('FOOD_FARE_LOCKED');
      }
      if (order.deliveryFareRaiseCount >= input.maxRaises) {
        throw new FoodRuleError('FOOD_FARE_RAISE_LIMIT');
      }
      if (input.amountVnd <= order.deliveryFareVnd) {
        throw new FoodRuleError('FOOD_OFFER_AMOUNT_INVALID');
      }
      const raiseCount = order.deliveryFareRaiseCount + 1;
      await tx.foodOrder.update({
        where: { id: input.orderId },
        data: {
          deliveryFareVnd: input.amountVnd,
          totalVnd: Math.max(
            0,
            order.subtotalVnd + input.amountVnd - order.discountVnd,
          ),
          deliveryFareRaiseCount: raiseCount,
        },
      });
      await writeFoodFareOutbox(tx, {
        orderId: input.orderId,
        kind: 'RAISED',
        ref: String(raiseCount),
        status: order.status,
        storeId: order.storeId,
        amountVnd: input.amountVnd,
      });
      const view = await this.findOrderIn(tx, input.orderId);
      if (!view) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      return view;
    });
  }

  async pickup(
    orderId: string,
    driverId: string,
    snapshot?: { merchantCashVnd: number; at: Date },
  ): Promise<FoodOrderView> {
    return this.assignedDriverTransition(
      orderId,
      driverId,
      'ASSIGNED',
      'PICKED_UP',
      undefined,
      {
        pickedUpAt: snapshot?.at ?? new Date(),
        merchantCashVnd: snapshot?.merchantCashVnd ?? null,
      },
    );
  }

  async snapshotCommissionWithin(
    tx: TxHandle,
    orderId: string,
    input: { commissionBps: number; commissionVnd: number },
  ): Promise<void> {
    await (tx as Prisma.TransactionClient).foodOrder.update({
      where: { id: orderId },
      data: {
        merchantCommissionBps: input.commissionBps,
        merchantCommissionVnd: input.commissionVnd,
      },
    });
  }

  async release(
    orderId: string,
    driverId: string,
    reasonCode: string,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: { assignedDriverId: true, status: true },
      });
      if (!current) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (current.assignedDriverId !== driverId) {
        throw new FoodRuleError('FOOD_NOT_ASSIGNED_DRIVER');
      }
      if (current.status !== 'ASSIGNED' && current.status !== 'PREPARING') {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      const to = current.status === 'ASSIGNED' ? 'READY' : 'PREPARING';
      const updated = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          assignedDriverId: driverId,
          status: current.status,
        },
        data: { status: to, assignedDriverId: null, deliveryFareAgreedAt: null },
      });
      if (updated.count !== 1) {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      await tx.driverJobCancellation.create({
        data: {
          entityType: 'FOOD_ORDER',
          entityId: orderId,
          driverId,
          actor: 'DRIVER',
          reasonCode,
          fromStatus: current.status,
        },
      });
      await this.writeFoodStatusOutbox(tx, orderId, to, {
        releasedBy: driverId,
      });
      const order = await this.findOrderIn(tx, orderId);
      if (!order) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      return order;
    });
  }

  async timeoutDue(
    now: Date,
    policy: FoodTimeoutPolicy,
    limit = 100,
  ): Promise<FoodTimedOut[]> {
    const placedCutoff = new Date(
      now.getTime() - policy.merchantAcceptMinutes * 60_000,
    );
    const readyCutoff = new Date(
      now.getTime() - policy.unclaimedReadyMinutes * 60_000,
    );
    const due = await this.db.foodOrder.findMany({
      where: {
        OR: [
          { status: 'PLACED', createdAt: { lte: placedCutoff } },
          {
            status: 'READY',
            assignedDriverId: null,
            OR: [
              { readyAt: { lte: readyCutoff } },
              { readyAt: null, updatedAt: { lte: readyCutoff } },
            ],
          },
        ],
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      take: limit,
      select: { id: true, status: true },
    });
    const out: FoodTimedOut[] = [];
    for (const row of due) {
      const reason: FoodSystemCancelReason =
        row.status === 'PLACED' ? 'MERCHANT_TIMEOUT' : 'NO_DRIVER';
      const done = await this.db.$transaction(async (tx) => {
        const updated = await tx.foodOrder.updateMany({
          where: { id: row.id, status: row.status, assignedDriverId: null },
          data: {
            status: 'CANCELLED',
            cancelledBy: 'SYSTEM',
            cancelReasonCode: reason,
          },
        });
        if (updated.count !== 1) {
          return false;
        }
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: row.id,
        });
        await this.writeFoodStatusOutbox(tx, row.id, 'CANCELLED', { reason });
        return true;
      });
      if (done) {
        out.push({ orderId: row.id, reason });
      }
    }
    return out;
  }

  async deliver(
    orderId: string,
    driverId: string,
    onDelivered?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView> {
    return this.assignedDriverTransition(
      orderId,
      driverId,
      'PICKED_UP',
      'DELIVERED',
      onDelivered,
    );
  }

  async fail(
    orderId: string,
    driverId: string,
    input: FoodFailInput,
    onFailed?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: {
          id: true,
          assignedDriverId: true,
          status: true,
          pickedUpAt: true,
        },
      });
      if (!current) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (current.assignedDriverId !== driverId) {
        throw new FoodRuleError('FOOD_NOT_ASSIGNED_DRIVER');
      }
      if (current.status === 'PICKED_UP') {
        assertFailWaitOver(current.pickedUpAt, input);
      }
      const updated = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          assignedDriverId: driverId,
          // Only after pickup; before that the driver releases the order.
          status: 'PICKED_UP',
        },
        data: {
          status: 'FAILED',
          failedAt: input.now,
          failReasonCode: input.reasonCode,
          failNote: input.note,
        },
      });
      if (updated.count === 1) {
        await this.writeFoodStatusOutbox(tx, orderId, 'FAILED', {
          failReasonCode: input.reasonCode,
        });
        // Confirmed (DEC-PROD-012): a failed delivery gives the voucher use back.
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: orderId,
        });
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        await onFailed?.(tx, order);
        return order;
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  async proposeChange(
    input: ProposeFoodOrderChangeInput,
  ): Promise<FoodOrderChangeResult> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "food_orders" WHERE id = ${input.orderId}::uuid FOR UPDATE`;
      const owned = await tx.foodOrder.findFirst({
        where: { id: input.orderId, store: { ownerId: input.ownerId } },
        select: { id: true },
      });
      if (!owned) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      const order = await this.findOrderIn(tx, input.orderId);
      if (!order) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (!FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status)) {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      const pending = await tx.foodOrderChange.findFirst({
        where: { orderId: order.id, status: 'PENDING' },
        select: { id: true },
      });
      if (pending) {
        throw new FoodRuleError('FOOD_CHANGE_PENDING');
      }
      const plan = planFoodOrderChange(order, input.lines);
      const row = await tx.foodOrderChange.create({
        data: {
          orderId: order.id,
          reasonCode: input.reasonCode,
          note: input.note,
          lines: plan.lines as unknown as Prisma.InputJsonValue,
          oldSubtotalVnd: plan.oldSubtotalVnd,
          newSubtotalVnd: plan.newSubtotalVnd,
          newDiscountVnd: plan.newDiscountVnd,
          newTotalVnd: plan.newTotalVnd,
          expiresAt: input.expiresAt,
        },
      });
      await tx.foodOrder.update({
        where: { id: order.id },
        data: { updatedAt: new Date() },
      });
      await writeFoodChangeOutbox(tx, {
        orderId: order.id,
        changeId: row.id,
        changeStatus: 'PENDING',
        status: order.status,
        storeId: order.storeId,
        expiresAt: row.expiresAt.toISOString(),
      });
      return { order, change: toChangeView(row) };
    });
  }

  async latestChange(orderId: string): Promise<FoodOrderChangeView | null> {
    const row = await this.db.foodOrderChange.findFirst({
      where: { orderId },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
    return row ? toChangeView(row) : null;
  }

  async respondChange(
    orderId: string,
    customerId: string,
    changeId: string,
    accept: boolean,
    now: Date,
  ): Promise<FoodOrderChangeResult> {
    return this.db.$transaction(async (tx) => {
      await tx.$queryRaw`SELECT id FROM "food_orders" WHERE id = ${orderId}::uuid FOR UPDATE`;
      const order = await this.findOrderIn(tx, orderId);
      if (!order || order.customerId !== customerId) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      const row = await tx.foodOrderChange.findFirst({
        where: { id: changeId, orderId },
      });
      if (!row) {
        throw new FoodRuleError('FOOD_CHANGE_NOT_FOUND');
      }
      const change = toChangeView(row);
      if (
        change.status !== 'PENDING' ||
        !FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status) ||
        change.expiresAt.getTime() <= now.getTime()
      ) {
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      if (accept) {
        for (const line of change.lines) {
          if (line.toQuantity === 0) {
            await tx.foodOrderLine.deleteMany({
              where: { id: line.lineId, orderId },
            });
          } else {
            await tx.foodOrderLine.updateMany({
              where: { id: line.lineId, orderId },
              data: { quantity: line.toQuantity },
            });
          }
        }
        await tx.foodOrder.update({
          where: { id: orderId },
          data: {
            subtotalVnd: change.newSubtotalVnd,
            discountVnd: change.newDiscountVnd,
            totalVnd: change.newTotalVnd,
          },
        });
        // Keep the redemption amount in line with what the order really discounts.
        await tx.promotionRedemption.updateMany({
          where: {
            entityType: 'FOOD_ORDER',
            entityId: orderId,
            releasedAt: null,
          },
          data: { discountVnd: change.newDiscountVnd },
        });
        await tx.foodOrderChange.update({
          where: { id: changeId },
          data: { status: 'ACCEPTED', respondedAt: now },
        });
        await writeFoodChangeOutbox(tx, {
          orderId,
          changeId,
          changeStatus: 'ACCEPTED',
          status: order.status,
          storeId: order.storeId,
        });
      } else {
        await tx.foodOrderChange.update({
          where: { id: changeId },
          data: { status: 'REJECTED', respondedAt: now },
        });
        await tx.foodOrder.update({
          where: { id: orderId },
          data: {
            status: 'CANCELLED',
            cancelledBy: 'CUSTOMER',
            cancelReasonCode: 'CHANGE_REJECTED',
          },
        });
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: orderId,
        });
        await this.writeFoodStatusOutbox(tx, orderId, 'CANCELLED', {
          reason: 'CHANGE_REJECTED',
        });
      }
      const updated = await this.findOrderIn(tx, orderId);
      const after = await tx.foodOrderChange.findUnique({
        where: { id: changeId },
      });
      if (!updated || !after) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      return { order: updated, change: toChangeView(after) };
    });
  }

  async expireChanges(now: Date, limit = 100): Promise<string[]> {
    const due = await this.db.foodOrderChange.findMany({
      where: { status: 'PENDING', expiresAt: { lte: now } },
      orderBy: [{ expiresAt: 'asc' }, { id: 'asc' }],
      take: limit,
      select: { id: true, orderId: true },
    });
    const out: string[] = [];
    for (const row of due) {
      const cancelled = await this.db.$transaction(async (tx) => {
        await tx.$queryRaw`SELECT id FROM "food_orders" WHERE id = ${row.orderId}::uuid FOR UPDATE`;
        const expired = await tx.foodOrderChange.updateMany({
          where: { id: row.id, status: 'PENDING' },
          data: { status: 'EXPIRED', respondedAt: now },
        });
        if (expired.count !== 1) {
          return false;
        }
        const updated = await tx.foodOrder.updateMany({
          where: {
            id: row.orderId,
            status: { in: [...FOOD_CHANGE_EDITABLE_STATUSES] },
          },
          data: {
            status: 'CANCELLED',
            cancelledBy: 'SYSTEM',
            cancelReasonCode: 'CHANGE_EXPIRED',
          },
        });
        if (updated.count !== 1) {
          return false;
        }
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: row.orderId,
        });
        await this.writeFoodStatusOutbox(tx, row.orderId, 'CANCELLED', {
          reason: 'CHANGE_EXPIRED',
        });
        return true;
      });
      if (cancelled) {
        out.push(row.orderId);
      }
    }
    return out;
  }

  async cancel(orderId: string, customerId: string): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, customerId, status: 'PLACED' },
        data: { status: 'CANCELLED', cancelledBy: 'CUSTOMER' },
      });
      if (updated.count === 1) {
        await releaseVoucherInTx(tx, {
          entityType: 'FOOD_ORDER',
          entityId: orderId,
        });
        await this.writeFoodStatusOutbox(tx, orderId, 'CANCELLED');
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        return order;
      }
      const existing = await tx.foodOrder.findFirst({
        where: { id: orderId, customerId },
        select: { id: true },
      });
      if (!existing) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
    });
  }

  async opsCancel(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult> {
    return this.db.$transaction(async (tx) => {
      const existing = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: { id: true, status: true },
      });
      if (!existing) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (
        existing.status === 'DELIVERED' ||
        existing.status === 'FAILED' ||
        existing.status === 'CANCELLED'
      ) {
        throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
      }
      const updated = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          status: { notIn: ['DELIVERED', 'FAILED', 'CANCELLED'] },
        },
        data: { status: 'CANCELLED', cancelledBy: 'OPS' },
      });
      if (updated.count !== 1) {
        throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
      }
      await releaseVoucherInTx(tx, {
        entityType: 'FOOD_ORDER',
        entityId: orderId,
      });
      const auditId = randomUUID();
      await tx.opsAuditLog.create({
        data: {
          id: auditId,
          actorUserId,
          action: 'CANCEL',
          entityType: 'FOOD_ORDER',
          entityId: orderId,
          reason,
          metadata: { priorStatus: existing.status },
        },
      });
      await writeOpsActionOutbox(tx, {
        aggregateType: 'FoodOrder',
        aggregateId: orderId,
        action: 'cancel',
        auditId,
        status: 'CANCELLED',
        payload: { reason },
      });
      await this.writeFoodStatusOutbox(tx, orderId, 'CANCELLED', {
        reason,
        auditId,
      });
      const order = await this.findOrderIn(tx, orderId);
      if (!order) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      return { order, auditId };
    });
  }

  async opsReassign(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, status: 'ASSIGNED' },
        data: { status: 'READY', assignedDriverId: null },
      });
      if (updated.count !== 1) {
        const existing = await tx.foodOrder.findUnique({
          where: { id: orderId },
          select: { id: true },
        });
        if (!existing) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        throw new FoodRuleError('FOOD_STATUS_CONFLICT');
      }
      const auditId = randomUUID();
      await tx.opsAuditLog.create({
        data: {
          id: auditId,
          actorUserId,
          action: 'REASSIGN',
          entityType: 'FOOD_ORDER',
          entityId: orderId,
          reason,
          metadata: { status: 'READY' },
        },
      });
      await writeOpsActionOutbox(tx, {
        aggregateType: 'FoodOrder',
        aggregateId: orderId,
        action: 'reassign',
        auditId,
        status: 'READY',
        payload: { reason },
      });
      await this.writeFoodStatusOutbox(tx, orderId, 'READY', {
        reason,
        auditId,
      });
      const order = await this.findOrderIn(tx, orderId);
      if (!order) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      return { order, auditId };
    });
  }

  private async assignedDriverTransition(
    orderId: string,
    driverId: string,
    from: 'ASSIGNED' | 'PICKED_UP',
    to: 'PICKED_UP' | 'DELIVERED',
    onChanged?: CompletionHook<FoodOrderView>,
    extra: { pickedUpAt?: Date; merchantCashVnd?: number | null } = {},
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: { id: true, assignedDriverId: true, status: true },
      });
      if (!current) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (current.assignedDriverId !== driverId) {
        throw new FoodRuleError('FOOD_NOT_ASSIGNED_DRIVER');
      }
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, assignedDriverId: driverId, status: from },
        data: { status: to, ...extra },
      });
      if (updated.count === 1) {
        await this.writeFoodStatusOutbox(tx, orderId, to);
        if (to === 'DELIVERED') {
          const lines = await tx.foodOrderLine.findMany({
            where: { orderId },
            select: { itemId: true, quantity: true },
          });
          for (const line of lines) {
            await tx.foodItem.update({
              where: { id: line.itemId },
              data: { soldCount: { increment: line.quantity } },
            });
          }
        }
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        await onChanged?.(tx, order);
        return order;
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  private async transition(
    orderId: string,
    ownerId: string,
    from: 'PLACED' | 'PREPARING',
    to: 'PREPARING' | 'READY',
    extra: { acceptedAt?: Date } = {},
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, status: from, store: { ownerId } },
        data: { status: to, ...extra },
      });
      if (updated.count === 1) {
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        await this.writeFoodStatusOutbox(tx, orderId, to, {
          storeId: order.storeId,
        });
        return order;
      }
      const existing = await tx.foodOrder.findFirst({
        where: { id: orderId, store: { ownerId } },
        select: { id: true },
      });
      if (!existing) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  private async writeFoodStatusOutbox(
    tx: Prisma.TransactionClient,
    orderId: string,
    status: string,
    extra: Record<string, unknown> = {},
  ): Promise<void> {
    const row = await tx.foodOrder.findUnique({
      where: { id: orderId },
      select: { storeId: true },
    });
    await writeStatusOutbox(tx, {
      aggregateType: 'FoodOrder',
      aggregateId: orderId,
      status,
      payload: { ...extra, ...(row?.storeId ? { storeId: row.storeId } : {}) },
    });
  }

  private async findOrderIn(
    db: Prisma.TransactionClient | PrismaClient,
    orderId: string,
  ): Promise<FoodOrderView | null> {
    const order = await db.foodOrder.findUnique({
      where: { id: orderId },
      include: orderInclude,
    });
    return order ? toView(order) : null;
  }

  private async requireOwnedItem(
    ownerId: string,
    itemId: string,
  ): Promise<{
    id: string;
    name: string;
    priceVnd: number;
    available: boolean;
  }> {
    const item = await this.db.foodItem.findUnique({
      where: { id: itemId },
      include: { store: { select: { ownerId: true } } },
    });
    if (!item) {
      throw new FoodRuleError('FOOD_ITEM_NOT_FOUND');
    }
    if (item.store.ownerId !== ownerId) {
      throw new FoodRuleError('FOOD_NOT_STORE_OWNER');
    }
    return item;
  }
}

const itemOptionsInclude = {
  optionGroups: {
    orderBy: { position: 'asc' },
    include: { options: { orderBy: { position: 'asc' } } },
  },
} as const satisfies Prisma.FoodItemInclude;

type ItemRow = {
  id: string;
  name: string;
  priceVnd: number;
  originalPriceVnd?: number | null;
  createdAt?: Date;
  available: boolean;
  moderationStatus?: 'PENDING' | 'APPROVED' | 'REJECTED';
  description?: string | null;
  prepMinutes?: number | null;
  imageUrl?: string | null;
  imageUrls?: unknown;
  soldCount?: number;
  menuCategoryId?: string | null;
  optionGroups?: {
    id: string;
    name: string;
    minSelect: number;
    maxSelect: number;
    options: {
      id: string;
      name: string;
      priceDeltaVnd: number;
      available: boolean;
      maxQuantity?: number;
    }[];
  }[];
};

function parseImageUrls(
  raw: unknown,
  cover: string | null | undefined,
): string[] {
  if (Array.isArray(raw)) {
    const urls = raw.filter(
      (u): u is string => typeof u === 'string' && u.length > 0,
    );
    if (urls.length > 0) return urls;
  }
  return cover ? [cover] : [];
}

function prismaItemView(item: ItemRow): StoreItemView {
  return {
    id: item.id,
    name: item.name,
    priceVnd: item.priceVnd,
    originalPriceVnd: shownOriginalPrice(item.priceVnd, item.originalPriceVnd),
    available: item.available,
    addedAt: item.createdAt ? item.createdAt.toISOString() : null,
    moderationStatus: item.moderationStatus,
    description: item.description ?? null,
    prepMinutes: item.prepMinutes ?? null,
    imageUrl: item.imageUrl ?? null,
    imageUrls: parseImageUrls(item.imageUrls, item.imageUrl),
    soldCount: item.soldCount ?? 0,
    menuCategoryId: item.menuCategoryId ?? null,
    optionGroups: (item.optionGroups ?? []).map(
      (group): FoodOptionGroupView => ({
        id: group.id,
        name: group.name,
        minSelect: group.minSelect,
        maxSelect: group.maxSelect,
        options: group.options.map((option) => ({
          id: option.id,
          name: option.name,
          priceDeltaVnd: option.priceDeltaVnd,
          available: option.available,
          maxQuantity: option.maxQuantity ?? 1,
        })),
      }),
    ),
  };
}

const storeDetailInclude = {
  items: { orderBy: { name: 'asc' }, include: itemOptionsInclude },
  hours: true,
  closures: true,
} as const satisfies Prisma.FoodStoreInclude;

function scheduleFromRow(store: {
  hoursConfigured?: boolean;
  lastOrderMinutes?: number;
  hours?: { weekday: number; opensMinute: number; closesMinute: number }[];
  closures?: { date: Date; note: string | null }[];
}): StoreSchedule {
  return {
    hoursConfigured: store.hoursConfigured ?? false,
    lastOrderMinutes: store.lastOrderMinutes ?? 0,
    hours: (store.hours ?? []).map((row) => ({
      weekday: row.weekday,
      opensMinute: row.opensMinute,
      closesMinute: row.closesMinute,
    })),
    closures: (store.closures ?? []).map((row) => ({
      date: row.date.toISOString().slice(0, 10),
      note: row.note,
    })),
  };
}

/** SQL twin of haversineKm() from a fixed origin; the caller aliases food_stores as `s`. */
function distanceKmSql(lat: number, lng: number): Prisma.Sql {
  return Prisma.sql`(
      6371 * 2 * ASIN(LEAST(1, SQRT(
        POWER(SIN(RADIANS(${lat} - s."lat") / 2), 2)
        + COS(RADIANS(${lat})) * COS(RADIANS(s."lat"))
          * POWER(SIN(RADIANS(${lng} - s."lng") / 2), 2)
      )))
    )`;
}

/** SQL twin of storeAvailability().openNow for list ordering (DEC-PROD-027/029). */
function openNowSql(now: Date): Prisma.Sql {
  const today = vnClock(now);
  return Prisma.sql`(
    NOT (s."serviceMode" = 'PAUSED' AND (s."serviceModeUntil" IS NULL OR s."serviceModeUntil" > ${now}))
    AND (
      (NOT s."hoursConfigured" AND NOT ${storeClosedOn(today.date)})
      OR (s."hoursConfigured" AND EXISTS (
        SELECT 1 FROM "food_store_hours" h
        WHERE h."storeId" = s."id"
          AND ${takingOrdersShiftSql(now)}
      ))
    )
  )`;
}

function storeClosedOn(date: string): Prisma.Sql {
  return Prisma.sql`EXISTS (
      SELECT 1 FROM "food_store_closures" c
      WHERE c."storeId" = s."id" AND c."date" = ${date}::date
    )`;
}

/** Minute a shift closes, counted from its start day's midnight (SQL twin of isOvernight). */
function shiftClosesMinuteSql(): Prisma.Sql {
  return Prisma.sql`(CASE WHEN h."closesMinute" < h."opensMinute"
    THEN h."closesMinute" + 1440 ELSE h."closesMinute" END)`;
}

/**
 * Minutes from today's midnight at which a matching row stops serving — the SQL twin of
 * shiftCloseOffset(), used only to break the multi-row tie deterministically.
 */
function shiftCloseOffsetSql(now: Date): Prisma.Sql {
  const today = vnClock(now);
  return Prisma.sql`(h."closesMinute" + (CASE
    WHEN h."weekday" = ${today.weekday} AND h."closesMinute" < h."opensMinute"
    THEN 1440 ELSE 0 END))`;
}

/** The weekly shift taking orders at `now`; SQL twin of the closesAtToday() lookup. */
function takingOrdersShiftSql(now: Date): Prisma.Sql {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  return Prisma.sql`(
    (
      h."weekday" = ${today.weekday}
      AND NOT ${storeClosedOn(today.date)}
      AND h."opensMinute" <= ${today.minute}
      AND ${today.minute} < ${shiftClosesMinuteSql()} - s."lastOrderMinutes"
    )
    OR (
      h."weekday" = ${yesterday.weekday}
      AND h."closesMinute" < h."opensMinute"
      AND NOT ${storeClosedOn(yesterday.date)}
      AND ${today.minute + 1440} < ${shiftClosesMinuteSql()} - s."lastOrderMinutes"
    )
  )`;
}

function acceptFromRow(store: {
  serviceMode?: StoreServiceMode | null;
  serviceModeUntil?: Date | null;
  acceptMode?: StoreAcceptMode;
  maxActiveOrders?: number | null;
  defaultPrepMinutes?: number;
  busyExtraMinutes?: number;
}): Pick<StoreDetail, 'acceptSettings' | 'estimatedPrepMinutes'> {
  const acceptSettings = acceptSettingsFromRow(store);
  const mode = effectiveServiceMode(
    store.serviceMode,
    store.serviceModeUntil,
  ).serviceMode;
  return {
    acceptSettings,
    estimatedPrepMinutes: prepMinutesFor(acceptSettings, mode),
  };
}

function toStoreDetail(store: {
  id: string;
  name: string;
  ownerId: string;
  lat?: number | null;
  lng?: number | null;
  category?: string | null;
  addressLabel?: string | null;
  logoUrl?: string | null;
  coverUrl?: string | null;
  description?: string | null;
  minOrderVnd?: number;
  serviceMode?: StoreServiceMode | null;
  serviceModeUntil?: Date | null;
  hoursConfigured?: boolean;
  lastOrderMinutes?: number;
  acceptMode?: StoreAcceptMode;
  maxActiveOrders?: number | null;
  defaultPrepMinutes?: number;
  busyExtraMinutes?: number;
  hours?: { weekday: number; opensMinute: number; closesMinute: number }[];
  closures?: { date: Date; note: string | null }[];
  items: ItemRow[];
}): StoreDetail {
  const schedule = scheduleFromRow(store);
  const now = new Date();
  const availability = storeAvailability(
    store.serviceMode,
    store.serviceModeUntil,
    schedule,
    now,
  );
  return {
    ...acceptFromRow(store),
    ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
    ...availability,
    closesAtToday: availability.openNow ? closesAtToday(schedule, now) : null,
    schedule: scheduleView(schedule),
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat ?? null,
    lng: store.lng ?? null,
    category: store.category ?? null,
    addressLabel: store.addressLabel ?? null,
    logoUrl: store.logoUrl ?? null,
    coverUrl: store.coverUrl ?? null,
    description: store.description ?? null,
    minOrderVnd: store.minOrderVnd ?? 0,
    items: store.items.map(prismaItemView),
  };
}

/** Snapshot taken at placement; legacy rows (before DEC-PROD-034) fall back to the store's current point. */
function orderPickup(order: {
  pickupLat: number | null;
  pickupLng: number | null;
  pickupLabel: string | null;
  store: {
    lat: number | null;
    lng: number | null;
    addressLabel: string | null;
  };
}): FoodOrderView['pickup'] {
  if (order.pickupLat != null && order.pickupLng != null) {
    return {
      lat: order.pickupLat,
      lng: order.pickupLng,
      label: order.pickupLabel,
    };
  }
  if (order.store.lat != null && order.store.lng != null) {
    return {
      lat: order.store.lat,
      lng: order.store.lng,
      label: order.store.addressLabel,
    };
  }
  return null;
}

/** YYYY-MM-DD → the UTC-midnight Date Prisma stores in a @db.Date column. */
function dayDate(key: string): Date {
  return new Date(`${key}T00:00:00.000Z`);
}

function toSettlementView(row: {
  id: string;
  storeId: string;
  periodStart: Date;
  periodEnd: Date;
  orderCount: number;
  grossVnd: number;
  merchantFundedVnd: number;
  commissionVnd: number;
  netVnd: number;
  actorUserId: string;
  note: string | null;
  createdAt: Date;
}): MerchantSettlementView {
  return {
    ...row,
    periodStart: row.periodStart.toISOString().slice(0, 10),
    periodEnd: row.periodEnd.toISOString().slice(0, 10),
  };
}

function toOfferView(row: {
  id: string;
  orderId: string;
  driverId: string;
  amountVnd: number;
  status: FoodDeliveryOfferView['status'];
  expiresAt: Date;
  editCount: number;
  createdAt: Date;
  updatedAt: Date;
}): FoodDeliveryOfferView {
  return {
    id: row.id,
    orderId: row.orderId,
    driverId: row.driverId,
    amountVnd: row.amountVnd,
    status: row.status,
    expiresAt: row.expiresAt,
    editCount: row.editCount,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function toView(order: OrderRow): FoodOrderView {
  return {
    id: order.id,
    customerId: order.customerId,
    storeId: order.storeId,
    storeName: order.store.name,
    serviceRegionCode:
      order.serviceRegionCode ?? order.store.serviceRegionCode ?? null,
    ownerId: order.store.ownerId,
    status: order.status,
    deliveryFareVnd: order.deliveryFareVnd,
    subtotalVnd: order.subtotalVnd,
    discountVnd: order.discountVnd,
    voucherCode: order.voucherCode,
    voucherSponsor: order.voucherSponsor ?? null,
    totalVnd: order.totalVnd,
    dropoff: {
      lat: order.dropoffLat,
      lng: order.dropoffLng,
      label: order.dropoffLabel,
    },
    pickup: orderPickup(order),
    assignedDriverId: order.assignedDriverId,
    cancelReason: toCancelReason(order.cancelReasonCode, order.cancelNote),
    cancelledBy: order.cancelledBy ?? null,
    note: order.note ?? null,
    utensils: order.utensils ?? true,
    lines: order.lines.map((line) => ({
      id: line.id,
      itemId: line.itemId,
      name: line.name,
      unitPriceVnd: line.unitPriceVnd,
      quantity: line.quantity,
      imageUrl: line.imageUrl ?? null,
      note: line.note ?? null,
      options: parseLineOptions(line.options),
    })),
    prepMinutes: order.prepMinutes ?? null,
    estimatedReadyAt: estimatedReadyAt(
      order.createdAt,
      order.prepMinutes ?? null,
    ),
    pickedUpAt: order.pickedUpAt ?? null,
    failReason: order.failReasonCode
      ? { code: order.failReasonCode, note: order.failNote ?? null }
      : null,
    merchantCashVnd: order.merchantCashVnd ?? null,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
    suggestedDeliveryFareVnd:
      order.suggestedDeliveryFareVnd ?? order.deliveryFareVnd,
    deliveryFareAgreedAt: order.deliveryFareAgreedAt ?? null,
    deliveryFareRaiseCount: order.deliveryFareRaiseCount ?? 0,
  };
}

function isOpenStatus(status: string): status is QueueOrderSummary['status'] {
  return (OPEN_STATUSES as readonly string[]).includes(status);
}

function isUniqueConflict(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === 'P2002'
  );
}

/** Map Admin UI category codes to FoodStore.category substrings used in seed. */
/**
 * UI KYB: PENDING | APPROVED | REJECTED
 * PartnerApplication: DRAFT | SUBMITTED | APPROVED | REJECTED
 */
function mapKybFilterToPartnerStatus(
  raw: string,
): 'PENDING' | 'APPROVED' | 'REJECTED' | null {
  const key = raw.trim().toUpperCase();
  if (
    key === 'PENDING' ||
    key === 'PENDING_KYB' ||
    key === 'NEED_MORE' ||
    key === 'NEEDS_VERIFY'
  ) {
    return 'PENDING';
  }
  if (key === 'APPROVED') return 'APPROVED';
  if (key === 'REJECTED') return 'REJECTED';
  return null;
}

function toCancelReason(
  code: string | null,
  note: string | null,
): FoodCancelReason | null {
  if (!code) {
    return null;
  }
  const known = [
    ...FOOD_REJECT_REASONS,
    ...FOOD_SYSTEM_CANCEL_REASONS,
    ...FOOD_CHANGE_CANCEL_REASONS,
  ] as readonly string[];
  return {
    code: (known.includes(code) ? code : 'OTHER') as FoodCancelReasonCode,
    note: note ?? null,
  };
}

type FoodOrderChangeRow = {
  id: string;
  orderId: string;
  status: string;
  reasonCode: string;
  note: string | null;
  lines: Prisma.JsonValue;
  oldSubtotalVnd: number;
  newSubtotalVnd: number;
  newDiscountVnd: number;
  newTotalVnd: number;
  expiresAt: Date;
  respondedAt: Date | null;
  createdAt: Date;
};

function toChangeView(row: FoodOrderChangeRow): FoodOrderChangeView {
  const lines = Array.isArray(row.lines)
    ? (row.lines as unknown as FoodOrderChangeLine[])
    : [];
  return {
    id: row.id,
    orderId: row.orderId,
    status: row.status as FoodOrderChangeStatusName,
    reasonCode: row.reasonCode,
    note: row.note,
    lines: lines.map((line) => ({ ...line })),
    oldSubtotalVnd: row.oldSubtotalVnd,
    newSubtotalVnd: row.newSubtotalVnd,
    newDiscountVnd: row.newDiscountVnd,
    newTotalVnd: row.newTotalVnd,
    expiresAt: row.expiresAt,
    respondedAt: row.respondedAt,
    createdAt: row.createdAt,
  };
}
