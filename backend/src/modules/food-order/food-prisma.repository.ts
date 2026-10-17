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
import type {
  CatalogItemInput,
  CreateCatalogItemInput,
  FoodLineView,
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
  QueueOrderSummary,
  ReadyOrderSummary,
  SetItemAvailabilityInput,
  ListFoodStoresQuery,
  StoreBrowsePage,
  StoreDetail,
  StoreItemView,
  UpdateCatalogItemInput,
  UpdateStoreLocationInput,
} from './food.repository.js';
import {
  aggregateStoreCategories,
  filterStoreCategories,
  normalizeStoreCategoryName,
} from './food.repository.js';

const OPEN_STATUSES = ['PLACED', 'PREPARING', 'READY', 'ASSIGNED', 'PICKED_UP'] as const;

type OrderRow = {
  id: string;
  customerId: string;
  storeId: string;
  status: FoodOrderView['status'];
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoffLat: number;
  dropoffLng: number;
  dropoffLabel: string;
  serviceRegionCode: string | null;
  assignedDriverId: string | null;
  updatedAt: Date;
  store: {
    ownerId: string;
    name: string;
    serviceRegionCode: string | null;
  };
  lines: {
    itemId: string;
    name: string;
    unitPriceVnd: number;
    quantity: number;
  }[];
};

