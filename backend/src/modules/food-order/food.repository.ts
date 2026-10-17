import { randomUUID } from 'node:crypto';
import { pageOffset } from '../../shared/pagination/pagination.js';
import {
  getServiceRegion,
  normalizeRegionFilter,
} from '../service-area/service-regions.js';
import { haversineKm } from '../ride/ride-geo.js';
import { FoodRuleError } from './food.error.js';
import { OPEN_FOOD_STATUSES, type FoodOrderStatusName } from './food.constants.js';

export type FoodLineView = {
  itemId: string;
  name: string;
  unitPriceVnd: number;
  quantity: number;
};

export type StoreListItem = {
  id: string;
  name: string;
  ownerId: string;
  lat: number | null;
  lng: number | null;
  category: string | null;
  serviceRegionCode?: string | null;
};

export type StoreBrowseItem = StoreListItem & {
  createdAt: Date;
  distanceKm: number | null;
};

export type StoreBrowsePage = {
  items: StoreBrowseItem[];
  total: number;
};

export type ListFoodStoresQuery = {
  page: number;
  limit: number;
  search?: string;
  category?: string;
  lat?: number;
  lng?: number;
  radiusKm: number;
  sortBy: 'name' | 'createdAt' | 'distance';
};

export type StoreItemView = {
  id: string;
  name: string;
  priceVnd: number;
  available: boolean;
};

export type StoreDetail = StoreListItem & {
  items: StoreItemView[];
};

export type OpsStoreSummary = StoreListItem & {
  createdAt: Date;
  itemCount: number;
};

export type OpsStoreDetail = OpsStoreSummary & {
  items: StoreItemView[];
};

export type OpsStorePage = {
  items: OpsStoreSummary[];
  total: number;
};

export type OpsCatalogModerationItem = {
  id: string;
  code: string;
  name: string;
  category: string;
  store: string;
  price: number;
  submittedAt: string;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  nameReady: boolean;
  imageReady: boolean;
};

export type OpsCatalogModerationPage = {
  items: OpsCatalogModerationItem[];
  total: number;
  page: number;
  limit: number;
};

export type OpsCatalogCategoryItem = {
  code: string;
  name: string;
  slug: string;
  storeCount: number;
  itemCount: number;
  status: 'ACTIVE';
};

export type OpsCatalogCategoryPage = {
  items: OpsCatalogCategoryItem[];
  total: number;
  page: number;
  limit: number;
};

export const UNCATEGORIZED_STORE_CATEGORY_NAME = 'Khác';

export function slugifyStoreCategory(name: string): string {
  const slug = name
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug.length > 0 ? slug : 'khac';
}

export function normalizeStoreCategoryName(category: string | null | undefined): string {
  const trimmed = category?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : UNCATEGORIZED_STORE_CATEGORY_NAME;
}

export function aggregateStoreCategories(
  stores: Array<{ category: string | null; itemCount: number }>,
): OpsCatalogCategoryItem[] {
  const byCode = new Map<string, OpsCatalogCategoryItem>();
  for (const store of stores) {
    const name = normalizeStoreCategoryName(store.category);
    const slug = slugifyStoreCategory(name);
    const existing = byCode.get(slug);
    if (existing) {
      existing.storeCount += 1;
      existing.itemCount += store.itemCount;
      continue;
    }
    byCode.set(slug, {
      code: slug,
      name,
      slug,
      storeCount: 1,
      itemCount: store.itemCount,
      status: 'ACTIVE',
    });
  }
  return [...byCode.values()].sort((a, b) => a.name.localeCompare(b.name, 'vi'));
}

export function filterStoreCategories(
  categories: OpsCatalogCategoryItem[],
  query: { page?: number; limit?: number; q?: string },
): OpsCatalogCategoryPage {
  const page = Math.max(1, query.page ?? 1);
  const limit = Math.max(1, Math.min(50, query.limit ?? 20));
  let filtered = categories;
  if (query.q?.trim()) {
    const q = query.q.trim().toLowerCase();
    filtered = categories.filter(
      (c) =>
        c.name.toLowerCase().includes(q) ||
        c.code.toLowerCase().includes(q) ||
        c.slug.toLowerCase().includes(q),
    );
  }
  const total = filtered.length;
  const start = (page - 1) * limit;
  return {
    items: filtered.slice(start, start + limit),
    total,
    page,
    limit,
  };
}

