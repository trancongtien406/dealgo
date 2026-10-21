import { cancellationCountsAgainstDriver } from '../../shared/cancel-actor.js';
import type { CancelActorName } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import type { CompletionHook } from '../../shared/tx/completion-hook.js';
import { randomUUID } from 'node:crypto';
import {
  normalizeRegionFilter,
  regionCodeOrLabelFallbackWhere,
  resolveServiceRegionCode,
} from '../service-area/service-regions.js';
import { Prisma, type PrismaClient } from '../../generated/prisma/client.js';
import { paymentFilterMatchers } from '../payment/ops-payment-filter.js';
import { writeOpsActionOutbox, writeStatusOutbox } from '../communication/outbox/outbox.write.js';
import { FoodRuleError } from './food.error.js';
import { effectiveServiceMode, type StoreServiceMode } from './store-service-mode.js';
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
  scheduleView,
  storeAvailability,
  vnClock,
  type StoreSchedule,
} from './store-schedule.js';
import type {
  CatalogItemInput,
  CreateCatalogItemInput,
  FoodDriverHistoryWindow,
  FoodOrderView,
  FoodRepository,
  OpsCatalogCategoryItem,
  OpsCatalogCategoryPage,
  OpsCatalogModerationPage,
  OpsFoodInterveneResult,
  OpsFoodOrderPage,
  OpsStoreDetail,
  OpsStorePage,
  PlaceFoodInput,
  ReplaceItemOptionsInput,
  QueueOrderSummary,
  MerchantStatsRows,
  ReadyOrderSummary,
  SetItemAvailabilityInput,
  ListFoodStoresQuery,
  StoreBrowsePage,
  StoreDetail,
  StoreItemView,
  UpdateCatalogItemInput,
  UpdateStoreLocationInput,
  UpdateStoreProfileInput,
  UpdateStoreScheduleInput,
  UpdateStoreServiceModeInput,
  UpdateStoreAcceptSettingsInput,
  FoodCancelReason,
} from './food.repository.js';
import { FOOD_REJECT_REASONS, type FoodRejectReason } from './food.constants.js';
import {
  DRIVER_HISTORY_FOOD_STATUSES,
  aggregateStoreCategories,
  filterStoreCategories,
  normalizeStoreCategoryName,
  slugifyStoreCategory,
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

const OPEN_STATUSES = ['PLACED', 'PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP'] as const;

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
  prepMinutes: number | null;
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
    itemId: string;
    name: string;
    unitPriceVnd: number;
    quantity: number;
    imageUrl: string | null;
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

  async createFixtureStore(ownerId: string, items: CatalogItemInput[]): Promise<void> {
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
          items: {
            create: items.map((item) => ({
              name: item.name,
              priceVnd: item.priceVnd,
              available: true,
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
      ? Prisma.sql`(
      6371 * 2 * ASIN(LEAST(1, SQRT(
        POWER(SIN(RADIANS(${query.lat!} - s."lat") / 2), 2)
        + COS(RADIANS(${query.lat!})) * COS(RADIANS(s."lat"))
          * POWER(SIN(RADIANS(${query.lng!} - s."lng") / 2), 2)
      )))
    )`
      : Prisma.sql`NULL::double precision`;

    const filters: Prisma.Sql[] = [Prisma.sql`TRUE`];
    if (hasGeo) {
      filters.push(Prisma.sql`s."lat" IS NOT NULL`);
      filters.push(Prisma.sql`s."lng" IS NOT NULL`);
      filters.push(Prisma.sql`${distanceSql} <= ${query.radiusKm}`);
    }
    if (search) {
      filters.push(Prisma.sql`s."name" ILIKE ${'%' + search + '%'}`);
    }
    if (category) {
      filters.push(Prisma.sql`LOWER(s."category") = LOWER(${category})`);
    }
    const whereSql = Prisma.join(filters, ' AND ');
    const openSql = openNowSql(now);

    const orderSql =
      sortBy === 'name'
        ? Prisma.sql`s."name" ASC, s."id" ASC`
        : sortBy === 'createdAt'
          ? Prisma.sql`s."createdAt" DESC, s."id" ASC`
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
        distance_km: number | null;
        imageUrl: string | null;
        logoUrl: string | null;
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
        ${distanceSql} AS distance_km,
        cover."imageUrl" AS "imageUrl",
        s."logoUrl"
      FROM "food_stores" s
      LEFT JOIN LATERAL (
        SELECT i."imageUrl"
        FROM "food_items" i
        WHERE i."storeId" = s."id"
          AND i."imageUrl" IS NOT NULL
          AND i."imageUrl" <> ''
        ORDER BY i."available" DESC, i."id" ASC
        LIMIT 1
      ) cover ON TRUE
      WHERE ${whereSql}
      ORDER BY open_now DESC, ${orderSql}
      LIMIT ${query.limit}
      OFFSET ${skip}
    `;

    return {
      total,
      items: rows.map((row) => {
        const mode = effectiveServiceMode(row.serviceMode, row.serviceModeUntil, now).serviceMode;
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
          closedReason: row.open_now ? null : mode === 'PAUSED' ? 'PAUSED' : 'CLOSED',
          imageUrl: row.imageUrl,
          logoUrl: row.logoUrl,
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
      and.push({
        category: {
          contains: mapStoreCategoryFilter(filter.category),
          mode: 'insensitive',
        },
      });
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
        OR: [{ serviceModeUntil: null }, { serviceModeUntil: { gt: new Date() } }],
      });
    } else if (saleOrStatus === 'CLOSED') {
      and.push({
        OR: [{ items: { none: {} } }, { items: { every: { available: false } } }],
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
        ...storeAvailability(store.serviceMode, store.serviceModeUntil, scheduleFromRow(store)),
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
      storeFilter.category = {
        contains: mapStoreCategoryFilter(query.category),
        mode: 'insensitive',
      };
    }
    if (Object.keys(storeFilter).length > 0) {
      where.store = storeFilter;
    }
    if (query.status && query.status !== 'ALL') {
      const status = query.status.toUpperCase();
      if (status === 'APPROVED' || status === 'PENDING' || status === 'REJECTED') {
        where.moderationStatus = status;
      }
    }

    const [total, rows] = await Promise.all([
      this.db.foodItem.count({ where }),
      this.db.foodItem.findMany({
        where,
        include: { store: true },
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
        category: normalizeStoreCategoryName(r.store.category),
        store: r.store.name,
        price: r.priceVnd,
        submittedAt: 'Hôm nay',
        status: r.moderationStatus,
        nameReady: true,
        imageReady: true,
      })),
      total,
      page,
      limit,
    };
  }

  async listStoreCategories(query: {
    page?: number;
    limit?: number;
    q?: string;
  }): Promise<OpsCatalogCategoryPage> {
    return filterStoreCategories(await this.loadStoreCategories(), query);
  }

  async findStoreCategoryByCode(code: string): Promise<OpsCatalogCategoryItem | null> {
    const normalized = code.trim().toLowerCase();
    return (await this.loadStoreCategories()).find((c) => c.code === normalized) ?? null;
  }

  async renameStoreCategory(code: string, name: string): Promise<OpsCatalogCategoryItem> {
    const current = await this.findStoreCategoryByCode(code);
    if (!current) {
      throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    }
    const stores = await this.db.foodStore.findMany({ select: { id: true, category: true } });
    const targets = stores.filter(
      (store) => slugifyStoreCategory(normalizeStoreCategoryName(store.category)) === current.code,
    );
    if (targets.length > 0) {
      await this.db.foodStore.updateMany({
        where: { id: { in: targets.map((t) => t.id) } },
        data: { category: name },
      });
    }
    const next = await this.findStoreCategoryByCode(slugifyStoreCategory(name));
    if (!next) {
      throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    }
    return next;
  }

  private async loadStoreCategories(): Promise<OpsCatalogCategoryItem[]> {
    const stores = await this.db.foodStore.findMany({
      select: {
        category: true,
        _count: { select: { items: true } },
      },
    });
    return aggregateStoreCategories(
      stores.map((store) => ({
        category: store.category,
        itemCount: store._count.items,
      })),
    );
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
    return {
      ...acceptFromRow(store),
      ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
      ...storeAvailability(store.serviceMode, store.serviceModeUntil, scheduleFromRow(store)),
      id: store.id,
      name: store.name,
      ownerId: store.ownerId,
      lat: store.lat,
      lng: store.lng,
      category: store.category,
      createdAt: store.createdAt,
      itemCount: store.items.length,
      items: store.items.map(prismaItemView),
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
    const created = await this.db.foodStore.create({
      data: { ownerId, name },
      include: storeDetailInclude,
    });
    return toStoreDetail(created);
  }

  async updateStoreSchedule(input: UpdateStoreScheduleInput): Promise<StoreDetail> {
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

  async updateStoreAcceptSettings(input: UpdateStoreAcceptSettingsInput): Promise<StoreDetail> {
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

  async updateStoreServiceMode(input: UpdateStoreServiceModeInput): Promise<StoreDetail> {
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
        ...(input.busyExtraMinutes !== undefined ? { busyExtraMinutes: input.busyExtraMinutes } : {}),
      },
      include: storeDetailInclude,
    });
    return toStoreDetail(updated);
  }

  async updateStoreProfile(input: UpdateStoreProfileInput): Promise<StoreDetail> {
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

  async updateStoreLocation(input: UpdateStoreLocationInput): Promise<StoreDetail> {
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
        available,
        moderationStatus: available ? 'APPROVED' : 'PENDING',
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
    const updated = await this.db.foodItem.update({
      where: { id: item.id },
      data: {
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.priceVnd !== undefined ? { priceVnd: input.priceVnd } : {}),
        ...(input.available !== undefined ? { available: input.available } : {}),
        ...(input.description !== undefined ? { description: input.description } : {}),
        ...(input.prepMinutes !== undefined ? { prepMinutes: input.prepMinutes } : {}),
        ...(input.imageUrl !== undefined ? { imageUrl: input.imageUrl } : {}),
        ...(input.imageUrls !== undefined
          ? { imageUrls: input.imageUrls, imageUrl: input.imageUrls[0] ?? null }
          : input.imageUrl !== undefined
            ? { imageUrls: input.imageUrl ? [input.imageUrl] : [] }
            : {}),
        ...(input.menuCategoryId !== undefined ? { menuCategoryId: input.menuCategoryId } : {}),
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
      ? rawUrls.filter((u): u is string => typeof u === 'string' && u.length > 0)
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

  async listMenuCategories(ownerId: string): Promise<import('./food.repository.js').MenuCategoryView[]> {
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
    return { id: row.id, name: row.name, description: row.description, position: row.position, itemCount: 0 };
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

  async deleteMenuCategory(ownerId: string, categoryId: string): Promise<{ deleted: true }> {
    const owned = await this.db.foodMenuCategory.findFirst({
      where: { id: categoryId, store: { ownerId } },
      select: { id: true },
    });
    if (!owned) throw new FoodRuleError('FOOD_CATEGORY_NOT_FOUND');
    await this.db.foodMenuCategory.delete({ where: { id: owned.id } });
    return { deleted: true };
  }

  async reorderMenuCategories(ownerId: string, orderedIds: string[]): Promise<import('./food.repository.js').MenuCategoryView[]> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (!store) throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    const existing = await this.db.foodMenuCategory.findMany({ where: { storeId: store.id } });
    const idSet = new Set(existing.map((r) => r.id));
    if (orderedIds.length !== existing.length || orderedIds.some((id) => !idSet.has(id))) {
      throw new FoodRuleError('FOOD_CATEGORY_REORDER_INVALID');
    }
    await this.db.$transaction(
      orderedIds.map((id, position) =>
        this.db.foodMenuCategory.update({ where: { id }, data: { position } }),
      ),
    );
    return this.listMenuCategories(ownerId);
  }

  async listMerchantHistory(filter: import('./food.repository.js').MerchantHistoryFilter) {
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
          lines: { select: { name: true, quantity: true }, orderBy: { name: 'asc' }, take: 4 },
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

  async replaceItemOptions(input: ReplaceItemOptionsInput): Promise<StoreItemView> {
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

  async setItemAvailability(input: SetItemAvailabilityInput): Promise<StoreItemView> {
    const item = await this.requireOwnedItem(input.ownerId, input.itemId);
    const updated = await this.db.foodItem.update({
      where: { id: item.id },
      data: {
        available: input.available,
        ...(input.available
          ? { moderationStatus: 'APPROVED' as const }
          : {}),
      },
      include: itemOptionsInclude,
    });
    return prismaItemView(updated);
  }

  async setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{ id: string; available: boolean; moderationStatus: string } | null> {
    const existing = await this.db.foodItem.findUnique({ where: { id: itemId } });
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
      and.push({ status: filter.status.toUpperCase() as FoodOrderView['status'] });
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

  private async foodOrderIdsForPaymentFilter(payment: string): Promise<string[]> {
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
      if (!cancellationCountsAgainstDriver(row.status, row.cancelledBy)) continue;
      const current = counts.get(row.assignedDriverId) ?? { completed: 0, finished: 0 };
      current.finished += row._count._all;
      if (row.status === 'DELIVERED') {
        current.completed += row._count._all;
      }
      counts.set(row.assignedDriverId, current);
    }
    return counts;
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
          where: { customerId: input.customerId, status: { in: [...OPEN_STATUSES] } },
          select: { id: true },
        });
        if (open) {
          throw new FoodRuleError('FOOD_ORDER_ALREADY_OPEN');
        }
        const store = await tx.foodStore.findUnique({
          where: { id: input.storeId },
          include: { items: { include: itemOptionsInclude }, hours: true, closures: true },
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
            where: { storeId: store.id, status: { in: [...KITCHEN_ACTIVE_STATUSES] } },
          });
          if (atCapacity(acceptSettings, active)) {
            throw new FoodRuleError('FOOD_STORE_AT_CAPACITY');
          }
        }
        const lines = snapshotFoodLines(store.items.map(prismaItemView), input.items);
        const subtotalVnd = lines.reduce((sum, line) => sum + line.unitPriceVnd * line.quantity, 0);
        const orderId = randomUUID();
        const voucher = input.voucherCode
          ? await redeemVoucherInTx(tx, {
              code: input.voucherCode,
              userId: input.customerId,
              serviceType: 'FOOD',
              orderAmount: subtotalVnd,
              deliveryFee: input.deliveryFareVnd,
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
            subtotalVnd,
            discountVnd,
            voucherCode: voucher?.code ?? null,
            voucherSponsor: voucher?.sponsor ?? null,
            totalVnd: Math.max(0, subtotalVnd + input.deliveryFareVnd - discountVnd),
            dropoffLat: input.dropoff.lat,
            dropoffLng: input.dropoff.lng,
            dropoffLabel: input.dropoff.label,
            // DEC-PROD-034: the driver navigates to where the store was when the order was placed.
            pickupLat: store.lat != null && store.lng != null ? store.lat : null,
            pickupLng: store.lat != null && store.lng != null ? store.lng : null,
            pickupLabel: store.lat != null && store.lng != null ? (store.addressLabel ?? null) : null,
            serviceRegionCode: resolveServiceRegionCode({
              lat: input.dropoff.lat,
              lng: input.dropoff.lng,
              label: input.dropoff.label,
              fallback: store.serviceRegionCode,
            }),
            idempotencyKey: input.idempotencyKey,
            lines: {
              create: lines.map((line) => ({
                itemId: line.itemId,
                name: line.name,
                unitPriceVnd: line.unitPriceVnd,
                quantity: line.quantity,
                imageUrl: line.imageUrl,
                options: line.options as Prisma.InputJsonValue,
              })),
            },
          },
          include: orderInclude,
        });
        await this.writeFoodStatusOutbox(tx, created.id, created.status, { storeId: created.storeId });
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

  async listReady(limit?: number): Promise<ReadyOrderSummary[]> {
    const take =
      limit !== undefined && Number.isSafeInteger(limit) && limit > 0 ? limit : undefined;
    const orders = await this.db.foodOrder.findMany({
      where: { status: 'READY', assignedDriverId: null },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      ...(take !== undefined ? { take } : {}),
      select: {
        id: true,
        storeId: true,
        deliveryFareVnd: true,
        subtotalVnd: true,
        totalVnd: true,
        dropoffLat: true,
        dropoffLng: true,
        dropoffLabel: true,
        pickupLat: true,
        pickupLng: true,
        pickupLabel: true,
        store: { select: { lat: true, lng: true, name: true, addressLabel: true } },
        _count: { select: { lines: true } },
      },
    });
    return orders.map((order) => {
      const pickup = orderPickup(order);
      return {
        id: order.id,
        storeId: order.storeId,
        status: 'READY' as const,
        storeName: order.store.name,
        storeAddress: order.store.addressLabel,
        deliveryFareVnd: order.deliveryFareVnd,
        subtotalVnd: order.subtotalVnd,
        totalVnd: order.totalVnd,
        dropoff: { lat: order.dropoffLat, lng: order.dropoffLng, label: order.dropoffLabel },
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
          dropoff: { lat: order.dropoffLat, lng: order.dropoffLng, label: order.dropoffLabel },
          lineCount: order._count.lines,
          createdAt: order.createdAt,
          customerId: order.customerId,
          assignedDriverId: order.assignedDriverId,
        },
      ];
    });
  }

  async merchantStats(ownerId: string, since: Date, topLimit: number): Promise<MerchantStatsRows> {
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
        where: { order: { store: { ownerId }, status: 'DELIVERED', updatedAt: { gte: since } } },
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
      topItems: top.map((row) => ({ name: row.name, quantity: row._sum.quantity ?? 0 })),
    };
  }

  async accept(orderId: string, ownerId: string): Promise<FoodOrderView> {
    return this.transition(orderId, ownerId, 'PLACED', 'PREPARING');
  }

  async reject(orderId: string, ownerId: string, reason: FoodCancelReason): Promise<FoodOrderView> {
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
        await releaseVoucherInTx(tx, { entityType: 'FOOD_ORDER', entityId: orderId });
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
    return this.transition(orderId, ownerId, 'PREPARING', 'READY');
  }

  async claim(
    orderId: string,
    driverId: string,
    maxConcurrentJobs = 1,
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const current = await tx.foodOrder.findUnique({
        where: { id: orderId },
        select: { id: true, customerId: true, status: true, assignedDriverId: true },
      });
      if (!current) {
        throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
      }
      if (current.customerId === driverId) {
        throw new FoodRuleError('FOOD_SELF_CLAIM');
      }

      const [activeFood, activeRides] = await Promise.all([
        tx.foodOrder.count({
          where: {
            assignedDriverId: driverId,
            status: { in: ['ASSIGNED', 'PICKED_UP'] },
          },
        }),
        tx.ride.count({
          where: {
            assignedDriverId: driverId,
            status: { in: ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'] },
          },
        }),
      ]);
      if (activeFood + activeRides >= maxConcurrentJobs) {
        throw new FoodRuleError('DRIVER_AT_CAPACITY');
      }

      // Atomic claim: READY + unassigned only — concurrent drivers cannot both win.
      const updated = await tx.foodOrder.updateMany({
        where: {
          id: orderId,
          status: 'READY',
          assignedDriverId: null,
          customerId: { not: driverId },
        },
        data: { status: 'ASSIGNED', assignedDriverId: driverId },
      });
      if (updated.count === 1) {
        await this.writeFoodStatusOutbox(tx, orderId, 'ASSIGNED', { assignedDriverId: driverId });
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

  async pickup(orderId: string, driverId: string): Promise<FoodOrderView> {
    return this.assignedDriverTransition(orderId, driverId, 'ASSIGNED', 'PICKED_UP');
  }

  async deliver(
    orderId: string,
    driverId: string,
    onDelivered?: CompletionHook<FoodOrderView>,
  ): Promise<FoodOrderView> {
    return this.assignedDriverTransition(orderId, driverId, 'PICKED_UP', 'DELIVERED', onDelivered);
  }

  async fail(orderId: string, driverId: string): Promise<FoodOrderView> {
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
        where: {
          id: orderId,
          assignedDriverId: driverId,
          status: { in: ['ASSIGNED', 'PICKED_UP'] },
        },
        data: { status: 'FAILED' },
      });
      if (updated.count === 1) {
        await this.writeFoodStatusOutbox(tx, orderId, 'FAILED');
        // Confirmed (DEC-PROD-012): a failed delivery gives the voucher use back.
        await releaseVoucherInTx(tx, { entityType: 'FOOD_ORDER', entityId: orderId });
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        return order;
      }
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    });
  }

  async cancel(orderId: string, customerId: string): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, customerId, status: 'PLACED' },
        data: { status: 'CANCELLED', cancelledBy: 'CUSTOMER' },
      });
      if (updated.count === 1) {
        await releaseVoucherInTx(tx, { entityType: 'FOOD_ORDER', entityId: orderId });
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
      await releaseVoucherInTx(tx, { entityType: 'FOOD_ORDER', entityId: orderId });
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
      await this.writeFoodStatusOutbox(tx, orderId, 'CANCELLED', { reason, auditId });
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
      await this.writeFoodStatusOutbox(tx, orderId, 'READY', { reason, auditId });
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
        data: { status: to },
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
  ): Promise<FoodOrderView> {
    return this.db.$transaction(async (tx) => {
      const updated = await tx.foodOrder.updateMany({
        where: { id: orderId, status: from, store: { ownerId } },
        data: { status: to },
      });
      if (updated.count === 1) {
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
        await this.writeFoodStatusOutbox(tx, orderId, to, { storeId: order.storeId });
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
  ): Promise<{ id: string; name: string; priceVnd: number; available: boolean }> {
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
  available: boolean;
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

function parseImageUrls(raw: unknown, cover: string | null | undefined): string[] {
  if (Array.isArray(raw)) {
    const urls = raw.filter((u): u is string => typeof u === 'string' && u.length > 0);
    if (urls.length > 0) return urls;
  }
  return cover ? [cover] : [];
}

function prismaItemView(item: ItemRow): StoreItemView {
  return {
    id: item.id,
    name: item.name,
    priceVnd: item.priceVnd,
    available: item.available,
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

/** SQL twin of storeAvailability().openNow for list ordering (DEC-PROD-027/029). */
function openNowSql(now: Date): Prisma.Sql {
  const today = vnClock(now);
  const yesterday = vnClock(new Date(now.getTime() - 24 * 60 * 60 * 1000));
  const closedOn = (date: string) => Prisma.sql`EXISTS (
      SELECT 1 FROM "food_store_closures" c
      WHERE c."storeId" = s."id" AND c."date" = ${date}::date
    )`;
  return Prisma.sql`(
    NOT (s."serviceMode" = 'PAUSED' AND (s."serviceModeUntil" IS NULL OR s."serviceModeUntil" > ${now}))
    AND (
      (NOT s."hoursConfigured" AND NOT ${closedOn(today.date)})
      OR (s."hoursConfigured" AND EXISTS (
        SELECT 1 FROM "food_store_hours" h
        WHERE h."storeId" = s."id"
          AND (
            (
              h."weekday" = ${today.weekday}
              AND NOT ${closedOn(today.date)}
              AND h."opensMinute" <= ${today.minute}
              AND ${today.minute} < (CASE WHEN h."closesMinute" < h."opensMinute"
                THEN h."closesMinute" + 1440 ELSE h."closesMinute" END) - s."lastOrderMinutes"
            )
            OR (
              h."weekday" = ${yesterday.weekday}
              AND h."closesMinute" < h."opensMinute"
              AND NOT ${closedOn(yesterday.date)}
              AND ${today.minute + 1440} < h."closesMinute" + 1440 - s."lastOrderMinutes"
            )
          )
      ))
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
  const mode = effectiveServiceMode(store.serviceMode, store.serviceModeUntil).serviceMode;
  return { acceptSettings, estimatedPrepMinutes: prepMinutesFor(acceptSettings, mode) };
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
  return {
    ...acceptFromRow(store),
    ...effectiveServiceMode(store.serviceMode, store.serviceModeUntil),
    ...storeAvailability(store.serviceMode, store.serviceModeUntil, schedule),
    schedule: scheduleView(schedule),
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat ?? null,
    lng: store.lng ?? null,
    category: store.category ?? null,
    addressLabel: store.addressLabel ?? null,
    logoUrl: store.logoUrl ?? null,
    items: store.items.map(prismaItemView),
  };
}

/** Snapshot taken at placement; legacy rows (before DEC-PROD-034) fall back to the store's current point. */
function orderPickup(order: {
  pickupLat: number | null;
  pickupLng: number | null;
  pickupLabel: string | null;
  store: { lat: number | null; lng: number | null; addressLabel: string | null };
}): FoodOrderView['pickup'] {
  if (order.pickupLat != null && order.pickupLng != null) {
    return { lat: order.pickupLat, lng: order.pickupLng, label: order.pickupLabel };
  }
  if (order.store.lat != null && order.store.lng != null) {
    return { lat: order.store.lat, lng: order.store.lng, label: order.store.addressLabel };
  }
  return null;
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
    dropoff: { lat: order.dropoffLat, lng: order.dropoffLng, label: order.dropoffLabel },
    pickup: orderPickup(order),
    assignedDriverId: order.assignedDriverId,
    cancelReason: toCancelReason(order.cancelReasonCode, order.cancelNote),
    cancelledBy: order.cancelledBy ?? null,
    lines: order.lines.map((line) => ({
      itemId: line.itemId,
      name: line.name,
      unitPriceVnd: line.unitPriceVnd,
      quantity: line.quantity,
      imageUrl: line.imageUrl ?? null,
      options: parseLineOptions(line.options),
    })),
    prepMinutes: order.prepMinutes ?? null,
    estimatedReadyAt: estimatedReadyAt(order.createdAt, order.prepMinutes ?? null),
    updatedAt: order.updatedAt,
  };
}

function isOpenStatus(status: string): status is QueueOrderSummary['status'] {
  return (OPEN_STATUSES as readonly string[]).includes(status);
}

function isUniqueConflict(error: unknown): boolean {
  return error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002';
}

/** Map Admin UI category codes to FoodStore.category substrings used in seed. */
function mapStoreCategoryFilter(raw: string): string {
  const key = raw.trim().toUpperCase();
  if (key === 'FOOD' || key === 'DO_AN') return 'Đồ ăn';
  if (key === 'DRINK' || key === 'DO_UONG') return 'Đồ uống';
  if (key === 'GROCERY' || key === 'TAP_HOA') return 'Tạp';
  return raw.trim();
}

/**
 * UI KYB: PENDING | APPROVED | REJECTED
 * PartnerApplication: DRAFT | SUBMITTED | APPROVED | REJECTED
 */
function mapKybFilterToPartnerStatus(
  raw: string,
): 'PENDING' | 'APPROVED' | 'REJECTED' | null {
  const key = raw.trim().toUpperCase();
  if (key === 'PENDING' || key === 'PENDING_KYB' || key === 'NEED_MORE' || key === 'NEEDS_VERIFY') {
    return 'PENDING';
  }
  if (key === 'APPROVED') return 'APPROVED';
  if (key === 'REJECTED') return 'REJECTED';
  return null;
}

function toCancelReason(code: string | null, note: string | null): FoodCancelReason | null {
  if (!code) {
    return null;
  }
  const known = (FOOD_REJECT_REASONS as readonly string[]).includes(code);
  return { code: (known ? code : 'OTHER') as FoodRejectReason, note: note ?? null };
}
