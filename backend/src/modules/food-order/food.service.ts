import { type OpsDateWindow } from '../operations/ops-date-window.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import { resumeAt, type StoreServiceMode } from './store-service-mode.js';
import type { StoreAcceptSettings } from './store-accept.js';
import type { StoreAvailability } from './store-schedule.js';
import { normalizeSchedule } from './store-schedule.js';
import { maskPersonName } from '../../shared/privacy/pii-mask.js';
import { haversineKm } from '../../shared/geo/haversine.js';
import { Inject, Injectable, Optional } from '@nestjs/common';
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
import type { DriverLocationResponse } from '../identity/driver-presence.repository.js';
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
import { EarningsService } from '../earnings/earnings.service.js';
import { platformFundedDiscountVnd } from '../promotion/voucher-funding.js';
import { PartnerEligibilityService } from '../partner/partner-eligibility.service.js';
import { PAYMENT_PORT } from '../payment/payment.constants.js';
import type { PaymentPort } from '../payment/payment-port.js';
import { UnavailablePaymentError } from '../payment/payment-port.js';
import { quoteReferenceFareVnd } from '../ride/ride-geo.js';
import {
  FIXTURE_MERCHANT_PHONE,
  FOOD_REJECT_NOTE_MAX,
  FOOD_FAIL_NOTE_MAX,
  type FoodFailReason,
  FOOD_REPOSITORY,
  OPEN_FOOD_STATUSES,
  type FoodRejectReason,
} from './food.constants.js';
import {
  FOOD_STORE_BROWSE_MAX_LIMIT,
  type ListFoodStoresQueryDto,
  type CreateFoodItemDto,
  type ReplaceFoodItemOptionsDto,
  type OpsCatalogCategoriesQueryDto,
  type OpsCatalogModerationQueryDto,
  type PlaceFoodOrderDto,
  type SetFoodItemAvailabilityDto,
  type UpdateFoodItemDto,
  type UpdateStoreLocationDto,
  type UpdateStoreProfileDto,
  type UpdateStoreServiceModeDto,
  type UpdateStoreAcceptSettingsDto,
  type UpdateStoreHoursDto,
} from './food.dto.js';
import { VoucherRejectedError } from '../promotion/promotion-redemption.js';
import { FoodRuleError, foodError } from './food.error.js';
import { activeRegionCodeAt } from '../service-area/service-regions.js';
import {
  FOOD_ORDER_CODE_STORE,
  type FoodOrderCodeKind,
  type FoodOrderCodeStore,
} from './food-order-code.js';
import { generatePickupCode, pickupCodeMatches } from '../ride/ride-pickup-code.js';
import {
  PhaseRouteCache,
  RoutingService,
  toRouteGeometryView,
  UNAVAILABLE_ROUTE_GEOMETRY,
  routePhaseForFood,
  type RouteGeometryView,
  type RoutePhase,
} from '../routing/index.js';
import type {
  MerchantSettlementView,
  FoodDriverHistoryWindow,
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
  FoodOrderChangeView,
} from './food.repository.js';
import { FOOD_CHANGE_EDITABLE_STATUSES } from './food.repository.js';

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
  /** M024/M023 live state (DEC-PROD-026/027) — Admin shows it as the store's sale status. */
  serviceMode: StoreServiceMode;
  serviceModeUntil: string | null;
  openNow: boolean;
  closedReason: StoreAvailability['closedReason'];
  /** M022 (DEC-PROD-028). */
  acceptSettings: StoreAcceptSettings;
  estimatedPrepMinutes: number;
};

export type OpsStoreView = OpsStoreListItem & {
  items: StoreItemView[];
};

const FIXTURE_ITEMS = [
  { name: 'Bún bò đặc biệt', priceVnd: 60_000 },
  { name: 'Trà tắc', priceVnd: 25_000 },
] as const;

/** Merchant edit as sent to clients. */
export type PublicFoodOrderChange = Omit<FoodOrderChangeView, 'expiresAt' | 'respondedAt' | 'createdAt'> & {
  expiresAt: string;
  respondedAt: string | null;
  createdAt: string;
};

export function publishChange(change: FoodOrderChangeView): PublicFoodOrderChange {
  return {
    ...change,
    lines: change.lines.map((line) => ({ ...line })),
    expiresAt: change.expiresAt.toISOString(),
    respondedAt: change.respondedAt?.toISOString() ?? null,
    createdAt: change.createdAt.toISOString(),
  };
}

export type PublicFoodOrder = Omit<
  FoodOrderView,
  'ownerId' | 'updatedAt' | 'voucherSponsor' | 'estimatedReadyAt' | 'pickedUpAt'
> & {
  /** Pickup time as ISO; the fail sheet uses it for the minimum wait. */
  pickedUpAt: string | null;
  /** placedAt + prepMinutes as ISO; the customer tracking screen shows it while cooking. */
  estimatedReadyAt: string | null;
  /** Last status change as ISO (delivery time once DELIVERED); history/receipts show it. */
  updatedAt: string;
  /** DEC-PROD-036: customer only, while ASSIGNED/PICKED_UP and FOOD_DELIVERY_CODE_REQUIRED. */
  deliveryCode?: string;
  /** DEC-PROD-036: store owner only, while ASSIGNED and FOOD_HANDOVER_CODE_REQUIRED. */
  handoverCode?: string;
  /** Customer/store only, while the customer has to answer a merchant edit. */
  pendingChange?: PublicFoodOrderChange;
  /** Ops detail only — the latest merchant edit in any status (audit view). */
  latestChange?: PublicFoodOrderChange;
  /**
   * Cash the driver pays the store at pickup
   * (subtotal minus the merchant-funded part of the voucher) and collects at the door.
   */
  cashPlan?: { payMerchantVnd: number; collectFromCustomerVnd: number; platformOwesDriverVnd: number };
  /** Road geometry when store pickup coords exist (same Nest ROUTING_PROVIDER). */
  route?: RouteGeometryView;
  /** APPROACH while ASSIGNED (courier → store), TRIP once PICKED_UP. */
  routePhase?: RoutePhase;
  /** Courier→store road leg (APPROACH only, needs a fresh fix). No straight-line fallback. */
  approachRoute?: RouteGeometryView;
};

export const MERCHANT_STATS_MAX_DAYS = 30;
/** Statements cover at most 31 ICT days. */
export const MERCHANT_STATEMENT_MAX_DAYS = 31;

type StatementTotals = {
  orderCount: number;
  /** Food subtotal before vouchers. */
  grossVnd: number;
  /** Voucher share the store funds (it received less cash at pickup). */
  merchantFundedVnd: number;
  /** Cash the store received from couriers at pickup. */
  cashReceivedVnd: number;
  /** DealGo commission (snapshot at delivery); the store owes this to DealGo. */
  commissionVnd: number;
  /** cashReceivedVnd − commissionVnd: what the store keeps. */
  netVnd: number;
};