export type UpdateStoreLocationInput = {
  ownerId: string;
  lat: number;
  lng: number;
};

export type FoodOrderView = {
  id: string;
  customerId: string;
  storeId: string;
  storeName: string | null;
  serviceRegionCode: string | null;
  ownerId: string;
  status: FoodOrderStatusName;
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  assignedDriverId: string | null;
  lines: FoodLineView[];
  updatedAt: Date;
};

export type CatalogItemInput = {
  name: string;
  priceVnd: number;
};

export type CreateCatalogItemInput = {
  ownerId: string;
  name: string;
  priceVnd: number;
  available?: boolean;
};

export type UpdateCatalogItemInput = {
  ownerId: string;
  itemId: string;
  name?: string;
  priceVnd?: number;
};

export type SetItemAvailabilityInput = {
  ownerId: string;
  itemId: string;
  available: boolean;
};

export type OpsFoodOrderPage = {
  items: FoodOrderView[];
  total: number;
};

export type ReadyOrderSummary = {
  id: string;
  storeId: string;
  status: 'READY';
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  /** Store coords when set; dispatch radius prefers these over dropoff. */
  store: { lat: number; lng: number } | null;
  lineCount: number;
};

export type OpsFoodInterveneResult = {
  order: FoodOrderView;
  auditId: string;
};

export type QueueOrderSummary = {
  id: string;
  storeId: string;
  status: (typeof OPEN_FOOD_STATUSES)[number];
  deliveryFareVnd: number;
  subtotalVnd: number;
  totalVnd: number;
  dropoff: { lat: number; lng: number; label: string };
  lineCount: number;
  createdAt: Date;
};

export type PlaceFoodInput = {
  customerId: string;
  storeId: string;
  idempotencyKey: string;
  items: { itemId: string; quantity: number }[];
  dropoff: { lat: number; lng: number; label: string };
  deliveryFareVnd: number;
};

export interface FoodRepository {
  hasStore(): Promise<boolean>;
  createFixtureStore(ownerId: string, items: CatalogItemInput[]): Promise<void>;
  listStores(query: ListFoodStoresQuery): Promise<StoreBrowsePage>;
  listStoresPage(
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
  ): Promise<OpsStorePage>;
  listCatalogModeration(query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
  }): Promise<OpsCatalogModerationPage>;
  listStoreCategories(query: {
    page?: number;
    limit?: number;
    q?: string;
  }): Promise<OpsCatalogCategoryPage>;
  findStoreCategoryByCode(code: string): Promise<OpsCatalogCategoryItem | null>;
  findStore(storeId: string): Promise<StoreDetail | null>;
  findStoreForOps(storeId: string): Promise<OpsStoreDetail | null>;
  findStoreByOwner(ownerId: string): Promise<StoreDetail | null>;
  ensureOwnedStore(ownerId: string, name: string): Promise<StoreDetail>;
  updateStoreLocation(input: UpdateStoreLocationInput): Promise<StoreDetail>;
  createItem(input: CreateCatalogItemInput): Promise<StoreItemView>;
  updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView>;
  setItemAvailability(input: SetItemAvailabilityInput): Promise<StoreItemView>;
  setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{ id: string; available: boolean; moderationStatus: string } | null>;
  place(input: PlaceFoodInput): Promise<FoodOrderView>;
  findOrder(orderId: string): Promise<FoodOrderView | null>;
  listReady(limit?: number): Promise<ReadyOrderSummary[]>;
  listQueue(ownerId: string): Promise<QueueOrderSummary[]>;
  listOrdersPage(
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
  ): Promise<OpsFoodOrderPage>;
  listOrdersForCustomer(
    customerId: string,
    page: number,
    limit: number,
  ): Promise<OpsFoodOrderPage>;
  accept(orderId: string, ownerId: string): Promise<FoodOrderView>;
  markReady(orderId: string, ownerId: string): Promise<FoodOrderView>;
  claim(orderId: string, driverId: string, maxConcurrentJobs?: number): Promise<FoodOrderView>;
  pickup(orderId: string, driverId: string): Promise<FoodOrderView>;
  deliver(orderId: string, driverId: string): Promise<FoodOrderView>;
  fail(orderId: string, driverId: string): Promise<FoodOrderView>;
  cancel(orderId: string, customerId: string): Promise<FoodOrderView>;
  opsCancel(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult>;
  opsReassign(
    orderId: string,
    actorUserId: string,
    reason: string,
  ): Promise<OpsFoodInterveneResult>;
}

