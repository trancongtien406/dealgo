import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { filterByDispatchRadius, type DispatchQuery } from '../dispatch/dispatch-filter.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import type { AppEnv } from '../../platform/config/env.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { DriverPresenceService } from '../identity/driver-presence.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
  type RoleName,
} from '../identity/identity.repository.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { MAPS_PORT } from '../../integrations/maps/maps.constants.js';
import {
  resolveRouteDistanceKm,
  UnavailableMapsError,
  type MapsPort,
} from '../../integrations/maps/maps-port.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { PartnerEligibilityService } from '../partner/partner-eligibility.service.js';
import { PAYMENT_PORT } from '../payment/payment.constants.js';
import type { PaymentPort } from '../payment/payment-port.js';
import { UnavailablePaymentError } from '../payment/payment-port.js';
import { quoteReferenceFareVnd } from '../ride/ride-geo.js';
import { FIXTURE_MERCHANT_PHONE, FOOD_REPOSITORY } from './food.constants.js';
import {
  FOOD_STORE_BROWSE_MAX_LIMIT,
  type ListFoodStoresQueryDto,
  type CreateFoodItemDto,
  type OpsCatalogCategoriesQueryDto,
  type OpsCatalogModerationQueryDto,
  type PlaceFoodOrderDto,
  type SetFoodItemAvailabilityDto,
  type UpdateFoodItemDto,
  type UpdateStoreLocationDto,
} from './food.dto.js';
import { FoodRuleError, foodError } from './food.error.js';
import type {
  FoodOrderView,
  FoodRepository,
  OpsCatalogCategoryItem,
  OpsCatalogCategoryPage,
  OpsCatalogModerationPage,
  OpsFoodInterveneResult,
  OpsStoreDetail,
  OpsStoreSummary,
  QueueOrderSummary,
  ReadyOrderSummary,
  StoreBrowseItem,
  StoreDetail,
  StoreItemView,
} from './food.repository.js';

export type PublicStoreBrowseItem = Omit<StoreBrowseItem, 'createdAt'> & {
  createdAt: string;
};

export type OpsStoreListItem = {
  id: string;
  name: string;
  ownerId: string;
  lat: number | null;
  lng: number | null;
  category: string | null;
  serviceRegionCode: string | null;
  createdAt: string;
  itemCount: number;
};

export type OpsStoreView = OpsStoreListItem & {
  items: StoreItemView[];
};

const FIXTURE_ITEMS = [
  { name: 'Bún bò đặc biệt', priceVnd: 60_000 },
  { name: 'Trà tắc', priceVnd: 25_000 },
] as const;

export type PublicFoodOrder = Omit<FoodOrderView, 'ownerId' | 'updatedAt'>;

export type MerchantCatalogView = StoreDetail & {
  sandboxSeed: boolean;
};

@Injectable()
export class FoodService {
  constructor(
    @Inject(FOOD_REPOSITORY) private readonly food: FoodRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(MAPS_PORT) private readonly maps: MapsPort,
    @Inject(PAYMENT_PORT) private readonly payments: PaymentPort,
    private readonly eligibility: PartnerEligibilityService,
    private readonly ledger: LedgerService,
    private readonly presence: DriverPresenceService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly settings: PlatformSettingsService,
  ) {}

  async listStores(
    actor: RequestActor,
    query: ListFoodStoresQueryDto = {},
  ): Promise<PageResult<PublicStoreBrowseItem>> {
    await this.requireActiveCustomer(actor.userId);
    await this.ensureSandboxFixtureCatalog();
    const page = normalizePage(query.page);
    const limit = normalizeLimit(query.limit, FOOD_STORE_BROWSE_MAX_LIMIT);
    const hasGeo = query.lat !== undefined && query.lng !== undefined;
    const sortBy =
      query.sort_by === 'distance' && !hasGeo
        ? 'createdAt'
        : (query.sort_by ?? 'createdAt');
    const radiusKm = hasGeo
      ? await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM')
      : 0;
    const result = await this.food.listStores({
      page,
      limit,
      search: query.search,
      category: query.category,
      lat: query.lat,
      lng: query.lng,
      radiusKm,
      sortBy,
    });
    return {
      items: result.items.map((store) => ({
        id: store.id,
        name: store.name,
        ownerId: store.ownerId,
        lat: store.lat,
        lng: store.lng,
        category: store.category,
        createdAt: store.createdAt.toISOString(),
        distanceKm: store.distanceKm,
      })),
      page,
      limit,
      total: result.total,
    };
  }