/** (OPEN-018) Per-store commission statement by Vietnam day. */
export type MerchantStatementView = {
  timezone: 'Asia/Ho_Chi_Minh';
  storeId: string;
  from: string;
  to: string;
  commissionPercentNow: number;
  /** (DEC-PROD-062) MERCHANT_SETTLEMENT_CYCLE_DAYS — default statement range and cadence. */
  settlementCycleDays: number;
  totals: StatementTotals;
  days: Array<StatementTotals & { date: string }>;
  settlements: MerchantSettlementView[];
  /** Commission in this window not yet covered by a recorded settlement. */
  unsettledCommissionVnd: number;
};

type StatsDay = { deliveredCount: number; cancelledCount: number; salesVnd: number };

export type MerchantStatsView = {
  timezone: 'Asia/Ho_Chi_Minh';
  days: number;
  today: StatsDay & { date: string; openCount: number };
  totals: StatsDay;
  /** Oldest → newest, one row per day including today. */
  series: Array<StatsDay & { date: string }>;
  topItems: Array<{ name: string; quantity: number }>;
};

/** YYYY-MM-DD of the instant in Vietnam time (UTC+7, no DST). */
function vnDayKey(at: Date): string {
  return new Date(at.getTime() + 7 * 3_600_000).toISOString().slice(0, 10);
}

/** Merchant queue row: counterpart names masked (given name + family initial), no ids. */
export type MerchantQueueOrder = Omit<QueueOrderSummary, 'customerId' | 'assignedDriverId'> & {
  customerName: string | null;
  driverName: string | null;
};

export type PublicStoreDetail = Omit<StoreDetail, 'acceptSettings'>;

export type MerchantCatalogView = StoreDetail & {
  sandboxSeed: boolean;
};