type CatalogModerationStatus = 'PENDING' | 'APPROVED' | 'REJECTED';

type StoredStore = StoreListItem & { createdAt: Date };
type StoredItem = StoreItemView & {
  storeId: string;
  moderationStatus: CatalogModerationStatus;
};
type StoredOrder = FoodOrderView & { idempotencyKey: string; createdAt: Date };

function touchOrder(order: StoredOrder): void {
  order.updatedAt = new Date();
}

const OPEN = new Set<string>(OPEN_FOOD_STATUSES);

export class MemoryFoodRepository implements FoodRepository {
  private readonly stores: StoredStore[] = [];
  private readonly items: StoredItem[] = [];
  private readonly orders: StoredOrder[] = [];

  async hasStore(): Promise<boolean> {
    return this.stores.length > 0;
  }

  async createFixtureStore(ownerId: string, items: CatalogItemInput[]): Promise<void> {
    if (this.stores.length > 0) {
      return;
    }
    const storeId = randomUUID();
    this.stores.push({
      id: storeId,
      name: 'Bún Bò Huế',
      ownerId,
      lat: null,
      lng: null,
      category: 'pho',
      createdAt: new Date(),
    });
    for (const item of items) {
      this.items.push({
        id: randomUUID(),
        storeId,
        name: item.name,
        priceVnd: item.priceVnd,
        available: true,
        moderationStatus: 'APPROVED',
      });
    }
  }