  async getStore(actor: RequestActor, storeId: string): Promise<StoreDetail> {
    await this.requireActiveCustomer(actor.userId);
    await this.ensureSandboxFixtureCatalog();
    const store = await this.food.findStore(storeId);
    if (!store) {
      throw foodError(404, 'FOOD_STORE_NOT_FOUND', 'Store not found');
    }
    return store;
  }

  async getMerchantCatalog(actor: RequestActor): Promise<MerchantCatalogView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const store = await this.food.ensureOwnedStore(actor.userId, 'My Store');
    return {
      ...store,
      sandboxSeed: false,
    };
  }

  async createItem(actor: RequestActor, dto: CreateFoodItemDto): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.food.ensureOwnedStore(actor.userId, 'My Store');
    return this.unwrapCatalog(() =>
      this.food.createItem({
        ownerId: actor.userId,
        name: dto.name,
        priceVnd: dto.priceVnd,
        available: dto.available,
      }),
    );
  }

  async updateItem(
    actor: RequestActor,
    itemId: string,
    dto: UpdateFoodItemDto,
  ): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    if (dto.name === undefined && dto.priceVnd === undefined) {
      throw foodError(400, 'VALIDATION_ERROR', 'Provide name and/or priceVnd to update');
    }
    return this.unwrapCatalog(() =>
      this.food.updateItem({
        ownerId: actor.userId,
        itemId,
        name: dto.name,
        priceVnd: dto.priceVnd,
      }),
    );
  }

  async setItemAvailability(
    actor: RequestActor,
    itemId: string,
    dto: SetFoodItemAvailabilityDto,
  ): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.unwrapCatalog(() =>
      this.food.setItemAvailability({
        ownerId: actor.userId,
        itemId,
        available: dto.available,
      }),
    );
  }

  async updateStoreLocation(
    actor: RequestActor,
    dto: UpdateStoreLocationDto,
  ): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.food.ensureOwnedStore(actor.userId, 'My Store');
    try {
      return await this.food.updateStoreLocation({
        ownerId: actor.userId,
        lat: dto.lat,
        lng: dto.lng,
      });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async place(actor: RequestActor, idempotencyKey: string, dto: PlaceFoodOrderDto): Promise<PublicFoodOrder> {
    await this.requireActiveCustomer(actor.userId);
    await this.probeDropoffMaps(dto.dropoff.label);
    await this.ensureSandboxFixtureCatalog();
    const deliveryFareVnd = await this.quoteDeliveryFare(dto.storeId, dto.dropoff);
    const order = await this.unwrap(() =>
      this.food.place({
        customerId: actor.userId,
        storeId: dto.storeId,
        idempotencyKey,
        items: dto.items,
        dropoff: dto.dropoff,
        deliveryFareVnd,
      }),
    );
    return publish(order);
  }

  async listForCustomer(
    actor: RequestActor,
    page?: number,
    limit?: number,
  ): Promise<PageResult<PublicFoodOrder>> {
    await this.requireActiveCustomer(actor.userId);
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.food.listOrdersForCustomer(actor.userId, safePage, safeLimit);
    return {
      items: result.items.map(publish),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async listReady(
    actor: RequestActor,
    query: DispatchQuery = {},
  ): Promise<ReadyOrderSummary[]> {
    await this.eligibility.requireEligibleDriver(actor.userId);
    if (!(await this.presence.isDispatchEligible(actor.userId))) {
      return [];
    }
    const fallbackLimit = this.config.get('DISPATCH_FALLBACK_LIMIT', { infer: true });
    const radiusKm = await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM');
    const fetchLimit =
      query.lat !== undefined && query.lng !== undefined
        ? Math.max(fallbackLimit * 10, 100)
        : fallbackLimit;
    const orders = await this.food.listReady(fetchLimit);
    return filterByDispatchRadius(
      orders,
      query,
      radiusKm,
      fallbackLimit,
      (order) => order.store ?? order.dropoff,
    );
  }

  async listQueue(actor: RequestActor): Promise<QueueOrderSummary[]> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.food.listQueue(actor.userId);
  }

  async get(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || !(await this.canRead(actor.userId, order))) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    return publish(order);
  }

  /** Socket room join uses the same participant checks as GET /food/orders/:id. */
  async canSubscribe(userId: string, orderId: string): Promise<boolean> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      return false;
    }
    return this.canRead(userId, order);
  }

  /** Status + updatedAt for contact-window checks (chat/voice). */
  async contactMeta(orderId: string): Promise<{ status: string; updatedAt: Date } | null> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      return null;
    }
    return { status: order.status, updatedAt: order.updatedAt };
  }

  /** Known participant userIds for push fan-out (customer + merchant owner + assigned driver). */
  async participantUserIds(orderId: string): Promise<string[]> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      return [];
    }
    const ids = [order.customerId, order.ownerId];
    if (order.assignedDriverId) {
      ids.push(order.assignedDriverId);
    }
    return [...new Set(ids)];
  }

  async accept(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return publish(await this.unwrap(() => this.food.accept(orderId, actor.userId)));
  }

  async markReady(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return publish(await this.unwrap(() => this.food.markReady(orderId, actor.userId)));
  }

  async claim(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.eligibility.requireEligibleDriver(actor.userId);
    const maxConcurrentJobs = await this.settings.getNumber('MAX_CONCURRENT_JOBS_PER_DRIVER');
    return publish(
      await this.unwrap(() => this.food.claim(orderId, actor.userId, maxConcurrentJobs)),
    );
  }

  async pickup(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    return publish(await this.unwrap(() => this.food.pickup(orderId, actor.userId)));
  }

  async deliver(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    const order = await this.unwrap(() => this.food.deliver(orderId, actor.userId));
    await this.ledger.postCodObligation({
      entityType: 'FOOD_ORDER',
      entityId: order.id,
      amountVnd: order.totalVnd,
    });
    await this.recordSandboxCodIntent(order.id, order.totalVnd);
    return publish(order);
  }

  async listForOps(
    page?: number,
    limit?: number,
    filter?: {
      status?: string;
      statuses?: string[];
      q?: string;
      store?: string;
      payment?: string;
      zone?: string;
    },
  ): Promise<PageResult<PublicFoodOrder>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.food.listOrdersPage(
      safePage,
      safeLimit,
      filter,
    );
    return {
      items: result.items.map(publish),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async getForOps(orderId: string): Promise<PublicFoodOrder> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    return publish(order);
  }

  async listStoresForOps(
    page?: number,
    limit?: number,
    filter?: {
      q?: string;
      status?: string;
      sale?: string;
      region?: string;
      category?: string;
      kyb?: string;
    },
  ): Promise<PageResult<OpsStoreListItem>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.food.listStoresPage(safePage, safeLimit, filter);
    return {
      items: result.items.map(toOpsStoreListItem),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async getStoreForOps(storeId: string): Promise<OpsStoreView> {
    const store = await this.food.findStoreForOps(storeId);
    if (!store) {
      throw foodError(404, 'FOOD_STORE_NOT_FOUND', 'Store not found');
    }
    return toOpsStoreView(store);
  }

  async listCatalogModeration(
    query: OpsCatalogModerationQueryDto,
  ): Promise<OpsCatalogModerationPage> {
    return this.food.listCatalogModeration(query);
  }

  async listStoreCategories(
    query: OpsCatalogCategoriesQueryDto,
  ): Promise<OpsCatalogCategoryPage> {
    return this.food.listStoreCategories(query);
  }

  async getStoreCategory(code: string): Promise<OpsCatalogCategoryItem> {
    const category = await this.food.findStoreCategoryByCode(code);
    if (!category) {
      throw foodError(404, 'FOOD_CATEGORY_NOT_FOUND', 'Catalog category not found');
    }
    return category;
  }

  async approveCatalogItem(
    id: string,
  ): Promise<{ success: boolean; id: string; available: boolean; moderationStatus: string }> {
    const updated = await this.food.setCatalogModeration(id, 'APPROVED');
    if (!updated) {
      throw foodError(404, 'FOOD_ITEM_NOT_FOUND', 'Catalog item not found');
    }
    return {
      success: true,
      id: updated.id,
      available: updated.available,
      moderationStatus: updated.moderationStatus,
    };
  }

  async rejectCatalogItem(
    id: string,
  ): Promise<{ success: boolean; id: string; available: boolean; moderationStatus: string }> {
    const updated = await this.food.setCatalogModeration(id, 'REJECTED');
    if (!updated) {
      throw foodError(404, 'FOOD_ITEM_NOT_FOUND', 'Catalog item not found');
    }
    return {
      success: true,
      id: updated.id,
      available: updated.available,
      moderationStatus: updated.moderationStatus,
    };
  }

  async getLedgerJournal(actor: RequestActor, orderId: string) {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || !(await this.canRead(actor.userId, order))) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    return this.ledger.getJournal('FOOD_ORDER', orderId);
  }

  async fail(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    return publish(await this.unwrap(() => this.food.fail(orderId, actor.userId)));
  }

  async cancel(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveCustomer(actor.userId);
    return publish(await this.unwrap(() => this.food.cancel(orderId, actor.userId)));
  }

  async opsCancel(actor: RequestActor, orderId: string, reason: string): Promise<PublicFoodOrder> {
    const result = await this.unwrapIntervene(() =>
      this.food.opsCancel(orderId, actor.userId, reason),
    );
    return publish(result.order);
  }

  /** Clear assignment back to READY when status is ASSIGNED. */
  async opsReassign(actor: RequestActor, orderId: string, reason: string): Promise<PublicFoodOrder> {
    const result = await this.unwrapIntervene(() =>
      this.food.opsReassign(orderId, actor.userId, reason),
    );
    return publish(result.order);
  }

  private async canRead(userId: string, order: FoodOrderView): Promise<boolean> {
    if (order.customerId === userId && (await this.hasActiveGrant(userId, 'CUSTOMER'))) {
      return true;
    }
    if (order.ownerId === userId && (await this.hasActiveGrant(userId, 'MERCHANT'))) {
      return true;
    }
    if (await this.hasActiveGrant(userId, 'DRIVER')) {
      if (order.status === 'READY') {
        return true;
      }
      const assignedVisible =
        order.status === 'ASSIGNED' ||
        order.status === 'PICKED_UP' ||
        order.status === 'DELIVERED' ||
        order.status === 'FAILED';
      return assignedVisible && order.assignedDriverId === userId;
    }
    return false;
  }

  /**
   * Sandbox-only demo seed when the catalog DB is empty.
   * Production never auto-creates stores or merchants.
   */
  private async ensureSandboxFixtureCatalog(): Promise<void> {
    if (await this.food.hasStore() || !this.sandbox()) {
      return;
    }
    const owner = await this.fixtureMerchant();
    if (!owner) {
      return;
    }
    await this.food.createFixtureStore(owner.id, [...FIXTURE_ITEMS]);
  }

  private async fixtureMerchant(): Promise<{ id: string } | null> {
    let user = await this.identity.findUserByPhone(FIXTURE_MERCHANT_PHONE);
    if (!user) {
      try {
        user = await this.identity.createUser({
          email: null,
          phone: FIXTURE_MERCHANT_PHONE,
          displayName: 'Bún Bò Huế',
        });
      } catch (error) {
        if (!(error instanceof UniqueConflictError)) {
          throw error;
        }
        user = await this.identity.findUserByPhone(FIXTURE_MERCHANT_PHONE);
      }
    }
    if (!user) {
      return null;
    }
    const grants = await this.identity.listGrants(user.id);
    if (!grants.some((grant) => grant.role === 'MERCHANT')) {
      try {
        await this.identity.insertGrant(user.id, 'MERCHANT', 'ACTIVE');
      } catch (error) {
        if (!(error instanceof UniqueConflictError)) {
          throw error;
        }
      }
    }
    return user;
  }

  private async requireActiveCustomer(userId: string): Promise<void> {
    if (await this.hasActiveGrant(userId, 'CUSTOMER')) {
      return;
    }
    const grants = await this.identity.listGrants(userId);
    const customerGrant = grants.find((grant) => grant.role === 'CUSTOMER');
    if (!customerGrant && this.sandbox()) {
      try {
        await this.identity.insertGrant(userId, 'CUSTOMER', 'ACTIVE');
      } catch (error) {
        if (!(error instanceof UniqueConflictError)) {
          throw error;
        }
      }
      if (await this.hasActiveGrant(userId, 'CUSTOMER')) {
        return;
      }
    }
    throw foodError(403, 'ROLE_NOT_ACTIVE', 'An active customer role is required');
  }

  private async requireActiveRole(userId: string, role: Extract<RoleName, 'MERCHANT' | 'DRIVER'>): Promise<void> {
    if (!(await this.hasActiveGrant(userId, role))) {
      throw foodError(403, 'ROLE_NOT_ACTIVE', 'An active role is required');
    }
  }

  private async hasActiveGrant(userId: string, role: Extract<RoleName, 'CUSTOMER' | 'MERCHANT' | 'DRIVER'>): Promise<boolean> {
    const grants = await this.identity.listGrants(userId);
    return grants.some((grant) => grant.role === role && grant.status === 'ACTIVE');
  }

  private sandbox(): boolean {
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    return nodeEnv === 'development' || nodeEnv === 'test';
  }

  /**
   * Server-authoritative delivery fare from store→dropoff distance.
   * Client deliveryFareVnd is ignored. Without store coords, uses FOOD_MIN.
   */
  private async quoteDeliveryFare(
    storeId: string,
    dropoff: { lat: number; lng: number },
  ): Promise<number> {
    const minimum = await this.settings.getNumber('FOOD_MIN_DELIVERY_VND');
    const maximum = await this.settings.getNumber('FOOD_MAX_DELIVERY_VND');
    const perKm = await this.settings.getNumber('FOOD_DELIVERY_VND_PER_KM');
    const store = await this.food.findStore(storeId);
    if (!store || store.lat == null || store.lng == null) {
      return minimum;
    }
    const distanceKm = await resolveRouteDistanceKm(
      this.maps,
      { lat: store.lat, lng: store.lng },
      { lat: dropoff.lat, lng: dropoff.lng },
    );
    const quoted = quoteReferenceFareVnd(distanceKm, perKm, minimum);
    return Math.min(maximum, Math.max(minimum, quoted));
  }

  /** Soft MapsPort probe at place; failures do not block checkout. */
  private async probeDropoffMaps(label: string): Promise<void> {
    try {
      await this.maps.geocode(label);
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        return;
      }
      throw error;
    }
  }

  private async recordSandboxCodIntent(entityId: string, amountVnd: number): Promise<void> {
    try {
      await this.payments.createSandboxIntent({
        entityType: 'FOOD_ORDER',
        entityId,
        amountVnd,
        method: 'COD',
      });
    } catch (error) {
      if (error instanceof UnavailablePaymentError) {
        return;
      }
      throw error;
    }
  }

  private async unwrap(work: () => Promise<FoodOrderView>): Promise<FoodOrderView> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private async unwrapIntervene(
    work: () => Promise<OpsFoodInterveneResult>,
  ): Promise<OpsFoodInterveneResult> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private async unwrapNullable(work: () => Promise<FoodOrderView | null>): Promise<FoodOrderView | null> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private async unwrapCatalog(work: () => Promise<StoreItemView>): Promise<StoreItemView> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private asHttp(error: unknown): unknown {
    if (error instanceof FoodRuleError) {
      return foodError(error.status, error.code, error.message);
    }
    return error;
  }
}

function publish(order: FoodOrderView): PublicFoodOrder {
  const { ownerId: _ownerId, updatedAt: _updatedAt, ...publicOrder } = order;
  return publicOrder;
}

function toOpsStoreListItem(store: OpsStoreSummary): OpsStoreListItem {
  return {
    id: store.id,
    name: store.name,
    ownerId: store.ownerId,
    lat: store.lat,
    lng: store.lng,
    category: store.category,
    serviceRegionCode: store.serviceRegionCode ?? null,
    createdAt: store.createdAt.toISOString(),
    itemCount: store.itemCount,
  };
}

function toOpsStoreView(store: OpsStoreDetail): OpsStoreView {
  return {
    ...toOpsStoreListItem(store),
    items: store.items.map((item) => ({ ...item })),
  };
}

export { FoodService as FoodOrderService };