const FOOD_TRACKING_STATUSES: ReadonlySet<string> = new Set(['ASSIGNED', 'PICKED_UP']);

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
    private readonly earnings: EarningsService,
    private readonly routing: RoutingService,
    @Inject(FOOD_ORDER_CODE_STORE) private readonly codes: FoodOrderCodeStore,
    @Optional() private readonly phaseRoutes?: PhaseRouteCache,
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
        serviceMode: store.serviceMode,
        openNow: store.openNow,
        closedReason: store.closedReason,
        imageUrl: store.imageUrl,
      })),
      page,
      limit,
      total: result.total,
    };
  }

  async getStore(actor: RequestActor, storeId: string): Promise<PublicStoreDetail> {
    await this.requireActiveCustomer(actor.userId);
    await this.ensureSandboxFixtureCatalog();
    const store = await this.food.findStore(storeId);
    if (!store) {
      throw foodError(404, 'FOOD_STORE_NOT_FOUND', 'Store not found');
    }
    // Capacity and accept mode are the merchant's business; customers only see the prep estimate.
    const { acceptSettings: _acceptSettings, ...publicStore } = store;
    return publicStore;
  }

  async getMerchantCatalog(actor: RequestActor): Promise<MerchantCatalogView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const store = await this.ownedStore(actor.userId);
    return {
      ...store,
      sandboxSeed: false,
    };
  }

  async createItem(actor: RequestActor, dto: CreateFoodItemDto): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    return this.unwrapCatalog(() =>
      this.food.createItem({
        ownerId: actor.userId,
        name: dto.name,
        priceVnd: dto.priceVnd,
        available: dto.available,
        description: dto.description,
        prepMinutes: dto.prepMinutes,
        imageUrl: dto.imageUrl,
        menuCategoryId: dto.menuCategoryId,
      }),
    );
  }

  async findItemImageUrl(itemId: string): Promise<string | null> {
    return this.food.findItemImageUrl(itemId);
  }

  async findItemImageUrls(itemId: string): Promise<string[]> {
    return this.food.findItemImageUrls(itemId);
  }

  async updateItem(
    actor: RequestActor,
    itemId: string,
    dto: UpdateFoodItemDto,
  ): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    if (
      dto.name === undefined &&
      dto.priceVnd === undefined &&
      dto.available === undefined &&
      dto.description === undefined &&
      dto.prepMinutes === undefined &&
      dto.imageUrl === undefined &&
      dto.menuCategoryId === undefined
    ) {
      throw foodError(400, 'VALIDATION_ERROR', 'Provide at least one field to update');
    }
    return this.unwrapCatalog(() =>
      this.food.updateItem({
        ownerId: actor.userId,
        itemId,
        name: dto.name,
        priceVnd: dto.priceVnd,
        available: dto.available,
        description: dto.description,
        prepMinutes: dto.prepMinutes,
        imageUrl: dto.imageUrl,
        menuCategoryId: dto.menuCategoryId,
      }),
    );
  }

  async replaceItemOptions(
    actor: RequestActor,
    itemId: string,
    dto: ReplaceFoodItemOptionsDto,
  ): Promise<StoreItemView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.unwrapCatalog(() =>
      this.food.replaceItemOptions({
        ownerId: actor.userId,
        itemId,
        groups: dto.groups.map((group) => ({
          id: group.id,
          name: group.name,
          minSelect: group.minSelect,
          maxSelect: group.maxSelect,
          options: group.options.map((option) => ({
            id: option.id,
            name: option.name,
            priceDeltaVnd: option.priceDeltaVnd,
            available: option.available,
            maxQuantity: option.maxQuantity,
          })),
        })),
      }),
    );
  }

  async listMenuCategories(actor: RequestActor) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    return this.food.listMenuCategories(actor.userId);
  }

  async createMenuCategory(actor: RequestActor, dto: import('./food.dto.js').UpsertMenuCategoryDto) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    return this.unwrapCatalog(() =>
      this.food.createMenuCategory({
        ownerId: actor.userId,
        name: dto.name,
        description: dto.description,
      }),
    );
  }

  async updateMenuCategory(
    actor: RequestActor,
    categoryId: string,
    dto: import('./food.dto.js').UpsertMenuCategoryDto,
  ) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.unwrapCatalog(() =>
      this.food.updateMenuCategory({
        ownerId: actor.userId,
        categoryId,
        name: dto.name,
        description: dto.description,
      }),
    );
  }

  async deleteMenuCategory(actor: RequestActor, categoryId: string) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.unwrapCatalog(() => this.food.deleteMenuCategory(actor.userId, categoryId));
  }

  async reorderMenuCategories(actor: RequestActor, orderedIds: string[]) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.unwrapCatalog(() => this.food.reorderMenuCategories(actor.userId, orderedIds));
  }

  async merchantHistory(actor: RequestActor, query: import('./food.dto.js').MerchantHistoryQueryDto) {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.max(1, Math.min(50, query.limit ?? 20));
    const result = await this.food.listMerchantHistory({
      ownerId: actor.userId,
      page,
      limit,
      tab: query.tab,
      q: query.q,
      from: query.from ? new Date(query.from) : undefined,
      to: query.to ? new Date(query.to) : undefined,
    });
    return {
      ...result,
      items: result.items.map((row) => ({
        ...row,
        createdAt: row.createdAt.toISOString(),
        finishedAt: row.finishedAt.toISOString(),
      })),
    };
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

  /** M030 (DEC-PROD-045): rename the store; the logo goes through StoreLogoService. */
  async updateStoreProfile(actor: RequestActor, dto: UpdateStoreProfileDto): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    try {
      return await this.food.updateStoreProfile({ ownerId: actor.userId, name: dto.name });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** The merchant's own store (created on first use), for the logo pipeline. */
  async ownedStoreForProfile(actor: RequestActor): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return this.food.ensureOwnedStore(actor.userId, 'My Store');
  }

  async setStoreLogo(actor: RequestActor, logoUrl: string | null): Promise<StoreDetail> {
    try {
      return await this.food.updateStoreProfile({ ownerId: actor.userId, logoUrl });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async findStoreLogoUrl(storeId: string): Promise<string | null> {
    return this.food.findStoreLogoUrl(storeId);
  }

  async updateStoreLocation(
    actor: RequestActor,
    dto: UpdateStoreLocationDto,
  ): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    await this.assertInServiceZone(dto);
    try {
      return await this.food.updateStoreLocation({
        ownerId: actor.userId,
        lat: dto.lat,
        lng: dto.lng,
        addressLabel: dto.addressLabel,
      });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** DEC-PROD-027 — M023 weekly hours, closed days and last-order cut-off. */
  async updateStoreHours(actor: RequestActor, dto: UpdateStoreHoursDto): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    const normalized = normalizeSchedule(dto);
    if (!normalized.ok) {
      throw foodError(400, 'FOOD_HOURS_INVALID', normalized.problem);
    }
    try {
      return await this.food.updateStoreSchedule({
        ownerId: actor.userId,
        schedule: normalized.schedule,
      });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** DEC-PROD-028 — M022 manual/auto accept, kitchen cap and default prep time. */
  async updateStoreAcceptSettings(
    actor: RequestActor,
    dto: UpdateStoreAcceptSettingsDto,
  ): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    await this.ownedStore(actor.userId);
    try {
      return await this.food.updateStoreAcceptSettings({
        ownerId: actor.userId,
        acceptMode: dto.acceptMode,
        maxActiveOrders: dto.maxActiveOrders ?? null,
        defaultPrepMinutes: dto.defaultPrepMinutes,
        lastOrderMinutes: dto.lastOrderMinutes,
      });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** DEC-PROD-026 — M024 store intake mode. */
  async updateStoreServiceMode(
    actor: RequestActor,
    dto: UpdateStoreServiceModeDto,
    now: Date = new Date(),
  ): Promise<StoreDetail> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const store = await this.ownedStore(actor.userId);
    if (dto.mode !== 'PAUSED' && (store.lat == null || store.lng == null)) {
      // A store opens for orders only once it is pinned on the map.
      throw foodError(409, 'FOOD_STORE_LOCATION_REQUIRED', 'Pin the store on the map before opening');
    }
    try {
      return await this.food.updateStoreServiceMode({
        ownerId: actor.userId,
        mode: dto.mode,
        until: resumeAt(dto.mode, dto.resumeAfterMinutes, now),
        busyExtraMinutes: dto.busyExtraMinutes,
      });
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  async place(actor: RequestActor, idempotencyKey: string, dto: PlaceFoodOrderDto): Promise<PublicFoodOrder> {
    await this.requireActiveCustomer(actor.userId);
    await this.probeDropoffMaps(dto.dropoff.label);
    await this.ensureSandboxFixtureCatalog();
    await this.assertWithinDeliveryRange(dto.storeId, dto.dropoff);
    const deliveryFareVnd = await this.quoteDeliveryFare(dto.storeId, dto.dropoff);
    const order = await this.unwrap(() =>
      this.food.place({
        customerId: actor.userId,
        storeId: dto.storeId,
        idempotencyKey,
        items: dto.items,
        dropoff: dto.dropoff,
        deliveryFareVnd,
        voucherCode: dto.voucherCode?.trim() || undefined,
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
  ): Promise<Array<ReadyOrderSummary & { route: RouteGeometryView }>> {
    await this.eligibility.requireEligibleDriver(actor.userId);
    const requirePresence = await this.settings.getBoolean('DISPATCH_REQUIRE_FRESH_PRESENCE');
    if (!(await this.presence.isDispatchEligible(actor.userId, 'FOOD', requirePresence))) {
      return [];
    }
    // Over the debt limit → no new cash jobs.
    await this.earnings.assertUnderDebtLimit(actor.userId);
    const now = new Date();
    // Radius from query coords or the fresh presence fix; no fix → 409.
    const origin = await this.presence.dispatchOrigin(actor.userId, query, now, requirePresence);
    const fallbackLimit = this.config.get('DISPATCH_FALLBACK_LIMIT', { infer: true });
    const radiusKm = await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM');
    const early = { leadMinutes: await this.settings.getNumber('FOOD_EARLY_ASSIGN_LEAD_MINUTES'), now };
    const orders = origin
      ? await this.food.listReady(Math.max(fallbackLimit * 10, 100), { ...origin, radiusKm }, early)
      : await this.food.listReady(fallbackLimit, undefined, early);
    const pickupPoint = (order: ReadyOrderSummary) => order.store ?? order.dropoff;
    const filtered = filterByDispatchRadius(orders, origin ?? {}, radiusKm, fallbackLimit, pickupPoint);
    const visible = origin
      ? [...filtered].sort(
          (a, b) => haversineKm(origin, pickupPoint(a)) - haversineKm(origin, pickupPoint(b)),
        )
      : filtered;
    // Road geometry pickup→dropoff (DEC-PROD-045) so the driver map draws the
    // real street path; no pickup point or lookup failure → available=false (no line).
    return Promise.all(
      visible.map(async (order) => ({
        ...order,
        route: order.pickup
          ? await this.lookupRoute(order.pickup, order.dropoff)
          : { ...UNAVAILABLE_ROUTE_GEOMETRY, provider: this.routing.provider() },
      })),
    );
  }

  async listQueue(actor: RequestActor): Promise<MerchantQueueOrder[]> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const rows = await this.food.listQueue(actor.userId);
    const names = new Map<string, Promise<string | null>>();
    const nameOf = (userId: string | null): Promise<string | null> => {
      if (!userId) {
        return Promise.resolve(null);
      }
      let pending = names.get(userId);
      if (!pending) {
        pending = this.identity
          .findUserById(userId)
          .then((user) => maskPersonName(user?.displayName));
        names.set(userId, pending);
      }
      return pending;
    };
    return Promise.all(
      rows.map(async ({ customerId, assignedDriverId, ...row }) => ({
        ...row,
        customerName: await nameOf(customerId),
        driverName: await nameOf(assignedDriverId),
      })),
    );
  }

  /**
   * Merchant sales summary bucketed by Vietnam calendar day (UTC+7, no DST). Sales are item
   * subtotals of DELIVERED orders (before delivery fee, platform fee and vouchers).
   */
  async merchantStats(actor: RequestActor, days = 7): Promise<MerchantStatsView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const window = Math.min(Math.max(Math.trunc(days), 1), MERCHANT_STATS_MAX_DAYS);
    const now = new Date();
    const todayKey = vnDayKey(now);
    const startOfToday = new Date(`${todayKey}T00:00:00+07:00`);
    const since = new Date(startOfToday.getTime() - (window - 1) * 86_400_000);
    const rows = await this.food.merchantStats(actor.userId, since, 5);
    const buckets = new Map<string, { deliveredCount: number; cancelledCount: number; salesVnd: number }>();
    for (let i = 0; i < window; i += 1) {
      buckets.set(vnDayKey(new Date(since.getTime() + i * 86_400_000 + 3_600_000)), {
        deliveredCount: 0,
        cancelledCount: 0,
        salesVnd: 0,
      });
    }
    for (const row of rows.finished) {
      const bucket = buckets.get(vnDayKey(row.finishedAt));
      if (!bucket) {
        continue;
      }
      if (row.status === 'DELIVERED') {
        bucket.deliveredCount += 1;
        bucket.salesVnd += row.subtotalVnd;
      } else {
        bucket.cancelledCount += 1;
      }
    }
    const series = [...buckets.entries()].map(([date, value]) => ({ date, ...value }));
    const today = buckets.get(todayKey) ?? { deliveredCount: 0, cancelledCount: 0, salesVnd: 0 };
    return {
      timezone: 'Asia/Ho_Chi_Minh',
      days: window,
      today: { date: todayKey, ...today, openCount: rows.openCount },
      totals: series.reduce(
        (acc, day) => ({
          deliveredCount: acc.deliveredCount + day.deliveredCount,
          cancelledCount: acc.cancelledCount + day.cancelledCount,
          salesVnd: acc.salesVnd + day.salesVnd,
        }),
        { deliveredCount: 0, cancelledCount: 0, salesVnd: 0 },
      ),
      series,
      topItems: rows.topItems,
    };
  }

  /**
   * The merchant's own commission statement. Defaults to the last
   * MERCHANT_SETTLEMENT_CYCLE_DAYS ICT days (DRAFT 7, GrabFood pays weekly).
   */
  async merchantStatement(actor: RequestActor, from?: string, to?: string): Promise<MerchantStatementView> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const store = await this.food.findStoreByOwner(actor.userId);
    if (!store) {
      throw foodError(404, 'FOOD_STORE_NOT_FOUND', 'Store not found');
    }
    return this.statement(store.id, from, to);
  }

  async opsMerchantStatement(storeId: string, from?: string, to?: string): Promise<MerchantStatementView> {
    return this.statement(storeId, from, to);
  }

  /**
   * Ops records that the store paid the commission for a closed ICT period.
   * Totals are recomputed server-side; overlapping periods are rejected.
   */
  async opsRecordMerchantSettlement(
    actor: RequestActor,
    storeId: string,
    input: { from: string; to: string; reason: string; note?: string },
  ): Promise<MerchantSettlementView> {
    if (input.to >= vnDayKey(new Date())) {
      throw foodError(409, 'FOOD_SETTLEMENT_PERIOD_OPEN', 'Only closed days (before today, ICT) can be settled');
    }
    const view = await this.statement(storeId, input.from, input.to);
    return this.unwrapCatalog(() =>
      this.food.recordMerchantSettlement({
        storeId,
        periodStart: view.from,
        periodEnd: view.to,
        orderCount: view.totals.orderCount,
        grossVnd: view.totals.grossVnd,
        merchantFundedVnd: view.totals.merchantFundedVnd,
        commissionVnd: view.totals.commissionVnd,
        netVnd: view.totals.netVnd,
        actorUserId: actor.userId,
        note: input.note?.trim() ? input.note.trim().slice(0, 500) : null,
        reason: input.reason,
      }),
    );
  }

  private async statement(storeId: string, from?: string, to?: string): Promise<MerchantStatementView> {
    const today = vnDayKey(new Date());
    const toKey = to ?? today;
    const cycleDays = Math.max(
      1,
      Math.min(MERCHANT_STATEMENT_MAX_DAYS, Math.round(await this.settings.getNumber('MERCHANT_SETTLEMENT_CYCLE_DAYS'))),
    );
    const fromKey =
      from ?? vnDayKey(new Date(Date.parse(`${toKey}T12:00:00+07:00`) - (cycleDays - 1) * 86_400_000));
    const start = Date.parse(`${fromKey}T00:00:00+07:00`);
    const end = Date.parse(`${toKey}T00:00:00+07:00`) + 86_400_000;
    if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
      throw foodError(400, 'FOOD_STATEMENT_RANGE_INVALID', 'from must be on or before to (YYYY-MM-DD)');
    }
    if ((end - start) / 86_400_000 > MERCHANT_STATEMENT_MAX_DAYS) {
      throw foodError(400, 'FOOD_STATEMENT_RANGE_INVALID', `At most ${MERCHANT_STATEMENT_MAX_DAYS} days`);
    }
    const sharedPercent = await this.settings.getNumber('VOUCHER_SHARED_PLATFORM_PERCENT');
    const rows = await this.food.deliveredForStatement(storeId, new Date(start), new Date(end));
    const empty = (): StatementTotals => ({
      orderCount: 0,
      grossVnd: 0,
      merchantFundedVnd: 0,
      cashReceivedVnd: 0,
      commissionVnd: 0,
      netVnd: 0,
    });
    const days = new Map<string, StatementTotals>();
    for (let at = start; at < end; at += 86_400_000) {
      days.set(vnDayKey(new Date(at + 3_600_000)), empty());
    }
    const totals = empty();
    for (const row of rows) {
      const funded =
        row.merchantCashVnd != null
          ? Math.max(0, row.subtotalVnd - row.merchantCashVnd)
          : Math.max(0, row.discountVnd - platformFundedDiscountVnd(row.discountVnd, row.voucherSponsor, sharedPercent));
      const commission = row.commissionVnd ?? 0;
      for (const bucket of [days.get(vnDayKey(row.deliveredAt)), totals]) {
        if (!bucket) {
          continue;
        }
        bucket.orderCount += 1;
        bucket.grossVnd += row.subtotalVnd;
        bucket.merchantFundedVnd += funded;
        bucket.cashReceivedVnd += row.subtotalVnd - funded;
        bucket.commissionVnd += commission;
        bucket.netVnd += row.subtotalVnd - funded - commission;
      }
    }
    const settlements = (await this.food.listMerchantSettlements(storeId, 50)).filter(
      (row) => row.periodStart <= toKey && row.periodEnd >= fromKey,
    );
    let settledCommission = 0;
    for (const [date, day] of days) {
      if (settlements.some((row) => row.periodStart <= date && row.periodEnd >= date)) {
        settledCommission += day.commissionVnd;
      }
    }
    return {
      timezone: 'Asia/Ho_Chi_Minh',
      storeId,
      from: fromKey,
      to: toKey,
      commissionPercentNow: await this.settings.getNumber('FOOD_MERCHANT_COMMISSION_PERCENT'),
      settlementCycleDays: cycleDays,
      totals,
      days: [...days.entries()].map(([date, value]) => ({ date, ...value })),
      settlements,
      unsettledCommissionVnd: Math.max(0, totals.commissionVnd - settledCommission),
    };
  }

  async get(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || !(await this.canRead(actor.userId, order))) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    const view = publish(order);
    if (order.assignedDriverId === actor.userId) {
      view.cashPlan = await this.cashPlan(order);
    }
    // DEC-PROD-036: each code goes only to the party who hands it to the driver.
    if (
      order.customerId === actor.userId &&
      (order.status === 'ASSIGNED' || order.status === 'PICKED_UP') &&
      (await this.settings.getBoolean('FOOD_DELIVERY_CODE_REQUIRED'))
    ) {
      const { code } = await this.codes.ensure(order.id, 'DELIVERY', generatePickupCode());
      view.deliveryCode = code;
    }
    if (
      order.ownerId === actor.userId &&
      order.status === 'ASSIGNED' &&
      (await this.settings.getBoolean('FOOD_HANDOVER_CODE_REQUIRED'))
    ) {
      const { code } = await this.codes.ensure(order.id, 'HANDOVER', generatePickupCode());
      view.handoverCode = code;
    }
    if (order.pickup) {
      view.route = await this.lookupRoute(order.pickup, order.dropoff);
      const phase = order.assignedDriverId ? routePhaseForFood(order.status) : null;
      if (phase) {
        view.routePhase = phase;
        if (phase === 'APPROACH') {
          // Cached approach leg (shared with the realtime push): no Directions call per GET.
          const now = new Date();
          const cached = this.phaseRoutes?.forPhase('FoodOrder', order.id, 'APPROACH', now.getTime());
          const fix = cached ? null : await this.presence.freshLocation(order.assignedDriverId!, now);
          if (cached) {
            view.approachRoute = cached.route;
          } else if (fix) {
            view.approachRoute = await this.lookupRoute({ lat: fix.lat, lng: fix.lng }, order.pickup);
            this.phaseRoutes?.set('FoodOrder', order.id, { phase: 'APPROACH', route: view.approachRoute, at: now.getTime() });
          } else {
            view.approachRoute = { ...UNAVAILABLE_ROUTE_GEOMETRY, provider: this.routing.provider() };
          }
        }
      }
    }
    if (
      (order.customerId === actor.userId || order.ownerId === actor.userId) &&
      FOOD_CHANGE_EDITABLE_STATUSES.includes(order.status)
    ) {
      const change = await this.food.latestChange(order.id);
      if (change?.status === 'PENDING') {
        view.pendingChange = publishChange(change);
      }
    }
    return view;
  }

  private async lookupRoute(
    from: { lat: number; lng: number },
    to: { lat: number; lng: number },
  ): Promise<RouteGeometryView> {
    try {
      return toRouteGeometryView(await this.routing.route(from, to));
    } catch {
      return { ...UNAVAILABLE_ROUTE_GEOMETRY, provider: this.routing.provider() };
    }
  }

  /** DEC-PROD-031: the customer sees the courier's fresh position while the order is on its way. */
  async driverLocation(actor: RequestActor, orderId: string): Promise<DriverLocationResponse> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || order.customerId !== actor.userId) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    if (!order.assignedDriverId || !FOOD_TRACKING_STATUSES.has(order.status)) {
      return { location: null };
    }
    const location = await this.presence.freshLocation(order.assignedDriverId, new Date());
    return {
      location: location
        ? { lat: location.lat, lng: location.lng, at: location.at.toISOString() }
        : null,
    };
  }

  /** Who may rate the order and whom: used by the rating module. */
  async ratingSubject(
    orderId: string,
  ): Promise<{
    customerId: string;
    driverId: string | null;
    storeId: string;
    status: string;
    finishedAt: Date;
  } | null> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      return null;
    }
    return {
      customerId: order.customerId,
      driverId: order.assignedDriverId,
      storeId: order.storeId,
      status: order.status,
      finishedAt: order.updatedAt,
    };
  }

  /** Raw finished jobs for the driver-history module (auth is checked there). */
  listFinishedForDriver(driverId: string, window: FoodDriverHistoryWindow): Promise<FoodOrderView[]> {
    return this.food.listFinishedForDriver(driverId, window);
  }

  countFinishedForDrivers(driverIds: readonly string[]): Promise<Map<string, DriverJobCounts>> {
    return this.food.countFinishedForDrivers(driverIds);
  }

  /** Live-location room: same rule as GET /food/orders/:id/driver-location (customer only). */
  async canSubscribeLocation(userId: string, orderId: string): Promise<boolean> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    return Boolean(order && order.customerId === userId);
  }

  /** Orders whose customer should receive this courier's live fix. */
  /** Realtime phase-route: legs for an order the courier is serving, or null. */
  async routeLegsForDriver(
    orderId: string,
    driverId: string,
  ): Promise<{ phase: RoutePhase; pickup: { lat: number; lng: number }; dropoff: { lat: number; lng: number } } | null> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || order.assignedDriverId !== driverId || !order.pickup) return null;
    const phase = routePhaseForFood(order.status);
    return phase ? { phase, pickup: order.pickup, dropoff: order.dropoff } : null;
  }

  /** Relaunch resume (DEC-PROD-057): the customer's newest order that is still open. */
  async activeOrderForCustomer(customerId: string): Promise<{ id: string; status: string } | null> {
    const ids = (await this.food.listIdsForCustomerInStatuses?.(customerId, OPEN_FOOD_STATUSES)) ?? [];
    for (const id of ids) {
      const order = await this.unwrapNullable(() => this.food.findOrder(id));
      if (order && order.customerId === customerId && (OPEN_FOOD_STATUSES as readonly string[]).includes(order.status)) {
        return { id: order.id, status: order.status };
      }
    }
    return null;
  }

  async trackingOrderIdsForDriver(driverId: string): Promise<string[]> {
    return (await this.food.listIdsForDriverInStatuses?.(driverId, [...FOOD_TRACKING_STATUSES])) ?? [];
  }

  /** Socket room join uses the same participant checks as GET /food/orders/:id. */
  async canSubscribe(userId: string, orderId: string): Promise<boolean> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order) {
      return false;
    }
    return this.canRead(userId, order);
  }

  /** Merchant kitchen board: only the active store owner may join store:{id}. */
  async canSubscribeStore(userId: string, storeId: string): Promise<boolean> {
    const store = await this.food.findStore(storeId);
    if (!store || store.ownerId !== userId) {
      return false;
    }
    return this.hasActiveGrant(userId, 'MERCHANT');
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
  async participantRoles(
    orderId: string,
  ): Promise<{ customerId: string; merchantId: string; driverId: string | null } | null> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    return order
      ? { customerId: order.customerId, merchantId: order.ownerId, driverId: order.assignedDriverId ?? null }
      : null;
  }

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

  async reject(
    actor: RequestActor,
    orderId: string,
    input: { reasonCode: FoodRejectReason; note?: string },
  ): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const note = input.note?.trim() ? input.note.trim().slice(0, FOOD_REJECT_NOTE_MAX) : null;
    if (input.reasonCode === 'OTHER' && !note) {
      throw foodError(400, 'FOOD_REJECT_NOTE_REQUIRED', 'Describe the reason when choosing OTHER');
    }
    return publish(
      await this.unwrap(() =>
        this.food.reject(orderId, actor.userId, { code: input.reasonCode, note }),
      ),
    );
  }

  /**
   * The store lowers quantities or
   * removes out-of-stock lines; the customer has FOOD_ORDER_CHANGE_RESPONSE_MINUTES to accept
   * (new total) or decline (order cancelled, no fee, voucher returned). Silence cancels it too.
   */
  async proposeChange(
    actor: RequestActor,
    orderId: string,
    input: { reasonCode: string; note?: string; lines: { lineId: string; toQuantity: number }[] },
  ): Promise<{ order: PublicFoodOrder; change: PublicFoodOrderChange }> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    const note = input.note?.trim() ? input.note.trim().slice(0, FOOD_REJECT_NOTE_MAX) : null;
    if (input.reasonCode === 'OTHER' && !note) {
      throw foodError(400, 'FOOD_REJECT_NOTE_REQUIRED', 'Describe the reason when choosing OTHER');
    }
    const minutes = await this.settings.getNumber('FOOD_ORDER_CHANGE_RESPONSE_MINUTES');
    const expiresAt = new Date(Date.now() + Math.max(1, minutes) * 60_000);
    const result = await this.unwrap(() =>
      this.food.proposeChange({
        orderId,
        ownerId: actor.userId,
        reasonCode: input.reasonCode,
        note,
        lines: input.lines,
        expiresAt,
      }),
    );
    const order = publish(result.order);
    order.pendingChange = publishChange(result.change);
    return { order, change: publishChange(result.change) };
  }

  /** Latest change of an order (customer or store owner). */
  async latestChange(actor: RequestActor, orderId: string): Promise<PublicFoodOrderChange | null> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || (order.customerId !== actor.userId && order.ownerId !== actor.userId)) {
      throw foodError(404, 'FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    const change = await this.food.latestChange(orderId);
    return change ? publishChange(change) : null;
  }

  async respondChange(
    actor: RequestActor,
    orderId: string,
    changeId: string,
    accept: boolean,
  ): Promise<{ order: PublicFoodOrder; change: PublicFoodOrderChange }> {
    await this.requireActiveCustomer(actor.userId);
    const result = await this.unwrap(() =>
      this.food.respondChange(orderId, actor.userId, changeId, accept, new Date()),
    );
    return { order: publish(result.order), change: publishChange(result.change) };
  }

  async markReady(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'MERCHANT');
    return publish(await this.unwrap(() => this.food.markReady(orderId, actor.userId)));
  }

  async claim(actor: RequestActor, orderId: string): Promise<PublicFoodOrder> {
    await this.eligibility.requireEligibleDriver(actor.userId);
    if (!(await this.presence.isDispatchEligible(actor.userId, 'FOOD'))) {
      throw foodError(409, 'DRIVER_OFFLINE', 'Go online for food orders to claim one');
    }
    await this.earnings.assertUnderDebtLimit(actor.userId);
    const maxConcurrentJobs = await this.settings.getNumber('MAX_CONCURRENT_JOBS_PER_DRIVER');
    const early = {
      leadMinutes: await this.settings.getNumber('FOOD_EARLY_ASSIGN_LEAD_MINUTES'),
      now: new Date(),
    };
    return publish(
      await this.unwrap(() => this.food.claim(orderId, actor.userId, maxConcurrentJobs, early)),
    );
  }

  /**
   * Online food drivers near a READY, unassigned order, nearest first (job push audience; also
   * drivers whose app is backgrounded or killed, see DRIVER_PUSH_LOCATION_MAX_AGE_MS).
   */
  async readyAudience(orderId: string, now = new Date()): Promise<{
    driverIds: string[];
    order: { id: string; deliveryFareVnd: number; storeName: string | null; dropoffLabel: string };
    ttlSeconds: number;
  } | null> {
    const order = await this.food.findOrder(orderId);
    if (!order || order.status !== 'READY' || order.assignedDriverId) {
      return null;
    }
    const point = order.pickup ?? order.dropoff;
    const radiusKm = await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM');
    const rows = await this.presence.onlineNearForPush('FOOD', point, radiusKm, now);
    const inRange: Array<{ id: string; km: number }> = [];
    for (const row of rows) {
      if (row.userId === order.customerId) continue;
      const km = haversineKm(row, point);
      if (km > radiusKm) continue;
      try {
        await this.eligibility.requireEligibleDriver(row.userId);
      } catch {
        continue;
      }
      inRange.push({ id: row.userId, km });
    }
    const unclaimedMinutes = await this.settings.getNumber('FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES');
    return {
      driverIds: inRange.sort((a, b) => a.km - b.km).map((d) => d.id),
      order: {
        id: order.id,
        deliveryFareVnd: order.deliveryFareVnd,
        storeName: order.storeName,
        dropoffLabel: order.dropoff.label,
      },
      ttlSeconds: Math.max(60, Math.floor(unclaimedMinutes * 60)),
    };
  }

  /** The assigned driver hands the order back before pickup (back to the pool). */
  async release(actor: RequestActor, orderId: string, reasonCode: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    return publish(await this.unwrap(() => this.food.release(orderId, actor.userId, reasonCode)));
  }

  /** Merchant never accepted / nobody claimed a ready order. */
  async timeoutDue(now = new Date(), limit = 100): Promise<{ orderIds: string[] }> {
    const policy = {
      merchantAcceptMinutes: await this.settings.getNumber('FOOD_MERCHANT_ACCEPT_TIMEOUT_MINUTES'),
      unclaimedReadyMinutes: await this.settings.getNumber('FOOD_UNCLAIMED_READY_TIMEOUT_MINUTES'),
    };
    const timedOut = await this.food.timeoutDue(now, policy, limit);
    // Unanswered merchant edits cancel the order (SYSTEM, CHANGE_EXPIRED).
    const expired = await this.food.expireChanges(now, limit);
    return { orderIds: [...timedOut.map((row) => row.orderId), ...expired] };
  }

  private async cashPlan(order: FoodOrderView): Promise<NonNullable<PublicFoodOrder['cashPlan']>> {
    const sharedPercent = await this.settings.getNumber('VOUCHER_SHARED_PLATFORM_PERCENT');
    const platformFunded = platformFundedDiscountVnd(order.discountVnd, order.voucherSponsor, sharedPercent);
    const merchantFunded = Math.max(0, order.discountVnd - platformFunded);
    return {
      payMerchantVnd: Math.max(0, order.subtotalVnd - merchantFunded),
      collectFromCustomerVnd: order.totalVnd,
      platformOwesDriverVnd: platformFunded,
    };
  }

  async pickup(actor: RequestActor, orderId: string, handoverCode?: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    if (await this.settings.getBoolean('FOOD_HANDOVER_CODE_REQUIRED')) {
      await this.verifyOrderCode(actor, orderId, 'HANDOVER', 'ASSIGNED', handoverCode);
    }
    // Snapshot the cash the driver hands the store, so a later FAILED order can
    // reimburse exactly that amount even if voucher settings change in between.
    const current = await this.food.findOrder(orderId);
    const snapshot = current
      ? { merchantCashVnd: (await this.cashPlan(current)).payMerchantVnd, at: new Date() }
      : undefined;
    return publish(await this.unwrap(() => this.food.pickup(orderId, actor.userId, snapshot)));
  }

  async deliver(actor: RequestActor, orderId: string, deliveryCode?: string): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    if (await this.settings.getBoolean('FOOD_DELIVERY_CODE_REQUIRED')) {
      await this.verifyOrderCode(actor, orderId, 'DELIVERY', 'PICKED_UP', deliveryCode);
    }
    const feeBps = await this.earnings.currentFeeBps('FOOD_ORDER');
    const sharedPercent = await this.settings.getNumber('VOUCHER_SHARED_PLATFORM_PERCENT');
    const commissionBps = Math.round(
      Math.max(0, Math.min(100, await this.settings.getNumber('FOOD_MERCHANT_COMMISSION_PERCENT'))) * 100,
    );
    // COD obligation, DealGo-funded discount, earnings and fee commit with the delivery itself.
    const order = await this.unwrap(() =>
      this.food.deliver(orderId, actor.userId, async (tx, delivered) => {
        // A fully discounted order has no cash to collect (the journal rejects 0).
        if (delivered.totalVnd > 0) {
          await this.ledger.postWithin(tx, 'COD_OBLIGATION_POSTED', {
            entityType: 'FOOD_ORDER',
            entityId: delivered.id,
            amountVnd: delivered.totalVnd,
          });
        }
        // DEC-PROD-009/015: DealGo books only its own share of the voucher as an expense; the
        // merchant still receives the full subtotal for the platform share.
        const fundedVnd = platformFundedDiscountVnd(
          delivered.discountVnd,
          delivered.voucherSponsor,
          sharedPercent,
        );
        if (fundedVnd > 0) {
          await this.ledger.postWithin(tx, 'PROMOTION_DISCOUNT_FUNDED', {
            entityType: 'FOOD_ORDER',
            entityId: delivered.id,
            amountVnd: fundedVnd,
          });
          // The driver paid the store the full share but collected less at the
          // door; DealGo owes the driver its funded part (negative = credit on the sub-ledger).
          await this.earnings.adjustWithin(tx, {
            driverId: actor.userId,
            amountVnd: -fundedVnd,
            kind: 'FOOD_DISCOUNT_REIMBURSED',
            refType: 'FOOD_ORDER',
            refId: delivered.id,
            occurredAt: delivered.updatedAt,
          });
        }
        // (OPEN-018) Merchant commission on the food subtotal (GrabFood /
        // ShopeeFood charge the store a % of the basket). Snapshotted so statements never
        // re-price history; settled through MerchantSettlement, not at the door.
        const commissionVnd = merchantCommissionVnd(delivered.subtotalVnd, commissionBps);
        await this.food.snapshotCommissionWithin(tx, delivered.id, { commissionBps, commissionVnd });
        if (commissionVnd > 0) {
          await this.ledger.postWithin(tx, 'MERCHANT_COMMISSION_ACCRUED', {
            entityType: 'FOOD_ORDER',
            entityId: delivered.id,
            amountVnd: commissionVnd,
          });
        }
        // The driver's fare is the delivery fee; FOOD_DRIVER_COMMISSION_PERCENT applies to it.
        await this.earnings.recordWithin(tx, {
          entityType: 'FOOD_ORDER',
          entityId: delivered.id,
          driverId: actor.userId,
          fareVnd: delivered.deliveryFareVnd,
          completedAt: delivered.updatedAt,
          feeBps,
        });
      }),
    );
    if (order.totalVnd > 0) {
      await this.recordSandboxCodIntent(order.id, order.totalVnd);
    }
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
      window?: OpsDateWindow;
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
    const view = publish(order);
    const change = await this.food.latestChange(order.id);
    if (change) {
      view.latestChange = publishChange(change);
    }
    return view;
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
      /** MISSING = stores without map coordinates. */
      location?: string;
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
    query: OpsCatalogModerationQueryDto & { window?: OpsDateWindow },
  ): Promise<OpsCatalogModerationPage> {
    return this.food.listCatalogModeration(query);
  }

  async listStoreCategories(
    query: OpsCatalogCategoriesQueryDto,
  ): Promise<OpsCatalogCategoryPage> {
    return this.food.listStoreCategories(query);
  }

  async renameStoreCategory(code: string, name: string) {
    const trimmed = name.trim();
    if (!trimmed) {
      throw foodError(400, 'VALIDATION_ERROR', 'name must not be empty');
    }
    return this.food.renameStoreCategory(code, trimmed);
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

  /**
   * A delivery can fail only after pickup and with a reason. "Customer
   * unreachable" needs FOOD_FAIL_MIN_WAIT_MINUTES since pickup (ShopeeFood "đơn rớt": call,
   * wait, then report). The driver already paid the store, so DealGo credits that cash back
   * (FOOD_FAILED_REIMBURSED) in the same transaction; not counted as a driver cancel.
   */
  async fail(
    actor: RequestActor,
    orderId: string,
    input: { reasonCode: FoodFailReason; note?: string },
  ): Promise<PublicFoodOrder> {
    await this.requireActiveRole(actor.userId, 'DRIVER');
    const note = input.note?.trim() ? input.note.trim().slice(0, FOOD_FAIL_NOTE_MAX) : null;
    if (input.reasonCode === 'OTHER' && !note) {
      throw foodError(400, 'FOOD_FAIL_NOTE_REQUIRED', 'Describe the reason when choosing OTHER');
    }
    const minWaitMinutes = await this.settings.getNumber('FOOD_FAIL_MIN_WAIT_MINUTES');
    return publish(
      await this.unwrap(() =>
        this.food.fail(
          orderId,
          actor.userId,
          { reasonCode: input.reasonCode, note, minWaitMinutes, now: new Date() },
          async (tx, failed) => {
            const cash = failed.merchantCashVnd ?? 0;
            if (cash > 0) {
              await this.earnings.adjustWithin(tx, {
                driverId: actor.userId,
                amountVnd: -cash,
                kind: 'FOOD_FAILED_REIMBURSED',
                refType: 'FOOD_ORDER',
                refId: failed.id,
                occurredAt: failed.updatedAt,
              });
            }
          },
        ),
      ),
    );
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

  /**
   * DEC-PROD-036: only the assigned driver in the right status spends attempts; anything else
   * falls through to the repository's usual not-found / wrong-state error.
   */
  private async verifyOrderCode(
    actor: RequestActor,
    orderId: string,
    kind: FoodOrderCodeKind,
    status: 'ASSIGNED' | 'PICKED_UP',
    submitted: string | undefined,
  ): Promise<void> {
    const order = await this.unwrapNullable(() => this.food.findOrder(orderId));
    if (!order || order.assignedDriverId !== actor.userId || order.status !== status) {
      return;
    }
    const prefix = kind === 'DELIVERY' ? 'FOOD_DELIVERY_CODE' : 'FOOD_HANDOVER_CODE';
    const label = kind === 'DELIVERY' ? 'delivery' : 'handover';
    if (!submitted) {
      throw foodError(422, `${prefix}_REQUIRED`, `Enter the ${label} code`);
    }
    const max = await this.settings.getNumber('FOOD_DELIVERY_CODE_MAX_ATTEMPTS');
    const record = await this.codes.ensure(orderId, kind, generatePickupCode());
    if (!(await this.codes.reserveAttempt(orderId, kind, max))) {
      throw foodError(423, `${prefix}_LOCKED`, `Too many wrong ${label} codes; contact support`);
    }
    if (!pickupCodeMatches(record.code, submitted)) {
      throw foodError(422, `${prefix}_INVALID`, `The ${label} code does not match`);
    }
    await this.codes.markVerified(orderId, kind, new Date());
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

  /** Delivery fare preview for checkout; placement recomputes it the same way. */
  async quoteDelivery(
    actor: RequestActor,
    storeId: string,
    dropoff: { lat: number; lng: number },
  ): Promise<{ deliveryFareVnd: number }> {
    await this.requireActiveCustomer(actor.userId);
    const store = await this.food.findStore(storeId);
    if (!store) {
      throw foodError(404, 'FOOD_STORE_NOT_FOUND', 'Store not found');
    }
    await this.assertWithinDeliveryRange(storeId, dropoff);
    return { deliveryFareVnd: await this.quoteDeliveryFare(storeId, dropoff) };
  }

  /**
   * Straight-line store→drop-off cap (FOOD_MAX_DELIVERY_KM). A store without
   * coordinates cannot take delivery orders, and the drop-off must be in an ACTIVE service zone
   * (SERVICE_ZONE_ENFORCED, same rule as rides).
   */
  private async assertWithinDeliveryRange(
    storeId: string,
    dropoff: { lat: number; lng: number },
  ): Promise<void> {
    const store = await this.food.findStore(storeId);
    if (!store) {
      return;
    }
    if (store.lat == null || store.lng == null) {
      throw foodError(409, 'FOOD_STORE_LOCATION_REQUIRED', 'This store is not taking delivery orders yet');
    }
    await this.assertInServiceZone(dropoff);
    const maxKm = await this.settings.getNumber('FOOD_MAX_DELIVERY_KM');
    if (!(maxKm > 0)) {
      return;
    }
    if (haversineKm({ lat: store.lat, lng: store.lng }, dropoff) > maxKm) {
      throw foodError(422, 'FOOD_TOO_FAR', `Drop-off is more than ${maxKm} km from the store`);
    }
  }

  /** Same zone rule as rides (SERVICE_ZONE_ENFORCED). */
  private async assertInServiceZone(point: { lat: number; lng: number }): Promise<void> {
    if (!(await this.settings.getBoolean('SERVICE_ZONE_ENFORCED'))) {
      return;
    }
    if (!activeRegionCodeAt(point.lat, point.lng)) {
      throw foodError(422, 'FOOD_OUTSIDE_SERVICE_ZONE', 'DealGo does not serve this area yet');
    }
  }

  /**
   * The merchant's store (created on first use). A store still missing coordinates
   * is seeded from the shop pin on the merchant's KYB application.
   */
  private async ownedStore(ownerId: string): Promise<StoreDetail> {
    const store = await this.food.ensureOwnedStore(ownerId, 'My Store');
    if (store.lat != null && store.lng != null) {
      return store;
    }
    const pin = await this.eligibility.merchantShopPin(ownerId);
    if (!pin) {
      return store;
    }
    return this.food.updateStoreLocation({
      ownerId,
      lat: pin.lat,
      lng: pin.lng,
      addressLabel: store.addressLabel ?? pin.label ?? undefined,
    });
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

  private async unwrap<T = FoodOrderView>(work: () => Promise<T>): Promise<T> {
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

  private async unwrapCatalog<T>(work: () => Promise<T>): Promise<T> {
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
    if (error instanceof VoucherRejectedError) {
      return foodError(422, error.code, error.message);
    }
    return error;
  }
}

/** Commission in whole VND (rounded half up), never above the subtotal. */
export function merchantCommissionVnd(subtotalVnd: number, commissionBps: number): number {
  if (!(subtotalVnd > 0) || !(commissionBps > 0)) {
    return 0;
  }
  return Math.min(subtotalVnd, Math.round((subtotalVnd * commissionBps) / 10_000));
}

function publish(order: FoodOrderView): PublicFoodOrder {
  const {
    ownerId: _ownerId,
    updatedAt,
    voucherSponsor: _voucherSponsor,
    estimatedReadyAt,
    pickedUpAt,
    ...publicOrder
  } = order;
  return {
    ...publicOrder,
    estimatedReadyAt: estimatedReadyAt?.toISOString() ?? null,
    pickedUpAt: pickedUpAt?.toISOString() ?? null,
    updatedAt: updatedAt.toISOString(),
  };
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
    serviceMode: store.serviceMode,
    serviceModeUntil: store.serviceModeUntil,
    openNow: store.openNow,
    closedReason: store.closedReason,
    acceptSettings: { ...store.acceptSettings },
    estimatedPrepMinutes: store.estimatedPrepMinutes,
  };
}

function toOpsStoreView(store: OpsStoreDetail): OpsStoreView {
  return {
    ...toOpsStoreListItem(store),
    items: store.items.map((item) => ({ ...item })),
  };
}

export { FoodService as FoodOrderService };