  async listStores(query: ListFoodStoresQuery): Promise<StoreBrowsePage> {
    const search = query.search?.trim().toLowerCase();
    const category = query.category?.trim().toLowerCase();
    const hasGeo = query.lat !== undefined && query.lng !== undefined;
    const origin = hasGeo ? { lat: query.lat!, lng: query.lng! } : null;

    let filtered = this.stores.map((store) => {
      const distanceKm =
        origin && store.lat !== null && store.lng !== null
          ? haversineKm(origin, { lat: store.lat, lng: store.lng })
          : null;
      return { store, distanceKm };
    });

    if (search) {
      filtered = filtered.filter((entry) => entry.store.name.toLowerCase().includes(search));
    }
    if (category) {
      filtered = filtered.filter(
        (entry) => entry.store.category?.toLowerCase() === category,
      );
    }
    if (origin) {
      filtered = filtered.filter(
        (entry) => entry.distanceKm !== null && entry.distanceKm <= query.radiusKm,
      );
    }

    const sortBy =
      query.sortBy === 'distance' && !origin ? 'createdAt' : query.sortBy;
    filtered.sort((left, right) => {
      if (sortBy === 'name') {
        return (
          left.store.name.localeCompare(right.store.name) ||
          left.store.id.localeCompare(right.store.id)
        );
      }
      if (sortBy === 'distance') {
        const leftDistance = left.distanceKm ?? Number.POSITIVE_INFINITY;
        const rightDistance = right.distanceKm ?? Number.POSITIVE_INFINITY;
        return (
          leftDistance - rightDistance || left.store.id.localeCompare(right.store.id)
        );
      }
      return (
        right.store.createdAt.getTime() - left.store.createdAt.getTime() ||
        left.store.id.localeCompare(right.store.id)
      );
    });

    const total = filtered.length;
    const start = (pageOffset(query.page, query.limit));
    const items = filtered.slice(start, start + query.limit).map((entry) => ({
      ...toStoreListItem(entry.store),
      createdAt: entry.store.createdAt,
      distanceKm: entry.distanceKm,
    }));
    return { items, total };
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
    let filtered = [...this.stores];
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim().toLowerCase();
      filtered = filtered.filter(
        (s) => s.name.toLowerCase().includes(q) || s.id.toLowerCase().includes(q),
      );
    }
    const regionCode = normalizeRegionFilter(filter?.region);
    if (regionCode) {
      const label =
        getServiceRegion(regionCode)?.label.toLowerCase() ??
        regionCode.toLowerCase();
      filtered = filtered.filter((s) => s.name.toLowerCase().includes(label));
    }
    if (filter?.category && filter.category !== 'ALL') {
      const c = filter.category.toLowerCase();
      filtered = filtered.filter((s) =>
        (s.category ?? '').toLowerCase().includes(c),
      );
    }
    const sorted = filtered.sort(
      (left, right) =>
        right.createdAt.getTime() - left.createdAt.getTime() || left.id.localeCompare(right.id),
    );
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      total,
      items: sorted.slice(start, start + limit).map((store) => this.toOpsStoreSummary(store)),
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
    const combined: OpsCatalogModerationItem[] = [];
    for (const item of this.items) {
      const st = this.stores.find((s) => s.id === item.storeId);
      combined.push({
        id: item.id,
        code: `SP-${item.id.slice(0, 5).toUpperCase()}`,
        name: item.name,
        category: normalizeStoreCategoryName(st?.category),
        store: st ? st.name : 'Cửa hàng DealGo',
        price: item.priceVnd,
        submittedAt: 'Hôm nay',
        status: item.moderationStatus,
        nameReady: true,
        imageReady: true,
      });
    }
    return filterCatalogModerationItems(combined, query);
  }

  async listStoreCategories(query: {
    page?: number;
    limit?: number;
    q?: string;
  }): Promise<OpsCatalogCategoryPage> {
    return filterStoreCategories(this.aggregateCategories(), query);
  }

  async findStoreCategoryByCode(code: string): Promise<OpsCatalogCategoryItem | null> {
    const normalized = code.trim().toLowerCase();
    return this.aggregateCategories().find((c) => c.code === normalized) ?? null;
  }

  private aggregateCategories(): OpsCatalogCategoryItem[] {
    return aggregateStoreCategories(
      this.stores.map((store) => ({
        category: store.category,
        itemCount: this.items.filter((item) => item.storeId === store.id).length,
      })),
    );
  }

  async findStore(storeId: string): Promise<StoreDetail | null> {
    const store = this.stores.find((entry) => entry.id === storeId);
    if (!store) {
      return null;
    }
    return {
      ...toStoreListItem(store),
      items: this.items
        .filter((item) => item.storeId === storeId)
        .map(({ storeId: _storeId, ...item }) => item),
    };
  }

  async findStoreForOps(storeId: string): Promise<OpsStoreDetail | null> {
    const store = this.stores.find((entry) => entry.id === storeId);
    if (!store) {
      return null;
    }
    const items = this.items
      .filter((item) => item.storeId === storeId)
      .map(({ storeId: _storeId, ...item }) => item);
    return {
      ...this.toOpsStoreSummary(store),
      items,
    };
  }

  async place(input: PlaceFoodInput): Promise<FoodOrderView> {
    const existing = this.orders.find(
      (order) => order.customerId === input.customerId && order.idempotencyKey === input.idempotencyKey,
    );
    if (existing) {
      return copyOrder(existing);
    }
    if (this.orders.some((order) => order.customerId === input.customerId && OPEN.has(order.status))) {
      throw new FoodRuleError('FOOD_ORDER_ALREADY_OPEN');
    }
    const store = this.stores.find((entry) => entry.id === input.storeId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const lines = this.snapshotLines(input.storeId, input.items);
    const subtotalVnd = lines.reduce((sum, line) => sum + line.unitPriceVnd * line.quantity, 0);
    const order: StoredOrder = {
      id: randomUUID(),
      customerId: input.customerId,
      storeId: store.id,
      storeName: store.name,
      serviceRegionCode: store.serviceRegionCode ?? null,
      ownerId: store.ownerId,
      status: 'PLACED',
      deliveryFareVnd: input.deliveryFareVnd,
      subtotalVnd,
      totalVnd: subtotalVnd + input.deliveryFareVnd,
      dropoff: { ...input.dropoff },
      assignedDriverId: null,
      lines,
      idempotencyKey: input.idempotencyKey,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    this.orders.push(order);
    return copyOrder(order);
  }

  async findOrder(orderId: string): Promise<FoodOrderView | null> {
    const order = this.orders.find((entry) => entry.id === orderId);
    return order ? copyOrder(order) : null;
  }

  async listReady(limit?: number): Promise<ReadyOrderSummary[]> {
    const rows = this.orders
      .filter((order) => order.status === 'READY' && order.assignedDriverId === null)
      .sort(byCreatedAt)
      .map((order) => {
        const store = this.stores.find((entry) => entry.id === order.storeId);
        const storeCoords =
          store?.lat != null && store?.lng != null ? { lat: store.lat, lng: store.lng } : null;
        return {
          id: order.id,
          storeId: order.storeId,
          status: 'READY' as const,
          deliveryFareVnd: order.deliveryFareVnd,
          subtotalVnd: order.subtotalVnd,
          totalVnd: order.totalVnd,
          dropoff: { ...order.dropoff },
          store: storeCoords,
          lineCount: order.lines.length,
        };
      });
    if (limit !== undefined && Number.isSafeInteger(limit) && limit > 0) {
      return rows.slice(0, limit);
    }
    return rows;
  }

  async listQueue(ownerId: string): Promise<QueueOrderSummary[]> {
    return this.orders
      .filter(
        (order): order is StoredOrder & { status: QueueOrderSummary['status'] } =>
          order.ownerId === ownerId && OPEN.has(order.status),
      )
      .sort(byCreatedAt)
      .map((order) => ({
        id: order.id,
        storeId: order.storeId,
        status: order.status,
        deliveryFareVnd: order.deliveryFareVnd,
        subtotalVnd: order.subtotalVnd,
        totalVnd: order.totalVnd,
        dropoff: { ...order.dropoff },
        lineCount: order.lines.length,
        createdAt: new Date(order.createdAt),
      }));
  }

  async findStoreByOwner(ownerId: string): Promise<StoreDetail | null> {
    const store = this.stores.find((entry) => entry.ownerId === ownerId);
    if (!store) {
      return null;
    }
    return this.findStore(store.id);
  }

  async ensureOwnedStore(ownerId: string, name: string): Promise<StoreDetail> {
    const existing = await this.findStoreByOwner(ownerId);
    if (existing) {
      return existing;
    }
    const storeId = randomUUID();
    this.stores.push({
      id: storeId,
      name,
      ownerId,
      lat: null,
      lng: null,
      category: null,
      createdAt: new Date(),
    });
    return {
      id: storeId,
      name,
      ownerId,
      lat: null,
      lng: null,
      category: null,
      items: [],
    };
  }

  async updateStoreLocation(input: UpdateStoreLocationInput): Promise<StoreDetail> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    store.lat = input.lat;
    store.lng = input.lng;
    const detail = await this.findStore(store.id);
    if (!detail) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return detail;
  }

  /** Test helper: create a store with initial items for a non-fixture merchant. */
  async createStore(ownerId: string, name: string, items: CatalogItemInput[]): Promise<StoreDetail> {
    const store = await this.ensureOwnedStore(ownerId, name);
    for (const item of items) {
      await this.createItem({
        ownerId,
        name: item.name,
        priceVnd: item.priceVnd,
      });
    }
    const refreshed = await this.findStore(store.id);
    if (!refreshed) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    return refreshed;
  }

  async createItem(input: CreateCatalogItemInput): Promise<StoreItemView> {
    const store = this.stores.find((entry) => entry.ownerId === input.ownerId);
    if (!store) {
      throw new FoodRuleError('FOOD_STORE_NOT_FOUND');
    }
    const available = input.available ?? true;
    const stored: StoredItem = {
      id: randomUUID(),
      storeId: store.id,
      name: input.name,
      priceVnd: input.priceVnd,
      available,
      moderationStatus: available ? 'APPROVED' : 'PENDING',
    };
    this.items.push(stored);
    return {
      id: stored.id,
      name: stored.name,
      priceVnd: stored.priceVnd,
      available: stored.available,
    };
  }

  async updateItem(input: UpdateCatalogItemInput): Promise<StoreItemView> {
    const item = this.requireOwnedItem(input.ownerId, input.itemId);
    if (input.name !== undefined) {
      item.name = input.name;
    }
    if (input.priceVnd !== undefined) {
      item.priceVnd = input.priceVnd;
    }
    return {
      id: item.id,
      name: item.name,
      priceVnd: item.priceVnd,
      available: item.available,
    };
  }

  async setItemAvailability(input: SetItemAvailabilityInput): Promise<StoreItemView> {
    const item = this.requireOwnedItem(input.ownerId, input.itemId);
    item.available = input.available;
    if (input.available && item.moderationStatus === 'REJECTED') {
      item.moderationStatus = 'APPROVED';
    }
    return {
      id: item.id,
      name: item.name,
      priceVnd: item.priceVnd,
      available: item.available,
    };
  }

  async setCatalogModeration(
    itemId: string,
    decision: 'APPROVED' | 'REJECTED',
  ): Promise<{ id: string; available: boolean; moderationStatus: string } | null> {
    const item = this.items.find((entry) => entry.id === itemId);
    if (!item) {
      return null;
    }
    item.moderationStatus = decision;
    item.available = decision === 'APPROVED';
    return {
      id: item.id,
      available: item.available,
      moderationStatus: item.moderationStatus,
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
    let sorted = [...this.orders].sort(byCreatedAtDesc);
    if (filter?.statuses && filter.statuses.length > 0) {
      const allowed = new Set(
        filter.statuses.map((s) => s.trim().toUpperCase()).filter(Boolean),
      );
      sorted = sorted.filter((o) => allowed.has(o.status.toUpperCase()));
    } else if (filter?.status && filter.status !== 'ALL') {
      const targetStatus = filter.status.toUpperCase();
      sorted = sorted.filter((o) => o.status.toUpperCase() === targetStatus);
    }
    if (filter?.store && filter.store !== 'ALL') {
      const store = filter.store.toLowerCase();
      sorted = sorted.filter((o) => {
        const storeName = this.stores.find((s) => s.id === o.storeId)?.name?.toLowerCase();
        return o.storeId.toLowerCase().includes(store) || (storeName && storeName.includes(store));
      });
    }
    if (filter?.zone && filter.zone !== 'ALL') {
      const code = normalizeRegionFilter(filter.zone);
      if (code) {
        const label =
          getServiceRegion(code)?.label.toLowerCase() ?? code.toLowerCase();
        sorted = sorted.filter((o) =>
          o.dropoff.label.toLowerCase().includes(label),
        );
      }
    }
    if (filter?.q && filter.q.trim()) {
      const q = filter.q.trim().toLowerCase();
      sorted = sorted.filter((o) => {
        return (
          o.id.toLowerCase().includes(q) ||
          o.customerId.toLowerCase().includes(q) ||
          o.storeId.toLowerCase().includes(q) ||
          o.dropoff.label.toLowerCase().includes(q) ||
          o.lines.some((line) => line.name.toLowerCase().includes(q))
        );
      });
    }
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      items: sorted.slice(start, start + limit).map(copyOrder),
      total,
    };
  }

  async listOrdersForCustomer(
    customerId: string,
    page: number,
    limit: number,
  ): Promise<OpsFoodOrderPage> {
    const sorted = this.orders
      .filter((order) => order.customerId === customerId)
      .sort(byCreatedAtDesc);
    const total = sorted.length;
    const start = (page - 1) * limit;
    return {
      items: sorted.slice(start, start + limit).map(copyOrder),
      total,
    };
  }

  async accept(orderId: string, ownerId: string): Promise<FoodOrderView> {
    const order = this.requireOwned(orderId, ownerId);
    if (order.status !== 'PLACED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'PREPARING';
    touchOrder(order);
    return copyOrder(order);
  }

  async markReady(orderId: string, ownerId: string): Promise<FoodOrderView> {
    const order = this.requireOwned(orderId, ownerId);
    if (order.status !== 'PREPARING') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'READY';
    touchOrder(order);
    return copyOrder(order);
  }

  async claim(orderId: string, driverId: string, maxConcurrentJobs = 1): Promise<FoodOrderView> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.customerId === driverId) {
      throw new FoodRuleError('FOOD_SELF_CLAIM');
    }
    if (order.status === 'ASSIGNED') {
      throw new FoodRuleError('FOOD_ALREADY_ASSIGNED');
    }
    if (order.status !== 'READY' || order.assignedDriverId !== null) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    const active = this.orders.filter(
      (entry) =>
        entry.assignedDriverId === driverId &&
        (entry.status === 'ASSIGNED' || entry.status === 'PICKED_UP'),
    ).length;
    if (active >= maxConcurrentJobs) {
      throw new FoodRuleError('DRIVER_AT_CAPACITY');
    }
    order.status = 'ASSIGNED';
    order.assignedDriverId = driverId;
    touchOrder(order);
    return copyOrder(order);
  }

  async pickup(orderId: string, driverId: string): Promise<FoodOrderView> {
    return this.assignedDriverTransition(orderId, driverId, 'ASSIGNED', 'PICKED_UP');
  }

  async deliver(orderId: string, driverId: string): Promise<FoodOrderView> {
    return this.assignedDriverTransition(orderId, driverId, 'PICKED_UP', 'DELIVERED');
  }

  async fail(orderId: string, driverId: string): Promise<FoodOrderView> {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== 'ASSIGNED' && order.status !== 'PICKED_UP') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'FAILED';
    touchOrder(order);
    return copyOrder(order);
  }

  async cancel(orderId: string, customerId: string): Promise<FoodOrderView> {
    const order = this.orders.find((entry) => entry.id === orderId && entry.customerId === customerId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.status !== 'PLACED') {
      throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
    }
    order.status = 'CANCELLED';
    touchOrder(order);
    return copyOrder(order);
  }

  async opsCancel(
    orderId: string,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsFoodInterveneResult> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (
      order.status === 'DELIVERED' ||
      order.status === 'FAILED' ||
      order.status === 'CANCELLED'
    ) {
      throw new FoodRuleError('FOOD_NOT_CANCELLABLE');
    }
    order.status = 'CANCELLED';
    touchOrder(order);
    return { order: copyOrder(order), auditId: `memory-audit-${order.id}-cancel` };
  }

  async opsReassign(
    orderId: string,
    _actorUserId: string,
    _reason: string,
  ): Promise<OpsFoodInterveneResult> {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.status !== 'ASSIGNED') {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = 'READY';
    order.assignedDriverId = null;
    touchOrder(order);
    return { order: copyOrder(order), auditId: `memory-audit-${order.id}-reassign` };
  }

  private assignedDriverTransition(
    orderId: string,
    driverId: string,
    from: FoodOrderStatusName,
    to: FoodOrderStatusName,
  ): FoodOrderView {
    const order = this.requireAssignedDriver(orderId, driverId);
    if (order.status !== from) {
      throw new FoodRuleError('FOOD_STATUS_CONFLICT');
    }
    order.status = to;
    touchOrder(order);
    return copyOrder(order);
  }

  private requireAssignedDriver(orderId: string, driverId: string): StoredOrder {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    if (order.assignedDriverId !== driverId) {
      throw new FoodRuleError('FOOD_NOT_ASSIGNED_DRIVER');
    }
    return order;
  }

  private requireOwned(orderId: string, ownerId: string): StoredOrder {
    const order = this.orders.find((entry) => entry.id === orderId);
    if (!order || order.ownerId !== ownerId) {
      throw new FoodRuleError('FOOD_ORDER_NOT_FOUND');
    }
    return order;
  }

  private toOpsStoreSummary(store: StoredStore): OpsStoreSummary {
    return {
      ...toStoreListItem(store),
      createdAt: new Date(store.createdAt),
      itemCount: this.items.filter((item) => item.storeId === store.id).length,
    };
  }

  private requireOwnedItem(ownerId: string, itemId: string): StoredItem {
    const item = this.items.find((entry) => entry.id === itemId);
    if (!item) {
      throw new FoodRuleError('FOOD_ITEM_NOT_FOUND');
    }
    const store = this.stores.find((entry) => entry.id === item.storeId);
    if (!store || store.ownerId !== ownerId) {
      throw new FoodRuleError('FOOD_NOT_STORE_OWNER');
    }
    return item;
  }

  private snapshotLines(storeId: string, requested: { itemId: string; quantity: number }[]): FoodLineView[] {
    const seen = new Set<string>();
    return requested.map((line) => {
      if (seen.has(line.itemId)) {
        throw new FoodRuleError('FOOD_ITEM_UNAVAILABLE');
      }
      seen.add(line.itemId);
      const item = this.items.find((entry) => entry.id === line.itemId && entry.storeId === storeId);
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
}

function toStoreListItem(store: StoredStore): StoreListItem {
  return {
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat,
    lng: store.lng,
    category: store.category,
  };
}

function byCreatedAt(left: { createdAt: Date; id: string }, right: { createdAt: Date; id: string }): number {
  return left.createdAt.getTime() - right.createdAt.getTime() || left.id.localeCompare(right.id);
}

function byCreatedAtDesc(
  left: { createdAt: Date; id: string },
  right: { createdAt: Date; id: string },
): number {
  return right.createdAt.getTime() - left.createdAt.getTime() || left.id.localeCompare(right.id);
}

function copyOrder(order: StoredOrder): FoodOrderView {
  return {
    id: order.id,
    customerId: order.customerId,
    storeId: order.storeId,
    storeName: order.storeName ?? null,
    serviceRegionCode: order.serviceRegionCode ?? null,
    ownerId: order.ownerId,
    status: order.status,
    deliveryFareVnd: order.deliveryFareVnd,
    subtotalVnd: order.subtotalVnd,
    totalVnd: order.totalVnd,
    dropoff: { ...order.dropoff },
    assignedDriverId: order.assignedDriverId,
    lines: order.lines.map((line) => ({ ...line })),
    updatedAt: new Date(order.updatedAt),
  };
}

export const DEFAULT_CATALOG_MODERATION_ITEMS: OpsCatalogModerationItem[] = [
  {
    id: 'sp-02456',
    code: 'SP-02456',
    name: 'Cà phê muối',
    category: 'Đồ uống',
    store: 'Highlands Coffee',
    price: 39000,
    submittedAt: '10/06 · 10:25',
    status: 'PENDING',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02455',
    code: 'SP-02455',
    name: 'Bún bò đặc biệt',
    category: 'Đồ ăn',
    store: 'Bếp Nhà - Đà Nẵng',
    price: 55000,
    submittedAt: '10/06 · 09:48',
    status: 'PENDING',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02454',
    code: 'SP-02454',
    name: 'Pizza hải sản',
    category: 'Đồ ăn',
    store: "Pizza 4P's - Đà Nẵng",
    price: 245000,
    submittedAt: '10/06 · 09:12',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02453',
    code: 'SP-02453',
    name: 'Trà sữa trân châu hoàng gia',
    category: 'Đồ uống',
    store: 'Gong Cha',
    price: 48000,
    submittedAt: '10/06 · 08:35',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02452',
    code: 'SP-02452',
    name: 'Mì Quảng ếch',
    category: 'Đồ ăn',
    store: 'Mì Quảng Bà Mua',
    price: 45000,
    submittedAt: '09/06 · 18:20',
    status: 'REJECTED',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02451',
    code: 'SP-02451',
    name: 'Bánh mì pate chả bò',
    category: 'Đồ ăn',
    store: 'Bánh Mì Phượng',
    price: 35000,
    submittedAt: '09/06 · 16:45',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02450',
    code: 'SP-02450',
    name: 'Cơm gà xé Hội An',
    category: 'Đồ ăn',
    store: 'Cơm Gà Bà Buội',
    price: 60000,
    submittedAt: '09/06 · 14:10',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02449',
    code: 'SP-02449',
    name: 'Nước ép dưa hấu bạc hà',
    category: 'Đồ uống',
    store: 'The Alley',
    price: 42000,
    submittedAt: '09/06 · 11:30',
    status: 'PENDING',
    nameReady: true,
    imageReady: false,
  },
  {
    id: 'sp-02448',
    code: 'SP-02448',
    name: 'Gà rán giòn sốt cay',
    category: 'Đồ ăn',
    store: 'Lotteria',
    price: 89000,
    submittedAt: '09/06 · 10:05',
    status: 'APPROVED',
    nameReady: true,
    imageReady: true,
  },
  {
    id: 'sp-02447',
    code: 'SP-02447',
    name: 'Bánh xèo tôm nhảy',
    category: 'Đồ ăn',
    store: 'Bánh Xèo Cô Ba',
    price: 50000,
    submittedAt: '08/06 · 17:50',
    status: 'REJECTED',
    nameReady: false,
    imageReady: false,
  },
];

export function filterCatalogModerationItems(
  items: OpsCatalogModerationItem[],
  query: {
    page?: number;
    limit?: number;
    q?: string;
    store?: string;
    category?: string;
    status?: string;
  },
): OpsCatalogModerationPage {
  const page = Math.max(1, query.page ?? 1);
  const limit = Math.max(1, Math.min(50, query.limit ?? 10));

  let filtered = [...items];
  if (query.status && query.status !== 'ALL') {
    filtered = filtered.filter((i) => i.status === query.status);
  }
  if (query.store && query.store !== 'ALL') {
    const s = query.store.toLowerCase();
    filtered = filtered.filter((i) => i.store.toLowerCase().includes(s));
  }
  if (query.category && query.category !== 'ALL') {
    const c = query.category.toLowerCase();
    filtered = filtered.filter((i) => i.category.toLowerCase().includes(c));
  }
  if (query.q?.trim()) {
    const q = query.q.trim().toLowerCase();
    filtered = filtered.filter(
      (i) =>
        i.code.toLowerCase().includes(q) ||
        i.name.toLowerCase().includes(q) ||
        i.store.toLowerCase().includes(q) ||
        i.category.toLowerCase().includes(q),
    );
  }

  const total = filtered.length;
  const start = (page - 1) * limit;
  return {
    items: filtered.slice(start, start + limit),
    total,
    page,
    limit,
  };
}