const orderInclude = {
  lines: true,
  store: {
    select: { ownerId: true, name: true, serviceRegionCode: true },
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

    if (hasGeo) {
      return this.listStoresByDistance({
        ...query,
        search,
        category,
        sortBy,
        skip,
        lat: query.lat!,
        lng: query.lng!,
      });
    }

    const where: Prisma.FoodStoreWhereInput = {};
    if (search) {
      where.name = { contains: search, mode: 'insensitive' };
    }
    if (category) {
      where.category = { equals: category, mode: 'insensitive' };
    }

    const orderBy: Prisma.FoodStoreOrderByWithRelationInput[] =
      sortBy === 'name'
        ? [{ name: 'asc' }, { id: 'asc' }]
        : [{ createdAt: 'desc' }, { id: 'asc' }];

    const [total, stores] = await Promise.all([
      this.db.foodStore.count({ where }),
      this.db.foodStore.findMany({
        where,
        orderBy,
        skip,
        take: query.limit,
        select: {
          id: true,
          name: true,
          ownerId: true,
          lat: true,
          lng: true,
          category: true,
          createdAt: true,
        },
      }),
    ]);

    return {
      total,
      items: stores.map((store) => ({
        id: store.id,
        name: store.name,
        ownerId: store.ownerId,
        lat: store.lat,
        lng: store.lng,
        category: store.category,
        createdAt: store.createdAt,
        distanceKm: null,
      })),
    };
  }

  private async listStoresByDistance(input: {
    page: number;
    limit: number;
    skip: number;
    search?: string;
    category?: string;
    lat: number;
    lng: number;
    radiusKm: number;
    sortBy: 'name' | 'createdAt' | 'distance';
  }): Promise<StoreBrowsePage> {
    const distanceSql = Prisma.sql`(
      6371 * 2 * ASIN(LEAST(1, SQRT(
        POWER(SIN(RADIANS(${input.lat} - "lat") / 2), 2)
        + COS(RADIANS(${input.lat})) * COS(RADIANS("lat"))
          * POWER(SIN(RADIANS(${input.lng} - "lng") / 2), 2)
      )))
    )`;

    const filters: Prisma.Sql[] = [
      Prisma.sql`"lat" IS NOT NULL`,
      Prisma.sql`"lng" IS NOT NULL`,
      Prisma.sql`${distanceSql} <= ${input.radiusKm}`,
    ];
    if (input.search) {
      filters.push(Prisma.sql`"name" ILIKE ${'%' + input.search + '%'}`);
    }
    if (input.category) {
      filters.push(Prisma.sql`LOWER("category") = LOWER(${input.category})`);
    }
    const whereSql = Prisma.join(filters, ' AND ');

    const orderSql =
      input.sortBy === 'name'
        ? Prisma.sql`"name" ASC, "id" ASC`
        : input.sortBy === 'createdAt'
          ? Prisma.sql`"createdAt" DESC, "id" ASC`
          : Prisma.sql`distance_km ASC, "id" ASC`;

    const countRows = await this.db.$queryRaw<Array<{ total: bigint }>>`
      SELECT COUNT(*)::bigint AS total
      FROM "food_stores"
      WHERE ${whereSql}
    `;
    const total = Number(countRows[0]?.total ?? 0);

    const rows = await this.db.$queryRaw<
      Array<{
        id: string;
        name: string;
        ownerId: string;
        lat: number;
        lng: number;
        category: string | null;
        createdAt: Date;
        distance_km: number;
      }>
    >`
      SELECT
        "id",
        "name",
        "ownerId",
        "lat",
        "lng",
        "category",
        "createdAt",
        ${distanceSql} AS distance_km
      FROM "food_stores"
      WHERE ${whereSql}
      ORDER BY ${orderSql}
      LIMIT ${input.limit}
      OFFSET ${input.skip}
    `;

    return {
      total,
      items: rows.map((row) => ({
        id: row.id,
        name: row.name,
        ownerId: row.ownerId,
        lat: row.lat,
        lng: row.lng,
        category: row.category,
        createdAt: row.createdAt,
        distanceKm: Number(row.distance_km),
      })),
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
    } else if (saleOrStatus === 'CLOSED' || saleOrStatus === 'PAUSED') {
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
          _count: { select: { items: true } },
        },
      }),
    ]);
    return {
      total,
      items: stores.map((store) => ({
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
      include: { items: { orderBy: { name: 'asc' } } },
    });
    if (!store) {
      return null;
    }
    return toStoreDetail(store);
  }

  async findStoreForOps(storeId: string): Promise<OpsStoreDetail | null> {
    const store = await this.db.foodStore.findUnique({
      where: { id: storeId },
      include: { items: { orderBy: { name: 'asc' } } },
    });
    if (!store) {
      return null;
    }
    return {
      id: store.id,
      name: store.name,
      ownerId: store.ownerId,
      lat: store.lat,
      lng: store.lng,
      category: store.category,
      createdAt: store.createdAt,
      itemCount: store.items.length,
      items: store.items.map((item) => ({
        id: item.id,
        name: item.name,
        priceVnd: item.priceVnd,
        available: item.available,
      })),
    };
  }

  async findStoreByOwner(ownerId: string): Promise<StoreDetail | null> {
    const store = await this.db.foodStore.findFirst({
      where: { ownerId },
      include: { items: { orderBy: { name: 'asc' } } },
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
      include: { items: { orderBy: { name: 'asc' } } },
    });
    return toStoreDetail(created);
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
        serviceRegionCode: resolveServiceRegionCode({
          lat: input.lat,
          lng: input.lng,
          label: store.name,
        }),
      },
      include: { items: { orderBy: { name: 'asc' } } },
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
      },
    });
    return {
      id: item.id,
      name: item.name,
      priceVnd: item.priceVnd,
      available: item.available,
    };
  }

  async updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView> {
    const item = await this.requireOwnedItem(input.ownerId, input.itemId);
    const updated = await this.db.foodItem.update({
      where: { id: item.id },
      data: {
        ...(input.name !== undefined ? { name: input.name } : {}),
        ...(input.priceVnd !== undefined ? { priceVnd: input.priceVnd } : {}),
      },
    });
    return {
      id: updated.id,
      name: updated.name,
      priceVnd: updated.priceVnd,
      available: updated.available,
    };
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
    });
    return {
      id: updated.id,
      name: updated.name,
      priceVnd: updated.priceVnd,
      available: updated.available,
    };
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
          include: { items: true },
        });
        if (!store) {
          throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
        }
        const lines = snapshotLines(store.items, input.items);
        const subtotalVnd = lines.reduce((sum, line) => sum + line.unitPriceVnd * line.quantity, 0);
        const created = await tx.foodOrder.create({
          data: {
            customerId: input.customerId,
            storeId: store.id,
            status: 'PLACED',
            deliveryFareVnd: input.deliveryFareVnd,
            subtotalVnd,
            totalVnd: subtotalVnd + input.deliveryFareVnd,
            dropoffLat: input.dropoff.lat,
            dropoffLng: input.dropoff.lng,
            dropoffLabel: input.dropoff.label,
            serviceRegionCode: resolveServiceRegionCode({
              lat: input.dropoff.lat,
              lng: input.dropoff.lng,
              label: input.dropoff.label,
              fallback: store.serviceRegionCode,
            }),
            idempotencyKey: input.idempotencyKey,
            lines: { create: lines },
          },
          include: orderInclude,
        });
        return toView(created);
      });
    } catch (error) {
      if (error instanceof FoodRuleError) {
        throw error;
      }
      if (!isUniqueConflict(error)) {
        throw error;
      }
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
        store: { select: { lat: true, lng: true } },
        _count: { select: { lines: true } },
      },
    });
    return orders.map((order) => ({
      id: order.id,
      storeId: order.storeId,
      status: 'READY',
      deliveryFareVnd: order.deliveryFareVnd,
      subtotalVnd: order.subtotalVnd,
      totalVnd: order.totalVnd,
      dropoff: { lat: order.dropoffLat, lng: order.dropoffLng, label: order.dropoffLabel },
      store:
        order.store.lat != null && order.store.lng != null
          ? { lat: order.store.lat, lng: order.store.lng }
          : null,
      lineCount: order._count.lines,
    }));
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
        },
      ];
    });
  }

  async accept(orderId: string, ownerId: string): Promise<FoodOrderView> {
    return this.transition(orderId, ownerId, 'PLACED', 'PREPARING');
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
        await writeStatusOutbox(tx, {
          aggregateType: 'FoodOrder',
          aggregateId: orderId,
          status: 'ASSIGNED',
          payload: { assignedDriverId: driverId },
        });
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

  async deliver(orderId: string, driverId: string): Promise<FoodOrderView> {
    return this.assignedDriverTransition(orderId, driverId, 'PICKED_UP', 'DELIVERED');
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
        await writeStatusOutbox(tx, {
          aggregateType: 'FoodOrder',
          aggregateId: orderId,
          status: 'FAILED',
        });
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
        data: { status: 'CANCELLED' },
      });
      if (updated.count === 1) {
        await writeStatusOutbox(tx, {
          aggregateType: 'FoodOrder',
          aggregateId: orderId,
          status: 'CANCELLED',
        });
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
        data: { status: 'CANCELLED' },
      });
      if (updated.count !== 1) {
        throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
      }
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
      await writeStatusOutbox(tx, {
        aggregateType: 'FoodOrder',
        aggregateId: orderId,
        status: 'CANCELLED',
        payload: { reason, auditId },
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
      await writeStatusOutbox(tx, {
        aggregateType: 'FoodOrder',
        aggregateId: orderId,
        status: 'READY',
        payload: { reason, auditId },
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
        await writeStatusOutbox(tx, {
          aggregateType: 'FoodOrder',
          aggregateId: orderId,
          status: to,
        });
        const order = await this.findOrderIn(tx, orderId);
        if (!order) {
          throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
        }
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
        await writeStatusOutbox(tx, {
          aggregateType: 'FoodOrder',
          aggregateId: orderId,
          status: to,
        });
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

function toStoreDetail(store: {
  id: string;
  name: string;
  ownerId: string;
  lat?: number | null;
  lng?: number | null;
  category?: string | null;
  items: { id: string; name: string; priceVnd: number; available: boolean }[];
}): StoreDetail {
  return {
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat ?? null,
    lng: store.lng ?? null,
    category: store.category ?? null,
    items: store.items.map((item) => ({
      id: item.id,
      name: item.name,
      priceVnd: item.priceVnd,
      available: item.available,
    })),
  };
}

function snapshotLines(
  catalog: { id: string; name: string; priceVnd: number; available: boolean }[],
  requested: { itemId: string; quantity: number }[],
): FoodLineView[] {
  const seen = new Set<string>();
  return requested.map((line) => {
    if (seen.has(line.itemId)) {
      throw new FoodRuleError('FOOD_ITEM_UNAVAILABLE');
    }
    seen.add(line.itemId);
    const item = catalog.find((entry) => entry.id === line.itemId);
    if (!item || !item.available) {
      throw new FoodRuleError('FOOD_ITEM_UNAVAILABLE');
    }
    return {
      itemId: item.id,
      name: item.name,
      unitPriceVnd: item.priceVnd,
      quantity: line.quantity,
    };
  });
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
    totalVnd: order.totalVnd,
    dropoff: { lat: order.dropoffLat, lng: order.dropoffLng, label: order.dropoffLabel },
    assignedDriverId: order.assignedDriverId,
    lines: order.lines.map((line) => ({
      itemId: line.itemId,
      name: line.name,
      unitPriceVnd: line.unitPriceVnd,
      quantity: line.quantity,
    })),
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
