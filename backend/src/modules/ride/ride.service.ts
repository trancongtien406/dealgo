import type { CancelActorName } from '../../shared/cancel-actor.js';
import type { DriverJobCounts } from '../../shared/driver-job-counts.js';
import { HttpException, Inject, Injectable, Optional } from '@nestjs/common';
import { RideOfferEvents, type RideOfferChangeReason } from './ride-offer-events.js';
import { ConfigService } from '@nestjs/config';
import { boundingBox, filterByDispatchRadius, type DispatchQuery } from '../dispatch/dispatch-filter.js';
import { haversineKm } from '../../shared/geo/haversine.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import type { AppEnv } from '../../platform/config/env.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import type { DriverLocationResponse } from '../identity/driver-presence.repository.js';
import { DriverPresenceService } from '../identity/driver-presence.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import { UniqueConflictError, type IdentityRepository, type RoleName } from '../identity/identity.repository.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { MAPS_PORT } from '../../integrations/maps/maps.constants.js';
import { resolveRouteDistanceKm, type MapsPort } from '../../integrations/maps/maps-port.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { EarningsService } from '../earnings/earnings.service.js';
import { PartnerEligibilityService } from '../partner/partner-eligibility.service.js';
import { VoucherRejectedError } from '../promotion/promotion-redemption.js';
import { platformFundedDiscountVnd } from '../promotion/voucher-funding.js';
import { PAYMENT_PORT } from '../payment/payment.constants.js';
import type { PaymentPort } from '../payment/payment-port.js';
import { UnavailablePaymentError } from '../payment/payment-port.js';
import {
  PaymentGatewayService,
  splitCollection,
  type CheckoutView,
  type CollectionView,
} from '../payment/checkout/payment-gateway.service.js';
import { PaymentMethodRegistryService } from '../payment/checkout/payment-method-registry.service.js';
import { serviceForVehicleClass } from '../payment/checkout/payment-method.catalog.js';
import type { PaymentMethodCode } from '../../platform/settings/payment-method-registry.js';
import { RideVehicleClassService } from '../ride-vehicle/ride-vehicle-class.service.js';
import {
  clampToFareSteps,
  isBikeClass,
  MOTORBIKE_CLASS_CODE,
  rideBidFloorVnd,
  roundDownToFareStep,
  roundUpToFareStep,
} from '../ride-vehicle/ride-vehicle-class.js';
import {
  PhaseRouteCache,
  RoutingService,
  toRouteGeometryView,
  UNAVAILABLE_ROUTE_GEOMETRY,
  routePhaseForRide,
  type RoutePhase,
  type RouteGeometryView,
} from '../routing/index.js';
import type {
  DriverHistoryWindow,
  OpenRideListing,
  RideFeePolicy,
  RideOfferStatusName,
  RideSnapshot,
} from './ride-ledger.js';
import { activeRegionCodeAt } from '../service-area/service-regions.js';
import {
  CustomerAlreadyRatedError,
  RIDE_CUSTOMER_RATING_STORE,
  type CustomerRatingSummary,
  type RideCustomerRatingStore,
} from './ride-customer-rating.js';
import {
  RIDE_PICKUP_CODE_STORE,
  generatePickupCode,
  pickupCodeMatches,
  type RidePickupCodeStore,
} from './ride-pickup-code.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from './ride.constants.js';
import type {
  CreateOfferDto,
  CreateRideDto,
  DeclineOfferDto,
  DriverCancelRideDto,
  RaiseFareDto,
  RateCustomerDto,
  SelectOfferDto,
  UpdateStopsDto,
} from './ride.dto.js';
import { RideRuleError, rideError } from './ride.error.js';
import {
  loadMultiStopConfig,
  multiStopService,
  referenceWithStopsVnd,
  stopPolicy,
  stopsRuleError,
  waypoints,
  type MultiStopConfig,
} from './ride-multi-stop.js';
import type { OpsInterveneResult, RideRepository } from './ride.repository.js';

export type RideOfferView = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: 'ACCEPT' | 'COUNTER';
  /** DECLINED = customer rejected it; WITHDRAWN = the driver took it back. */
  status: RideOfferStatusName;
  expiresAt: string;
  /** Changes the driver made after the first offer. */
  editCount: number;
};

export type OpenRideView = {
  id: string;
  status: 'NEGOTIATING';
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  offeredFareVnd: number;
  referenceFareVnd: number;
  vehicleClassCode: string;
  imageUrl: string | null;
  expiresAt: string;
  offerCount: number;
  /** What drivers see about the customer before bidding (never the customer id). */
  customerRating: CustomerRatingSummary;
  /** Straight-line km from the driver's dispatch origin to pickup. */
  pickupDistanceKm: number | null;
  /** Intermediate stops between pickup and dropoff (empty = single destination). */
  stops: Array<{ lat: number; lng: number; label: string }>;
  /** Offers must quote this version; a stop edit bumps it. */
  routeVersion: number;
};

export type RideStopView = {
  seq: number;
  lat: number;
  lng: number;
  label: string;
  arrivedAt: string | null;
  departedAt: string | null;
};

export type RideView = {
  id: string;
  status:
    | 'NEGOTIATING'
    | 'ASSIGNED'
    | 'DRIVER_EN_ROUTE'
    | 'DRIVER_ARRIVED'
    | 'IN_TRIP'
    | 'COMPLETED'
    | 'CANCELLED'
    | 'EXPIRED';
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  /** Intermediate stops in visiting order (empty = single destination). */
  stops: RideStopView[];
  /** Bumped on each stop edit; offers carry it (RIDE_ROUTE_CHANGED on mismatch). */
  routeVersion: number;
  /** Next stop the driver has not left yet while IN_TRIP (null = heading to dropoff). */
  currentStopSeq: number | null;
  /** Per-stop fee included in the reference fare (snapshot at booking). */
  stopFeeVnd: number;
  /** Stop waiting charge over the free minutes, added at completion. */
  waitFeeVnd: number;
  offeredFareVnd: number;
  referenceFareVnd: number;
  vehicleClassCode: string;
  imageUrl: string | null;
  agreedFareVnd: number | null;
  /** DEC-PROD-024: voucher discount reserved at selection (0 when none). */
  discountVnd: number;
  voucherCode: string | null;
  /** Cash the driver collects: agreedFareVnd - discountVnd (null before selection). */
  cashDueVnd: number | null;
  assignedDriverId: string | null;
  /** DEC-PROD-035: who cancelled (null unless CANCELLED). */
  cancelledBy: CancelActorName | null;
  /** Last state change (completion time once COMPLETED); receipts show it. */
  updatedAt: string;
  /** DEC-PROD-017: only on the customer's own GET while the driver is on the way. */
  pickupCode?: string;
  selectedOfferId: string | null;
  expiresAt: string;
  offers: RideOfferView[];
  /** Road geometry (DEC-PROD-045 provider). available=false → straight-line UI. */
  route: RouteGeometryView;
  /** APPROACH while the driver heads to pickup, TRIP from DRIVER_ARRIVED; absent otherwise. */
  routePhase?: RoutePhase;
  /** Driver→pickup road leg (APPROACH only, needs a fresh driver fix). No straight-line fallback. */
  approachRoute?: RouteGeometryView;
  /** When the driver was assigned (null before). */
  assignedAt: string | null;
  /** Customer did not show up (driver-reported after RIDE_NO_SHOW_WAIT_MINUTES). */
  noShow: boolean;
  /** Why it ended (CUSTOMER_LATE_CANCEL, NO_SHOW, …) or null. */
  cancelReasonCode: string | null;
  /** Earlier unpaid cancel/no-show fees collected in this ride's cash. */
  priorFeesVnd: number;
  /** Customer fare raises so far. */
  fareRaiseCount: number;
  /** The EXPIRED ride this request re-posts. */
  repostOfRideId: string | null;
  /** Live limits while NEGOTIATING so apps can disable buttons (0 = unlimited). */
  negotiation?: RideNegotiationLimits;
  /** For EXPIRED requests, the suggested fare for a one-tap re-post. */
  repostHint?: { suggestedFareVnd: number; raisePercent: number };
  /** Assigned driver's view of the customer's rating. */
  customerRating?: CustomerRatingSummary;
};

/** Admin view: the public RideView plus who booked it (BFF resolves the name). */
export type OpsRideView = RideView & { customerId: string };

function toOpsView(ride: RideSnapshot, imageUrl: string | null): OpsRideView {
  return { ...toView(ride, imageUrl), customerId: ride.customerId };
}

const DRIVER_VISIBLE_STATUSES = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
  'COMPLETED',
]);

export interface RideQuoteOptionView {
  code: string;
  name: string;
  seats: number;
  referenceFareVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  durationMin: number;
  baseFareVnd: number;
  perKmVnd: number;
  perMinuteVnd: number;
  imageUrl: string | null;
  /**
   * Lowest bid the server accepts = max(class min,
   * ceil(reference × RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE / 100)). The slider starts here.
   */
  minBidVnd: number;
  /** Multi-stop service for this class (BIKE / CAR). */
  multiStopService: 'BIKE' | 'CAR';
  /** false when the quoted stops are not allowed for this class (flag off / too many). */
  available: boolean;
  unavailableReason: 'RIDE_STOPS_DISABLED' | 'RIDE_TOO_MANY_STOPS' | null;
}

export interface RideQuoteView {
  distanceKm: number;
  referenceFareVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  /** Effective lowest bid for the primary option. */
  minBidVnd: number;
  /** Unpaid fees that will be added to the next completed ride. */
  pendingFeesVnd: number;
  options: RideQuoteOptionView[];
  /** Road geometry for the overview map (same provider as Admin). */
  route: RouteGeometryView;
  /** Stops quoted (0 = single destination). */
  stopCount: number;
  /** Admin multi-stop rules per service, so the app shows / hides "Thêm điểm dừng". */
  multiStop: { BIKE: MultiStopConfig; CAR: MultiStopConfig };
}


const RIDE_TRACKING_STATUSES: ReadonlySet<string> = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
]);

export const CUSTOMER_ACTIVE_RIDE_STATUSES: readonly string[] = ['NEGOTIATING', ...RIDE_TRACKING_STATUSES];

@Injectable()
export class RideService {
  constructor(
    @Inject(RIDE_REPOSITORY) private readonly rides: RideRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(RIDE_CLOCK) private readonly clock: RideClock,
    @Inject(MAPS_PORT) private readonly maps: MapsPort,
    @Inject(PAYMENT_PORT) private readonly payments: PaymentPort,
    private readonly ledger: LedgerService,
    private readonly eligibility: PartnerEligibilityService,
    private readonly presence: DriverPresenceService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly settings: PlatformSettingsService,
    private readonly earnings: EarningsService,
    private readonly vehicleClasses: RideVehicleClassService,
    private readonly routing: RoutingService,
    @Inject(RIDE_PICKUP_CODE_STORE) private readonly pickupCodes: RidePickupCodeStore,
    @Optional() private readonly offerEvents?: RideOfferEvents,
    @Optional() @Inject(RIDE_CUSTOMER_RATING_STORE)
    private readonly customerRatings?: RideCustomerRatingStore,
    @Optional() private readonly phaseRoutes?: PhaseRouteCache,
    @Optional() private readonly paymentMethods?: PaymentMethodRegistryService,
    @Optional() private readonly checkout?: PaymentGatewayService,
  ) {}

  /** Server-side enforcement: only methods enabled for this service (CASH always allowed). */
  private async resolvePaymentMethod(vehicleClassCode: string, requested?: string): Promise<PaymentMethodCode> {
    const code = requested ?? 'CASH';
    if (code === 'CASH' || !this.paymentMethods) {
      if (code !== 'CASH') {
        throw rideError(422, 'PAYMENT_METHOD_UNAVAILABLE', 'Online payment is not available');
      }
      return 'CASH';
    }
    return this.paymentMethods.assertSelectable(serviceForVehicleClass(vehicleClassCode), code);
  }

  /** Customer picks / starts paying for a ride. Amount = agreed fare − voucher (server side). */
  async startPayment(
    actor: RequestActor,
    rideId: string,
    methodCode: string,
    clientIp?: string,
  ): Promise<CheckoutView> {
    await this.requireOwnRide(actor, rideId);
    const ride = await this.get(actor, rideId);
    if (ride.status === 'CANCELLED' || ride.status === 'EXPIRED') {
      throw rideError(409, 'RIDE_NOT_PAYABLE', 'This ride can no longer be paid');
    }
    if (!this.checkout) {
      throw rideError(422, 'PAYMENT_METHOD_UNAVAILABLE', 'Online payment is not available');
    }
    return this.checkout.start({
      entityType: 'RIDE',
      entityId: ride.id,
      service: serviceForVehicleClass(ride.vehicleClassCode),
      methodCode,
      amountVnd: ride.cashDueVnd ?? 0,
      userId: actor.userId,
      clientIp,
    });
  }

  private async requireOwnRide(actor: RequestActor, rideId: string): Promise<void> {
    const raw = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!raw || raw.customerId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
  }

  /** Assigned driver: method + paid-online vs cash to collect. */
  async driverCollection(actor: RequestActor, rideId: string): Promise<CollectionView> {
    const raw = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!raw || raw.assignedDriverId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const ride = await this.get(actor, rideId);
    const due = ride.cashDueVnd ?? 0;
    if (!this.checkout) {
      return {
        entityType: 'RIDE', entityId: ride.id, methodCode: 'CASH', status: 'CASH', amountVnd: null,
        paymentUrl: null, deeplink: null, intentId: null, failureReason: null,
        paidOnlineVnd: 0, cashToCollectVnd: due,
      };
    }
    return this.checkout.collection('RIDE', ride.id, due);
  }

  async paymentStatus(actor: RequestActor, rideId: string): Promise<CheckoutView> {
    await this.requireOwnRide(actor, rideId);
    const ride = await this.get(actor, rideId);
    if (!this.checkout) {
      return {
        entityType: 'RIDE', entityId: ride.id, methodCode: 'CASH', status: 'CASH', amountVnd: null,
        paymentUrl: null, deeplink: null, intentId: null, failureReason: null,
      };
    }
    return this.checkout.status('RIDE', ride.id);
  }

  private notifyOffers(rideId: string, reason: RideOfferChangeReason): void {
    this.offerEvents?.publish({ rideId, reason, at: this.clock.now() });
  }

  /**
   * Customer-room payload for `rideOffers` (DEC-PROD-031 rev 2026-10-24). Only ever emitted to
   * `ride-offers:{id}`, which admits the ride's customer alone.
   */
  async customerOffersSnapshot(
    rideId: string,
  ): Promise<{ status: RideView['status']; offers: RideOfferView[]; updatedAt: string } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return null;
    }
    const view = toView(ride, null);
    return { status: view.status, offers: view.offers, updatedAt: view.updatedAt };
  }

  async create(actor: RequestActor, idempotencyKey: string, dto: CreateRideDto): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const vehicle = await this.requireEnabledClass(dto.vehicleClassCode);
    const paymentMethod = await this.resolvePaymentMethod(vehicle.code, dto.paymentMethod);
    const offeredFareVnd = toFareStep(dto.offeredFareVnd);
    await this.assertFare(offeredFareVnd, vehicle.minFareVnd, vehicle.maxFareVnd);
    const stops = dto.stops ?? [];
    const multiStop = await loadMultiStopConfig(this.settings, multiStopService(vehicle.code));
    this.assertStopsAllowed(stops.length, multiStop);
    await this.assertInServiceZone(dto.pickup, dto.dropoff, stops);
    const now = this.clock.now();
    await this.assertCancelCooldown(actor.userId, now);
    const repostOfRideId = await this.repostSource(actor.userId, dto.repostOfRideId, now);
    const distanceKm = await this.routeDistanceKm(dto.pickup, stops, dto.dropoff);
    const distanceQuote = this.vehicleClasses.quote(distanceKm, vehicle);
    const quoted = {
      ...distanceQuote,
      referenceFareVnd: referenceWithStopsVnd(distanceQuote.referenceFareVnd, stops.length, multiStop.stopFeeVnd, vehicle),
    };
    // The customer's bid may not undercut the server reference by more than
    // RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE (inDrive shows a "recommended" floor the same way).
    await this.assertBidFloor(offeredFareVnd, quoted.referenceFareVnd);
    const expiresAt = await this.requestWindowEnd(now);
    const created = await this.unwrap(() =>
      this.rides.create({
        customerId: actor.userId,
        idempotencyKey,
        pickup: dto.pickup,
        dropoff: dto.dropoff,
        ...(stops.length > 0 ? { stops, stopPolicy: stopPolicy(multiStop) } : {}),
        offeredFareVnd,
        referenceFareVnd: quoted.referenceFareVnd,
        vehicleClassCode: vehicle.code,
        expiresAt,
        now,
        repostOfRideId,
      }),
    );
    if (this.checkout && paymentMethod !== 'CASH') {
      await this.checkout.recordSelection('RIDE', created.id, paymentMethod);
    }
    if (created.status === 'NEGOTIATING') {
      this.notifyOffers(created.id, 'CREATED');
    }
    return created;
  }

  /**
   * After CUSTOMER_CANCEL_LIMIT_COUNT cancellations of rides that already had
   * a driver within CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS, new requests wait
   * CUSTOMER_CANCEL_COOLDOWN_MINUTES from the latest one (Grab/inDrive temporary restriction).
   */
  private async assertCancelCooldown(customerId: string, now: Date): Promise<void> {
    const limit = await this.settings.getNumber('CUSTOMER_CANCEL_LIMIT_COUNT');
    const cooldown = await this.settings.getNumber('CUSTOMER_CANCEL_COOLDOWN_MINUTES');
    if (limit <= 0 || cooldown <= 0) {
      return;
    }
    const windowHours = await this.settings.getNumber('CUSTOMER_CANCEL_LIMIT_WINDOW_HOURS');
    const since = new Date(now.getTime() - windowHours * 3_600_000);
    const times = await this.rides.customerCancelTimes(customerId, since);
    if (times.length < limit) {
      return;
    }
    const latest = Math.max(...times.map((time) => time.getTime()));
    const until = latest + cooldown * 60_000;
    if (until > now.getTime()) {
      throw new HttpException(
        {
          message: 'Too many cancelled rides recently; please try again later',
          errorCode: 'RIDE_CANCEL_COOLDOWN',
          retryAt: new Date(until).toISOString(),
        },
        429,
      );
    }
  }

  /** A re-post must point at this customer's own EXPIRED request. */
  private async repostSource(
    customerId: string,
    rideId: string | undefined,
    now: Date,
  ): Promise<string | null> {
    if (!rideId) {
      return null;
    }
    const source = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!source || source.customerId !== customerId || source.status !== 'EXPIRED') {
      throw rideError(409, 'RIDE_REPOST_INVALID', 'Only your own expired request can be re-posted');
    }
    return source.id;
  }

  /** Preview of what create() would store, so the app never guesses prices. */
  async quote(
    actor: RequestActor,
    dto: {
      pickup: { lat: number; lng: number };
      dropoff: { lat: number; lng: number };
      stops?: Array<{ lat: number; lng: number }>;
    },
  ): Promise<RideQuoteView> {
    await this.requireActiveCustomer(actor.userId);
    const enabled = await this.vehicleClasses.listEnabled();
    if (enabled.length === 0) {
      throw rideError(400, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'No vehicle class is available');
    }
    const stops = dto.stops ?? [];
    await this.assertInServiceZone(dto.pickup, dto.dropoff, stops);
    const multiStop = await this.multiStopConfig();
    const distanceKm = await this.routeDistanceKm(dto.pickup, stops, dto.dropoff);
    const floorPercent = await this.settings.getNumber('RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE');
    const options = enabled.map((vehicle) => {
      const service = multiStopService(vehicle.code);
      const config = multiStop[service];
      const unavailableReason = stopsRuleError(stops.length, config) as RideQuoteOptionView['unavailableReason'];
      const distanceQuote = this.vehicleClasses.quote(distanceKm, vehicle);
      const quoted = {
        ...distanceQuote,
        referenceFareVnd: referenceWithStopsVnd(distanceQuote.referenceFareVnd, stops.length, config.stopFeeVnd, vehicle),
      };
      const floor = rideBidFloorVnd(quoted.referenceFareVnd, floorPercent);
      return {
        multiStopService: service,
        available: unavailableReason === null,
        unavailableReason,
        minBidVnd: clampToFareSteps(floor, vehicle.minFareVnd, vehicle.maxFareVnd),
        code: vehicle.code,
        name: vehicle.name,
        seats: vehicle.seats,
        referenceFareVnd: quoted.referenceFareVnd,
        minFareVnd: vehicle.minFareVnd,
        maxFareVnd: vehicle.maxFareVnd,
        durationMin: quoted.durationMin,
        baseFareVnd: vehicle.baseFareVnd,
        perKmVnd: vehicle.perKmVnd,
        perMinuteVnd: vehicle.perMinuteVnd,
        imageUrl: vehicle.imageUrl,
      };
    });
    // Top-level summary uses catalog sortOrder — do not prefer MOTORBIKE (DG-DEC-VEH-001).
    if (stops.length > 0 && !options.some((option) => option.available)) {
      const reason = options.find((option) => option.unavailableReason)?.unavailableReason ?? 'RIDE_STOPS_DISABLED';
      throw this.asHttp(new RideRuleError(reason));
    }
    const primary = options.find((option) => option.available) ?? options[0]!;
    const route = await this.lookupRoute(dto.pickup, dto.dropoff, stops);
    return {
      distanceKm: Math.round(distanceKm * 10) / 10,
      referenceFareVnd: primary.referenceFareVnd,
      minFareVnd: primary.minFareVnd,
      maxFareVnd: primary.maxFareVnd,
      minBidVnd: primary.minBidVnd,
      pendingFeesVnd: await this.rides.pendingFeeTotal(actor.userId),
      options,
      route,
      stopCount: stops.length,
      multiStop,
    };
  }

  /** Admin multi-stop rules for both services (GET /v1/rides/multi-stop-config). */
  async multiStopConfig(): Promise<{ BIKE: MultiStopConfig; CAR: MultiStopConfig }> {
    const [BIKE, CAR] = await Promise.all([
      loadMultiStopConfig(this.settings, 'BIKE'),
      loadMultiStopConfig(this.settings, 'CAR'),
    ]);
    return { BIKE, CAR };
  }

  /**
   * Customer adds / removes / reorders stops while NEGOTIATING. The route and reference are
   * re-quoted, pending offers die (LOST) and the round restarts; after selection the route is
   * locked (RIDE_STOPS_LOCKED). Removing every stop is always allowed even with the flag off.
   */
  async updateStops(actor: RequestActor, rideId: string, dto: UpdateStopsDto): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const now = this.clock.now();
    const existing = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!existing || existing.customerId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (existing.status !== 'NEGOTIATING') {
      throw this.asHttp(new RideRuleError('RIDE_STOPS_LOCKED'));
    }
    const stops = dto.stops;
    const dropoff = dto.dropoff ?? existing.dropoff;
    const multiStop = await loadMultiStopConfig(this.settings, multiStopService(existing.vehicleClassCode));
    this.assertStopsAllowed(stops.length, multiStop);
    await this.assertInServiceZone(existing.pickup, dropoff, stops);
    const bounds = await this.vehicleClasses.findAny(existing.vehicleClassCode);
    if (!bounds) {
      throw rideError(400, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class is not available');
    }
    const distanceKm = await this.routeDistanceKm(existing.pickup, stops, dropoff);
    const referenceFareVnd = referenceWithStopsVnd(
      this.vehicleClasses.quote(distanceKm, bounds).referenceFareVnd,
      stops.length,
      multiStop.stopFeeVnd,
      bounds,
    );
    const offeredFareVnd = toFareStep(dto.offeredFareVnd ?? existing.offeredFareVnd);
    await this.assertFare(offeredFareVnd, bounds.minFareVnd, bounds.maxFareVnd);
    await this.assertBidFloor(offeredFareVnd, referenceFareVnd);
    const windowExpiresAt = await this.requestWindowEnd(now);
    const updated = await this.unwrap(() =>
      this.rides.updateStops({
        rideId,
        customerId: actor.userId,
        stops,
        dropoff,
        referenceFareVnd,
        offeredFareVnd,
        stopFeeVnd: multiStop.stopFeeVnd,
        ...(dto.routeVersion !== undefined ? { expectedRouteVersion: dto.routeVersion } : {}),
        windowExpiresAt,
        now,
      }),
    );
    this.notifyOffers(rideId, 'ROUTE_CHANGED');
    return updated;
  }

  /** Assigned driver reached stop `seq` (IN_TRIP, stops in order; repeats are no-ops). */
  async arriveStop(actor: RequestActor, rideId: string, seq: number): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    return this.unwrap(() =>
      this.rides.arriveStop({ rideId, driverId: actor.userId, seq, now: this.clock.now() }),
    );
  }

  /** Assigned driver leaves stop `seq`; waiting beyond the free minutes is billed at completion. */
  async departStop(actor: RequestActor, rideId: string, seq: number): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    return this.unwrap(() =>
      this.rides.departStop({ rideId, driverId: actor.userId, seq, now: this.clock.now() }),
    );
  }

  private assertStopsAllowed(stopCount: number, config: MultiStopConfig): void {
    const code = stopsRuleError(stopCount, config);
    if (code) {
      throw this.asHttp(new RideRuleError(code));
    }
  }

  /** Road km over every leg pickup → stops → dropoff. */
  private async routeDistanceKm(
    pickup: { lat: number; lng: number },
    stops: ReadonlyArray<{ lat: number; lng: number }>,
    dropoff: { lat: number; lng: number },
  ): Promise<number> {
    const points = waypoints(pickup, [...stops], dropoff);
    const legs = await Promise.all(
      points.slice(1).map((to, index) => resolveRouteDistanceKm(this.maps, points[index]!, to)),
    );
    return legs.reduce((sum, km) => sum + km, 0);
  }

  async listVehicleClasses(): Promise<{
    classes: Array<{ code: string; name: string; seats: number; imageUrl: string | null }>;
  }> {
    const rows = await this.vehicleClasses.listEnabled();
    return {
      classes: rows.map((row) => ({
        code: row.code,
        name: row.name,
        seats: row.seats,
        imageUrl: row.imageUrl,
      })),
    };
  }

  /** Raw finished jobs for the driver-history module (auth is checked there). */
  listFinishedForDriver(driverId: string, window: DriverHistoryWindow): Promise<RideSnapshot[]> {
    return this.rides.listFinishedForDriver(driverId, window);
  }

  countFinishedForDrivers(driverIds: readonly string[]): Promise<Map<string, DriverJobCounts>> {
    return this.rides.countFinishedForDrivers(driverIds);
  }

  async listForCustomer(
    actor: RequestActor,
    page?: number,
    limit?: number,
  ): Promise<PageResult<RideView>> {
    await this.requireActiveCustomer(actor.userId);
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.rides.listForCustomer(
      actor.userId,
      safePage,
      safeLimit,
      this.clock.now(),
    );
    const images = await this.enabledClassImageUrls(result.items);
    return {
      items: result.items.map((ride) => toView(ride, images.get(ride.vehicleClassCode) ?? null)),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async listOpen(actor: RequestActor, query: DispatchQuery = {}): Promise<OpenRideView[]> {
    await this.eligibility.requireEligibleDriver(actor.userId);
    const requirePresence = await this.settings.getBoolean('DISPATCH_REQUIRE_FRESH_PRESENCE');
    if (!(await this.presence.isDispatchEligible(actor.userId, 'RIDE', requirePresence))) {
      return [];
    }
    // Drivers over DRIVER_DEBT_LIMIT_VND cannot take new cash jobs.
    await this.earnings.assertUnderDebtLimit(actor.userId);
    const now = this.clock.now();
    // Radius from query coords or the fresh presence fix; no fix → 409, never
    // an unfiltered "recent" slice of the whole country.
    const origin = await this.presence.dispatchOrigin(actor.userId, query, now, requirePresence);
    const fallbackLimit = this.config.get('DISPATCH_FALLBACK_LIMIT', { infer: true });
    const radiusKm = await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM');
    const fetchLimit = origin ? Math.max(fallbackLimit * 10, 100) : fallbackLimit;
    const driverClass = await this.eligibility.driverVehicleClassCode(actor.userId);
    // Fail closed (DG-DEC-VEH-001): no valid KYC class → empty open list (never silent MOTORBIKE).
    if (!driverClass) {
      return [];
    }
    const rides = await this.rides.listOpen(
      now,
      fetchLimit,
      driverClass,
      origin ? boundingBox(origin, radiusKm) : undefined,
    );
    const filtered = filterByDispatchRadius(
      rides,
      origin ?? {},
      radiusKm,
      fallbackLimit,
      (ride) => ride.pickup,
    );
    const nearestFirst = origin
      ? [...filtered].sort((a, b) => haversineKm(origin, a.pickup) - haversineKm(origin, b.pickup))
      : filtered;
    const images = await this.enabledClassImageUrls(nearestFirst);
    const ratings = await this.customerSummaries(nearestFirst.map((ride) => ride.customerId));
    return nearestFirst.map((ride) =>
      toOpenView(
        ride,
        images.get(ride.vehicleClassCode) ?? null,
        ratings.get(ride.customerId) ?? EMPTY_CUSTOMER_RATING,
        origin ? Math.round(haversineKm(origin, ride.pickup) * 10) / 10 : null,
      ),
    );
  }

  private async customerSummaries(ids: readonly string[]): Promise<Map<string, CustomerRatingSummary>> {
    if (!this.customerRatings || ids.length === 0) {
      return new Map();
    }
    return this.customerRatings.summaries(ids);
  }

  async get(actor: RequestActor, rideId: string): Promise<RideView> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || !(await this.canRead(actor.userId, ride))) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const imageUrl = await this.imageUrlForClass(ride.vehicleClassCode);
    if (ride.customerId === actor.userId) {
      await this.requireActiveCustomer(actor.userId);
      if (PICKUP_CODE_STATUSES.has(ride.status)) {
        const { code } = await this.pickupCodes.ensure(ride.id, generatePickupCode());
        return this.withPhaseRoute(
          await this.withRoute({ ...toView(ride, imageUrl), pickupCode: code }, ride.pickup, ride.dropoff),
          ride,
        );
      }
    }
    const view = toView(ride, imageUrl);
    if (ride.customerId !== actor.userId) {
      const ratings = await this.customerSummaries([ride.customerId]);
      view.customerRating = ratings.get(ride.customerId) ?? EMPTY_CUSTOMER_RATING;
    }
    return this.withNegotiation(
      await this.withPhaseRoute(
        await this.withRoute(
          ride.customerId === actor.userId ? view : onlyOwnOffers(view, actor.userId),
          ride.pickup,
          ride.dropoff,
        ),
        ride,
      ),
    );
  }

  /** REST snapshot of the phase-aware leg (reconnect); live updates come via `routeUpdated`. */
  private async withPhaseRoute(view: RideView, ride: RideSnapshot): Promise<RideView> {
    const phase = ride.assignedDriverId ? routePhaseForRide(ride.status) : null;
    if (!phase) return view;
    if (phase === 'TRIP') return { ...view, routePhase: phase };
    // One cached approach leg per job (shared with the realtime push): a re-GET never
    // costs its own Directions call.
    const now = this.clock.now();
    const cached = this.phaseRoutes?.forPhase('Ride', ride.id, 'APPROACH', now.getTime());
    if (cached) return { ...view, routePhase: phase, approachRoute: cached.route };
    const fix = await this.presence.freshLocation(ride.assignedDriverId!, now);
    if (!fix) {
      return { ...view, routePhase: phase, approachRoute: { ...UNAVAILABLE_ROUTE_GEOMETRY, provider: this.routing.provider() } };
    }
    const approachRoute = await this.lookupRoute({ lat: fix.lat, lng: fix.lng }, ride.pickup);
    this.phaseRoutes?.set('Ride', ride.id, { phase: 'APPROACH', route: approachRoute, at: now.getTime() });
    return { ...view, routePhase: phase, approachRoute };
  }

  /** Realtime phase-route: legs for a ride the driver is serving, or null. */
  async routeLegsForDriver(
    rideId: string,
    driverId: string,
  ): Promise<{
    phase: RoutePhase;
    pickup: { lat: number; lng: number };
    dropoff: { lat: number; lng: number };
    via?: Array<{ lat: number; lng: number }>;
  } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || ride.assignedDriverId !== driverId) return null;
    const phase = routePhaseForRide(ride.status);
    if (!phase) return null;
    const via = (ride.stops ?? [])
      .filter((stop) => !stop.departedAt)
      .map((stop) => ({ lat: stop.lat, lng: stop.lng }));
    return { phase, pickup: ride.pickup, dropoff: ride.dropoff, ...(via.length > 0 ? { via } : {}) };
  }

  /**
   * DEC-PROD-031: the customer sees the assigned driver's fresh position from assignment until
   * the trip ends; nobody else does (404 like GET /rides/:id).
   */
  async driverLocation(actor: RequestActor, rideId: string): Promise<DriverLocationResponse> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || ride.customerId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (!ride.assignedDriverId || !RIDE_TRACKING_STATUSES.has(ride.status)) {
      return { location: null };
    }
    const location = await this.presence.freshLocation(ride.assignedDriverId, this.clock.now());
    return {
      location: location
        ? { lat: location.lat, lng: location.lng, at: location.at.toISOString() }
        : null,
    };
  }

  /** Live-location room: same rule as GET /rides/:id/driver-location (customer only). */
  async canSubscribeLocation(userId: string, rideId: string): Promise<boolean> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    return Boolean(ride && ride.customerId === userId);
  }

  /**
   * Relaunch resume (DEC-PROD-057): the customer's newest ride that is still live
   * (negotiating or on trip). Re-read through findById so lazily expired offers drop out.
   */
  async activeRideForCustomer(customerId: string): Promise<{ id: string; status: string } | null> {
    const ids =
      (await this.rides.listIdsForCustomerInStatuses?.(customerId, CUSTOMER_ACTIVE_RIDE_STATUSES)) ?? [];
    for (const id of ids) {
      const ride = await this.unwrapNullable(() => this.rides.findById(id, this.clock.now()));
      if (ride && ride.customerId === customerId && CUSTOMER_ACTIVE_RIDE_STATUSES.includes(ride.status)) {
        return { id: ride.id, status: ride.status };
      }
    }
    return null;
  }

  /** Rides whose customer should receive this driver's live fix. */
  async trackingRideIdsForDriver(driverId: string): Promise<string[]> {
    return (await this.rides.listIdsForDriverInStatuses?.(driverId, [...RIDE_TRACKING_STATUSES])) ?? [];
  }

  /** Socket room join uses the same participant checks as GET /rides/:id. */
  async canSubscribe(userId: string, rideId: string): Promise<boolean> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return false;
    }
    try {
      return await this.canRead(userId, ride);
    } catch {
      // Fail closed: any lookup error (grants, eligibility) denies the room.
      return false;
    }
  }

  /** Status + updatedAt for contact-window checks (chat/voice). */
  async contactMeta(rideId: string): Promise<{ status: string; updatedAt: Date } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return null;
    }
    return { status: ride.status, updatedAt: ride.updatedAt };
  }

  /** Who may rate the ride and whom: used by the rating module. */
  /** Raw snapshot for the public share page (caller enforces the share token). */
  async shareSnapshot(rideId: string): Promise<RideSnapshot | null> {
    return this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
  }

  async ratingSubject(
    rideId: string,
  ): Promise<{
    customerId: string;
    driverId: string | null;
    storeId: null;
    status: string;
    finishedAt: Date;
  } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return null;
    }
    return {
      customerId: ride.customerId,
      driverId: ride.assignedDriverId,
      storeId: null,
      status: ride.status,
      finishedAt: ride.updatedAt,
    };
  }

  /** Known participant userIds for push fan-out (customer + assigned driver). */
  async participantRoles(rideId: string): Promise<{ customerId: string; driverId: string | null } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    return ride ? { customerId: ride.customerId, driverId: ride.assignedDriverId ?? null } : null;
  }

  async participantUserIds(rideId: string): Promise<string[]> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return [];
    }
    const ids = [ride.customerId];
    if (ride.assignedDriverId) {
      ids.push(ride.assignedDriverId);
    }
    return ids;
  }

  async offer(actor: RequestActor, rideId: string, dto: CreateOfferDto): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    await this.earnings.assertUnderDebtLimit(actor.userId);
    // A driver who is explicitly offline or has ride requests off cannot bid.
    if (!(await this.presence.isDispatchEligible(actor.userId, 'RIDE'))) {
      throw rideError(409, 'DRIVER_OFFLINE', 'Go online for rides to send an offer');
    }
    const now = this.clock.now();
    const existing = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!existing) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const driverClass = await this.eligibility.driverVehicleClassCode(actor.userId);
    if (!driverClass || driverClass !== existing.vehicleClassCode) {
      throw rideError(
        403,
        'RIDE_VEHICLE_CLASS_MISMATCH',
        'This ride is for a different vehicle class',
      );
    }
    // Taking the customer's own price stays exact; any other amount goes up to the fare step.
    const amountVnd =
      dto.amountVnd === existing.offeredFareVnd ? dto.amountVnd : toFareStep(dto.amountVnd);
    const bounds = await this.vehicleClasses.findAny(existing.vehicleClassCode);
    if (bounds) {
      await this.assertFare(amountVnd, bounds.minFareVnd, bounds.maxFareVnd);
    } else {
      await this.assertFare(amountVnd);
    }
    // A counter can only go up from the customer's bid and at most
    // RIDE_COUNTER_MAX_PERCENT_OF_OFFER of it (the ledger enforces the lower bound too).
    const counterPercent = await this.settings.getNumber('RIDE_COUNTER_MAX_PERCENT_OF_OFFER');
    const counterCapVnd = Math.max(
      existing.offeredFareVnd,
      roundDownToFareStep((existing.offeredFareVnd * counterPercent) / 100),
    );
    if (counterPercent > 0 && amountVnd > counterCapVnd) {
      throw rideError(
        400,
        'RIDE_COUNTER_OUT_OF_RANGE',
        `A counter may be at most ${counterPercent}% of the customer's price`,
      );
    }
    const expiresAt = await this.expiresAt(now);
    const maxLiveOffers = await this.maxLiveOffers();
    const maxEdits = await this.settings.getOptionalNumber('RIDE_MAX_OFFER_EDITS_PER_DRIVER');
    const offered = await this.unwrap(() =>
      this.rides.offer({
        rideId,
        driverId: actor.userId,
        amountVnd,
        expiresAt,
        now,
        ...(dto.routeVersion !== undefined ? { routeVersion: dto.routeVersion } : {}),
        ...(maxLiveOffers > 0 ? { maxLiveOffers } : {}),
        ...(maxEdits !== undefined && maxEdits >= 0 ? { maxEdits } : {}),
      }),
    );
    this.notifyOffers(rideId, 'OFFER');
    // A driver only ever sees its own offers (no competitor amounts / driver ids).
    return onlyOwnOffers(offered, actor.userId);
  }

  async select(
    actor: RequestActor,
    rideId: string,
    idempotencyKey: string,
    dto: SelectOfferDto,
  ): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const maxConcurrentJobs = await this.settings.getNumber('MAX_CONCURRENT_JOBS_PER_DRIVER');
    const selected = await this.unwrap(() =>
      this.rides.select({
        rideId,
        customerId: actor.userId,
        offerId: dto.offerId,
        idempotencyKey,
        now: this.clock.now(),
        maxConcurrentJobs,
        voucherCode: dto.voucherCode,
      }),
    );
    this.notifyOffers(rideId, 'SELECTED');
    return selected;
  }

  async cancel(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const now = this.clock.now();
    const existing = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    const fee = existing ? await this.lateCancelPolicy(existing.vehicleClassCode) : undefined;
    const cancelled = await this.unwrap(() =>
      this.rides.cancel({
        rideId,
        customerId: actor.userId,
        now,
        ...(fee ? { fee } : {}),
      }),
    );
    this.notifyOffers(rideId, 'CANCELLED');
    return cancelled;
  }

  /**
   * Free within RIDE_FREE_CANCEL_MINUTES of assignment,
   * then a flat class fee; always charged once the driver has arrived. Cash-only, so it is
   * added to the customer's next completed ride and passed to this driver.
   */
  private async lateCancelPolicy(vehicleClassCode: string): Promise<RideFeePolicy> {
    const [freeCancelMinutes, amountVnd] = await Promise.all([
      this.settings.getNumber('RIDE_FREE_CANCEL_MINUTES'),
      this.classFee(vehicleClassCode),
    ]);
    return { freeCancelMinutes, amountVnd };
  }

  private async classFee(vehicleClassCode: string): Promise<number> {
    return this.settings.getNumber(
      isBikeClass(vehicleClassCode) ? 'RIDE_CANCEL_FEE_BIKE_VND' : 'RIDE_CANCEL_FEE_CAR_VND',
    );
  }

  /**
   * The customer lifts the bid while NEGOTIATING; pending
   * offers below the new price become ACCEPT offers at it, and the window is extended.
   */
  async raiseFare(actor: RequestActor, rideId: string, dto: RaiseFareDto): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const now = this.clock.now();
    const existing = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!existing || existing.customerId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const amountVnd = toFareStep(dto.amountVnd);
    const bounds = await this.vehicleClasses.findAny(existing.vehicleClassCode);
    await this.assertFare(amountVnd, bounds?.minFareVnd, bounds?.maxFareVnd);
    // The raised price must still respect the floor (it only goes up, but the reference may
    // have been recomputed since create).
    await this.assertBidFloor(amountVnd, existing.referenceFareVnd);
    const windowExpiresAt = await this.requestWindowEnd(now);
    const maxRaises = await this.settings.getNumber('RIDE_MAX_FARE_RAISES_PER_RIDE');
    const raised = await this.unwrap(() =>
      this.rides.raiseFare({
        rideId,
        customerId: actor.userId,
        amountVnd,
        now,
        windowExpiresAt,
        ...(maxRaises > 0 ? { maxRaises } : {}),
      }),
    );
    this.notifyOffers(rideId, 'RAISED');
    return raised;
  }

  /** The customer rejects one driver's offer (that driver may not re-offer). */
  async declineOffer(actor: RequestActor, rideId: string, dto: DeclineOfferDto): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const declined = await this.unwrap(() =>
      this.rides.declineOffer({
        rideId,
        customerId: actor.userId,
        offerId: dto.offerId,
        now: this.clock.now(),
      }),
    );
    this.notifyOffers(rideId, 'DECLINED');
    return declined;
  }

  /** A driver takes back a pending offer (may offer again within the edit limit). */
  async withdrawOffer(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    const withdrawn = await this.unwrap(() =>
      this.rides.withdrawOffer({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
    this.notifyOffers(rideId, 'WITHDRAWN');
    return onlyOwnOffers(withdrawn, actor.userId);
  }

  /**
   * The assigned driver gives the ride up before the trip starts (reason
   * required). The ride goes back to bidding with a fresh window; the cancellation counts
   * against the driver's completion rate.
   */
  async driverCancel(actor: RequestActor, rideId: string, dto: DriverCancelRideDto): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    const now = this.clock.now();
    const returned = await this.unwrap(async () =>
      this.rides.driverCancel({
        rideId,
        driverId: actor.userId,
        reasonCode: dto.reasonCode,
        now,
        windowExpiresAt: await this.requestWindowEnd(now),
      }),
    );
    this.notifyOffers(rideId, 'DRIVER_CANCELLED');
    return onlyOwnOffers(returned, actor.userId);
  }

  /**
   * The driver waited RIDE_NO_SHOW_WAIT_MINUTES at pickup; the ride is
   * cancelled as a customer no-show and the class fee is owed to this driver.
   */
  async markNoShow(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    const now = this.clock.now();
    const existing = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!existing || existing.assignedDriverId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const [waitMinutes, feeVnd] = await Promise.all([
      this.settings.getNumber('RIDE_NO_SHOW_WAIT_MINUTES'),
      this.classFee(existing.vehicleClassCode),
    ]);
    const done = await this.unwrap(() =>
      this.rides.markNoShow({ rideId, driverId: actor.userId, now, waitMinutes, feeVnd }),
    );
    this.notifyOffers(rideId, 'CANCELLED');
    return done;
  }

  /** The driver rates the customer of a ride they completed (once). */
  async rateCustomer(
    actor: RequestActor,
    rideId: string,
    dto: RateCustomerDto,
  ): Promise<{ rideId: string; stars: number; tags: string[]; comment: string | null; createdAt: string }> {
    await this.requireActiveDriver(actor.userId);
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || ride.assignedDriverId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (ride.status !== 'COMPLETED' && !(ride.status === 'CANCELLED' && ride.noShow)) {
      throw rideError(422, 'RATING_NOT_ALLOWED', 'Only completed or no-show rides can be rated');
    }
    const days = await this.settings.getNumber('RATING_WINDOW_DAYS');
    if (this.clock.now().getTime() > ride.updatedAt.getTime() + days * 86_400_000) {
      throw rideError(422, 'RATING_WINDOW_EXPIRED', 'The rating window for this ride has closed');
    }
    if (!this.customerRatings) {
      throw rideError(503, 'RATING_UNAVAILABLE', 'Customer ratings are not available');
    }
    try {
      const row = await this.customerRatings.create({
        rideId,
        customerId: ride.customerId,
        driverId: actor.userId,
        stars: dto.stars,
        tags: [...new Set<string>(dto.tags ?? [])],
        comment: dto.comment ? dto.comment : null,
      });
      return {
        rideId: row.rideId,
        stars: row.stars,
        tags: row.tags,
        comment: row.comment,
        createdAt: row.createdAt.toISOString(),
      };
    } catch (error) {
      if (error instanceof CustomerAlreadyRatedError) {
        throw rideError(409, 'RIDE_ALREADY_RATED', 'You already rated this customer for this ride');
      }
      throw error;
    }
  }

  /** Whether the driver already rated this ride's customer (snapshot for the app). */
  async customerRatingForRide(actor: RequestActor, rideId: string) {
    await this.requireActiveDriver(actor.userId);
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || ride.assignedDriverId !== actor.userId) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const row = (await this.customerRatings?.findByRide(rideId)) ?? null;
    return {
      rating: row
        ? { stars: row.stars, tags: row.tags, comment: row.comment, createdAt: row.createdAt.toISOString() }
        : null,
      customer: (await this.customerSummaries([ride.customerId])).get(ride.customerId) ?? EMPTY_CUSTOMER_RATING,
    };
  }

  /** Customer's unpaid late-cancel / no-show fees (shown before booking). */
  async pendingFees(actor: RequestActor): Promise<{ pendingFeesVnd: number }> {
    await this.requireActiveCustomer(actor.userId);
    return { pendingFeesVnd: await this.rides.pendingFeeTotal(actor.userId) };
  }

  /**
   * Worker entry: ASSIGNED rides not started within
   * RIDE_ASSIGNED_START_TIMEOUT_MINUTES and EN_ROUTE rides not arrived within
   * RIDE_EN_ROUTE_TIMEOUT_MINUTES go back to bidding (SYSTEM cancellation on the driver).
   */
  async timeoutDue(now?: Date, limit = 100): Promise<{ returnedIds: string[] }> {
    const at = now ?? this.clock.now();
    const [assignedTimeoutMinutes, enRouteTimeoutMinutes] = await Promise.all([
      this.settings.getNumber('RIDE_ASSIGNED_START_TIMEOUT_MINUTES'),
      this.settings.getNumber('RIDE_EN_ROUTE_TIMEOUT_MINUTES'),
    ]);
    const returnedIds = await this.rides.timeoutDue({
      now: at,
      policy: { assignedTimeoutMinutes, enRouteTimeoutMinutes },
      windowExpiresAt: await this.requestWindowEnd(at),
      limit,
    });
    for (const id of returnedIds) {
      this.notifyOffers(id, 'TIMEOUT');
    }
    return { returnedIds };
  }

  /** Rides drivers near `point` should hear about (fan-out helper). */
  /**
   * Who hears about a NEGOTIATING ride: `driverIds` (socket list, fresh position) and
   * `pushDriverIds` (nearest first; also drivers who stayed online but whose app is in the
   * background or killed, see DRIVER_PUSH_LOCATION_MAX_AGE_MS).
   */
  async requestAudience(
    rideId: string,
  ): Promise<{ driverIds: string[]; pushDriverIds: string[]; ride: OpenRideView } | null> {
    const now = this.clock.now();
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, now));
    if (!ride || ride.status !== 'NEGOTIATING') {
      return null;
    }
    const radiusKm = await this.settings.getNumber('DRIVER_SEARCH_RADIUS_KM');
    const nearby = await this.presence.onlineNearForPush('RIDE', ride.pickup, radiusKm, now);
    const drivers: string[] = [];
    const inRange: Array<{ id: string; km: number }> = [];
    for (const row of nearby) {
      const driverId = row.userId;
      if (driverId === ride.customerId || driverId === ride.assignedDriverId) continue;
      const km = haversineKm(row, ride.pickup);
      if (km > radiusKm) continue;
      const driverClass = await this.eligibility.driverVehicleClassCode(driverId).catch(() => null);
      if (driverClass !== ride.vehicleClassCode) continue;
      inRange.push({ id: driverId, km });
      if (row.fresh) drivers.push(driverId);
    }
    const pushDriverIds = inRange.sort((a, b) => a.km - b.km).map((d) => d.id);
    const ratings = await this.customerSummaries([ride.customerId]);
    return {
      driverIds: drivers,
      pushDriverIds,
      ride: toOpenView(
        {
          id: ride.id,
          customerId: ride.customerId,
          status: 'NEGOTIATING',
          pickup: ride.pickup,
          dropoff: ride.dropoff,
          offeredFareVnd: ride.offeredFareVnd,
          referenceFareVnd: ride.referenceFareVnd,
          vehicleClassCode: ride.vehicleClassCode,
          expiresAt: ride.expiresAt,
          offerCount: ride.offers.filter((o) => o.status === 'PENDING').length,
        } as OpenRideListing,
        await this.imageUrlForClass(ride.vehicleClassCode),
        ratings.get(ride.customerId) ?? EMPTY_CUSTOMER_RATING,
        null,
      ),
    };
  }

  async opsCancel(actor: RequestActor, rideId: string, reason: string): Promise<OpsRideView> {
    const result = await this.unwrapIntervene(() =>
      this.rides.opsCancel({ rideId, now: this.clock.now() }, actor.userId, reason),
    );
    this.notifyOffers(rideId, 'CANCELLED');
    const base = toOpsView(result.ride, await this.imageUrlForClass(result.ride.vehicleClassCode));
    return { ...base, route: await this.lookupRoute(result.ride.pickup, result.ride.dropoff, result.ride.stops) };
  }

  /** Clear assignment back to NEGOTIATING when still pre-trip. */
  async opsReassign(actor: RequestActor, rideId: string, reason: string): Promise<OpsRideView> {
    const result = await this.unwrapIntervene(() =>
      this.requestWindowEnd(this.clock.now()).then((windowExpiresAt) =>
        this.rides.opsReassign({ rideId, now: this.clock.now(), windowExpiresAt }, actor.userId, reason),
      ),
    );
    this.notifyOffers(rideId, 'REASSIGNED');
    const base = toOpsView(result.ride, await this.imageUrlForClass(result.ride.vehicleClassCode));
    return { ...base, route: await this.lookupRoute(result.ride.pickup, result.ride.dropoff, result.ride.stops) };
  }

  /** Worker entry: expire NEGOTIATING rides past expiresAt (idempotent). */
  async expireDue(now?: Date, limit = 100): Promise<{ expiredIds: string[] }> {
    const at = now ?? this.clock.now();
    const expiredIds = await this.rides.expireDue(at, limit);
    for (const id of expiredIds) {
      this.notifyOffers(id, 'EXPIRED');
    }
    return { expiredIds };
  }

  async markEnRoute(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    return this.unwrap(() =>
      this.rides.markEnRoute({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
  }

  async markArrived(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    return this.unwrap(() =>
      this.rides.markArrived({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
  }

  async startTrip(actor: RequestActor, rideId: string, pickupCode: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    // Only the assigned driver at pickup may spend attempts; anything else gets the repository's
    // usual not-found / wrong-state error below without touching the code.
    if (ride && ride.assignedDriverId === actor.userId && ride.status === 'DRIVER_ARRIVED') {
      await this.verifyPickupCode(rideId, pickupCode);
    }
    return this.unwrap(() =>
      this.rides.startTrip({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
  }

  async complete(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    // Commission differs per vehicle class; read both before the transaction and pick the
    // one matching the completed ride's class inside it.
    const [bikeFeeBps, carFeeBps] = await Promise.all([
      this.earnings.currentFeeBps('RIDE', MOTORBIKE_CLASS_CODE),
      this.earnings.currentFeeBps('RIDE', 'CAR_4'),
    ]);
    const sharedPercent = await this.settings.getNumber('VOUCHER_SHARED_PLATFORM_PERCENT');
    const completedAt = this.clock.now();
    // Online prepayment (captured − refunded) replaces cash at the door.
    const prepaid = (await this.checkout?.prepaidFor('RIDE', rideId)) ?? null;
    let collectedCashVnd = 0;
    let appliedIntentId: string | null = null;
    // COD obligation, DealGo-funded discount, earnings and fee commit with the completion.
    const ride = await this.unwrap(() =>
      this.rides.complete(
        { rideId, driverId: actor.userId, now: completedAt },
        async (tx, done) => {
          if (done.agreedFareVnd === null) {
            throw new RideRuleError('RIDE_STATUS_CONFLICT');
          }
          // DEC-PROD-024: the customer pays the fare minus the voucher in cash; the driver's
          // fare (earnings) stays whole and DealGo owes the driver its funded share.
          const split = splitCollection(cashDue(done), prepaid?.amountVnd ?? 0);
          collectedCashVnd = split.cashVnd;
          if (split.cashVnd > 0) {
            await this.ledger.postWithin(tx, 'COD_OBLIGATION_POSTED', {
              entityType: 'RIDE',
              entityId: done.id,
              amountVnd: split.cashVnd,
            });
          }
          if (split.onlineVnd > 0 && prepaid) {
            // Paid online: no cash changes hands; DealGo owes the driver what it collected.
            appliedIntentId = prepaid.intentId;
            await this.ledger.postWithin(tx, 'PSP_PREPAID_APPLIED', {
              entityType: 'RIDE',
              entityId: done.id,
              amountVnd: split.onlineVnd,
            });
            await this.earnings.adjustWithin(tx, {
              driverId: actor.userId,
              amountVnd: -split.onlineVnd,
              kind: 'ONLINE_PAYMENT_PAYOUT',
              refType: 'PAYMENT_INTENT',
              refId: prepaid.intentId,
              occurredAt: completedAt,
            });
          }
          const fundedVnd = platformFundedDiscountVnd(
            done.discountVnd,
            done.voucherSponsor,
            sharedPercent,
          );
          if (fundedVnd > 0) {
            await this.ledger.postWithin(tx, 'PROMOTION_DISCOUNT_FUNDED', {
              entityType: 'RIDE',
              entityId: done.id,
              amountVnd: fundedVnd,
            });
          }
          await this.earnings.recordWithin(tx, {
            entityType: 'RIDE',
            entityId: done.id,
            driverId: actor.userId,
            fareVnd: done.agreedFareVnd + (done.waitFeeVnd ?? 0),
            completedAt,
            feeBps: isBikeClass(done.vehicleClassCode) ? bikeFeeBps : carFeeBps,
          });
          // This driver collected earlier cancel/no-show fees in cash
          // (priorFeesVnd); it owes them to DealGo, which owes them to the driver who
          // suffered the cancellation. Same driver → nothing moves.
          for (const fee of done.collectedFees ?? []) {
            if (!fee.beneficiaryDriverId || fee.beneficiaryDriverId === actor.userId) continue;
            await this.earnings.adjustWithin(tx, {
              driverId: actor.userId,
              amountVnd: fee.amountVnd,
              kind: 'CUSTOMER_FEE_COLLECTED',
              refType: 'FEE_CHARGE',
              refId: fee.id,
              occurredAt: completedAt,
            });
            await this.earnings.adjustWithin(tx, {
              driverId: fee.beneficiaryDriverId,
              amountVnd: -fee.amountVnd,
              kind: 'CUSTOMER_FEE_PAYOUT',
              refType: 'FEE_CHARGE',
              refId: fee.id,
              occurredAt: completedAt,
            });
          }
        },
      ),
    );
    if (collectedCashVnd > 0) {
      await this.recordSandboxCodIntent('RIDE', ride.id, collectedCashVnd);
    }
    await this.checkout?.afterCompletion('RIDE', ride.id, appliedIntentId, completedAt);
    return ride;
  }

  async listForOps(
    page?: number,
    limit?: number,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<PageResult<OpsRideView>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.rides.listPage(
      safePage,
      safeLimit,
      this.clock.now(),
      filter,
    );
    const images = await this.enabledClassImageUrls(result.items);
    return {
      items: result.items.map((ride) =>
        toOpsView(ride, images.get(ride.vehicleClassCode) ?? null),
      ),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async getForOps(rideId: string): Promise<OpsRideView> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    const base = toOpsView(ride, await this.imageUrlForClass(ride.vehicleClassCode));
    return { ...base, route: await this.lookupRoute(ride.pickup, ride.dropoff, ride.stops) };
  }

  async getLedgerJournal(actor: RequestActor, rideId: string) {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || !(await this.canRead(actor.userId, ride))) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    return this.ledger.getJournal('RIDE', rideId);
  }

  private async canRead(userId: string, ride: RideSnapshot): Promise<boolean> {
    if (ride.customerId === userId) {
      return true;
    }
    if (!(await this.hasActiveGrant(userId, 'DRIVER'))) {
      return false;
    }
    const assignedToDriver =
      DRIVER_VISIBLE_STATUSES.has(ride.status) && ride.assignedDriverId === userId;
    if (assignedToDriver) {
      return true;
    }
    // NEGOTIATING: only same-class drivers may read (DG-P1-008 / RIDE-CAR-012).
    if (ride.status === 'NEGOTIATING') {
      const driverClass = await this.eligibility.driverVehicleClassCode(userId);
      return Boolean(driverClass) && driverClass === ride.vehicleClassCode;
    }
    return false;
  }

  private async requireActiveCustomer(userId: string): Promise<void> {
    if (await this.hasActiveGrant(userId, 'CUSTOMER')) {
      return;
    }
    const grants = await this.identity.listGrants(userId);
    const customerGrant = grants.find((grant) => grant.role === 'CUSTOMER');
    // Phone OTP sign-up grants CUSTOMER; accounts created before that may still lack it.
    // Dev/test backfills ACTIVE CUSTOMER here; production does not.
    if (!customerGrant && this.sandboxCustomerGrant()) {
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
    throw rideError(403, 'ROLE_NOT_ACTIVE', 'An active customer role is required');
  }

  private async requireActiveDriver(userId: string): Promise<void> {
    await this.eligibility.requireEligibleDriver(userId);
  }

  private async hasActiveGrant(userId: string, role: Extract<RoleName, 'CUSTOMER' | 'DRIVER'>): Promise<boolean> {
    const grants = await this.identity.listGrants(userId);
    return grants.some((grant) => grant.role === role && grant.status === 'ACTIVE');
  }

  private sandboxCustomerGrant(): boolean {
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    return nodeEnv === 'development' || nodeEnv === 'test';
  }

  private async imageUrlForClass(code: string): Promise<string | null> {
    const vehicle = await this.vehicleClasses.findAny(code);
    if (!vehicle?.enabled) {
      return null;
    }
    return vehicle.imageUrl;
  }

  private async enabledClassImageUrls(
    rides: readonly { vehicleClassCode: string }[],
  ): Promise<ReadonlyMap<string, string | null>> {
    if (rides.length === 0) {
      return new Map();
    }
    const rows = await this.vehicleClasses.listEnabled();
    return new Map(rows.map((row) => [row.code, row.imageUrl]));
  }

  private async requireEnabledClass(code: string | undefined) {
    const requested = code?.trim().toUpperCase();
    if (!requested) {
      throw rideError(
        400,
        'RIDE_VEHICLE_CLASS_REQUIRED',
        'vehicleClassCode is required (MOTORBIKE or CAR; no silent default)',
      );
    }
    const vehicle = await this.vehicleClasses.findEnabled(requested);
    if (!vehicle) {
      throw rideError(400, 'RIDE_VEHICLE_CLASS_UNKNOWN', 'Vehicle class is not available');
    }
    return vehicle;
  }

  private async assertFare(amountVnd: number, minimum?: number, maximum?: number): Promise<void> {
    const min = minimum ?? (await this.settings.getNumber('RIDE_MIN_FARE_VND'));
    const max = maximum ?? (await this.settings.getNumber('RIDE_MAX_FARE_VND'));
    if (!Number.isSafeInteger(amountVnd) || amountVnd < min || amountVnd > max) {
      throw rideError(400, 'RIDE_FARE_OUT_OF_RANGE', 'Fare is outside the allowed range');
    }
  }

  /** Optional sandbox COD PaymentIntent; ledger remains source of COD obligation. */
  private async recordSandboxCodIntent(
    entityType: 'RIDE',
    entityId: string,
    amountVnd: number,
  ): Promise<void> {
    try {
      await this.payments.createSandboxIntent({ entityType, entityId, amountVnd, method: 'COD' });
    } catch (error) {
      if (error instanceof UnavailablePaymentError) {
        return;
      }
      throw error;
    }
  }

  /** Per-offer TTL (RIDE_OFFER_TTL_SECONDS); the ledger caps it at the ride's window. */
  private async expiresAt(now: Date): Promise<Date> {
    const seconds = await this.settings.getNumber('RIDE_OFFER_TTL_SECONDS');
    return new Date(now.getTime() + seconds * 1000);
  }

  /**
   * How long a request stays open for bids (RIDE_REQUEST_WINDOW_SECONDS),
   * separate from each offer's own TTL. Previously the ride expired with the offer TTL.
   */
  private async requestWindowEnd(now: Date): Promise<Date> {
    const seconds = await this.settings.getNumber('RIDE_REQUEST_WINDOW_SECONDS');
    return new Date(now.getTime() + seconds * 1000);
  }

  private async assertBidFloor(amountVnd: number, referenceFareVnd: number): Promise<void> {
    const percent = await this.settings.getNumber('RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE');
    const floor = rideBidFloorVnd(referenceFareVnd, percent);
    if (floor > 0 && amountVnd < floor) {
      throw rideError(
        400,
        'RIDE_FARE_OUT_OF_RANGE',
        `Your price must be at least ${floor} VND (${percent}% of the suggested fare)`,
      );
    }
  }

  /** Pickup and drop-off inside an ACTIVE service region (SERVICE_ZONE_ENFORCED). */
  private async assertInServiceZone(
    pickup: { lat: number; lng: number },
    dropoff: { lat: number; lng: number },
    stops: ReadonlyArray<{ lat: number; lng: number }> = [],
  ): Promise<void> {
    if (!(await this.settings.getBoolean('SERVICE_ZONE_ENFORCED'))) {
      return;
    }
    if ([pickup, ...stops, dropoff].some((point) => !activeRegionCodeAt(point.lat, point.lng))) {
      throw rideError(
        422,
        'RIDE_OUTSIDE_SERVICE_ZONE',
        'DealGo does not serve this pickup or drop-off area yet',
      );
    }
  }

  private async verifyPickupCode(rideId: string, submitted: string): Promise<void> {
    const max = await this.settings.getNumber('RIDE_PICKUP_CODE_MAX_ATTEMPTS');
    const record = await this.pickupCodes.ensure(rideId, generatePickupCode());
    if (!(await this.pickupCodes.reserveAttempt(rideId, max))) {
      throw rideError(423, 'RIDE_PICKUP_CODE_LOCKED', 'Too many wrong pickup codes; contact support');
    }
    if (!pickupCodeMatches(record.code, submitted)) {
      throw rideError(422, 'RIDE_PICKUP_CODE_INVALID', 'Pickup code does not match');
    }
    await this.pickupCodes.markVerified(rideId, this.clock.now());
  }

  /**
   * Cap on live driver offers per ride from RIDE_MAX_LIVE_OFFERS_PER_RIDE (0 = unlimited, as on inDrive).
   */
  private async maxLiveOffers(): Promise<number> {
    return Math.max(0, await this.settings.getNumber('RIDE_MAX_LIVE_OFFERS_PER_RIDE'));
  }

  private async withNegotiation(view: RideView): Promise<RideView> {
    if (view.status === 'EXPIRED') {
      const raisePercent = await this.settings.getNumber('RIDE_REPOST_RAISE_HINT_PERCENT');
      const raised = view.offeredFareVnd * (1 + raisePercent / 100);
      return {
        ...view,
        repostHint: { suggestedFareVnd: roundUpToFareStep(raised), raisePercent },
      };
    }
    if (view.status !== 'NEGOTIATING') {
      return view;
    }
    const maxEdits = (await this.settings.getOptionalNumber('RIDE_MAX_OFFER_EDITS_PER_DRIVER')) ?? 0;
    const maxRaises = await this.settings.getNumber('RIDE_MAX_FARE_RAISES_PER_RIDE');
    return {
      ...view,
      negotiation: {
        maxOfferEditsPerDriver: maxEdits,
        maxFareRaises: maxRaises,
        fareRaisesLeft: maxRaises > 0 ? Math.max(0, maxRaises - view.fareRaiseCount) : null,
        maxLiveOffers: await this.maxLiveOffers(),
      },
    };
  }

  private async unwrap(work: () => Promise<RideSnapshot>): Promise<RideView> {
    try {
      const ride = await work();
      return this.withNegotiation(
        await this.withRoute(
          toView(ride, await this.imageUrlForClass(ride.vehicleClassCode)),
          ride.pickup,
          ride.dropoff,
        ),
      );
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  /** Authenticated app road geometry (same Nest provider as Admin). */
  async routeGeometry(
    actor: RequestActor,
    from: { lat: number; lng: number },
    to: { lat: number; lng: number },
    via: ReadonlyArray<{ lat: number; lng: number }> = [],
  ): Promise<RouteGeometryView> {
    // Any signed-in customer/driver session may preview a route (throttled at controller).
    if (!actor.userId) {
      throw rideError(401, 'UNAUTHORIZED', 'Unauthorized');
    }
    return this.lookupRoute(from, to, via);
  }

  private async lookupRoute(
    from: { lat: number; lng: number },
    to: { lat: number; lng: number },
    stops: ReadonlyArray<{ lat: number; lng: number }> = [],
  ): Promise<RouteGeometryView> {
    try {
      if (stops.length > 0) {
        return toRouteGeometryView(await this.routing.routeVia(waypoints(from, [...stops], to)));
      }
      return toRouteGeometryView(await this.routing.route(from, to));
    } catch {
      return { ...UNAVAILABLE_ROUTE_GEOMETRY, provider: this.routing.provider() };
    }
  }

  private async withRoute(
    view: RideView,
    from: { lat: number; lng: number },
    to: { lat: number; lng: number },
    stops: ReadonlyArray<{ lat: number; lng: number }> = view.stops,
  ): Promise<RideView> {
    return { ...view, route: await this.lookupRoute(from, to, stops) };
  }

  private async unwrapIntervene(work: () => Promise<OpsInterveneResult>): Promise<OpsInterveneResult> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private async unwrapNullable(work: () => Promise<RideSnapshot | null>): Promise<RideSnapshot | null> {
    try {
      return await work();
    } catch (error) {
      throw this.asHttp(error);
    }
  }

  private asHttp(error: unknown): unknown {
    if (error instanceof RideRuleError) {
      return rideError(error.status, error.code, error.message);
    }
    if (error instanceof VoucherRejectedError) {
      return rideError(422, error.code, error.message);
    }
    return error;
  }
}

const PICKUP_CODE_STATUSES: ReadonlySet<RideSnapshot['status']> = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
]);

const EMPTY_CUSTOMER_RATING: CustomerRatingSummary = { average: null, count: 0 };

function toOpenView(
  ride: OpenRideListing,
  imageUrl: string | null,
  customerRating: CustomerRatingSummary = EMPTY_CUSTOMER_RATING,
  pickupDistanceKm: number | null = null,
): OpenRideView {
  return {
    id: ride.id,
    status: ride.status,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    offeredFareVnd: ride.offeredFareVnd,
    referenceFareVnd: ride.referenceFareVnd,
    vehicleClassCode: ride.vehicleClassCode,
    imageUrl,
    expiresAt: ride.expiresAt.toISOString(),
    offerCount: ride.offerCount,
    customerRating,
    pickupDistanceKm,
    stops: ride.stops.map((stop) => ({ lat: stop.lat, lng: stop.lng, label: stop.label })),
    routeVersion: ride.routeVersion,
  };
}

function toView(ride: RideSnapshot, imageUrl: string | null): RideView {
  return {
    id: ride.id,
    status: ride.status,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    stops: (ride.stops ?? []).map((stop) => ({
      seq: stop.seq,
      lat: stop.lat,
      lng: stop.lng,
      label: stop.label,
      arrivedAt: stop.arrivedAt ? stop.arrivedAt.toISOString() : null,
      departedAt: stop.departedAt ? stop.departedAt.toISOString() : null,
    })),
    routeVersion: ride.routeVersion ?? 0,
    currentStopSeq:
      ride.status === 'IN_TRIP' ? ((ride.stops ?? []).find((stop) => !stop.departedAt)?.seq ?? null) : null,
    stopFeeVnd: ride.stopFeeVnd ?? 0,
    waitFeeVnd: ride.waitFeeVnd ?? 0,
    offeredFareVnd: ride.offeredFareVnd,
    referenceFareVnd: ride.referenceFareVnd,
    vehicleClassCode: ride.vehicleClassCode,
    imageUrl,
    agreedFareVnd: ride.agreedFareVnd,
    discountVnd: ride.discountVnd,
    voucherCode: ride.voucherCode,
    cashDueVnd: ride.agreedFareVnd === null ? null : cashDue(ride),
    assignedDriverId: ride.assignedDriverId,
    cancelledBy: ride.cancelledBy,
    selectedOfferId: ride.selectedOfferId,
    expiresAt: ride.expiresAt.toISOString(),
    updatedAt: ride.updatedAt.toISOString(),
    offers: ride.offers.map((offer) => ({
      id: offer.id,
      driverId: offer.driverId,
      amountVnd: offer.amountVnd,
      kind: offer.kind,
      status: offer.status,
      expiresAt: offer.expiresAt.toISOString(),
      editCount: offer.editCount ?? 0,
    })),
    route: UNAVAILABLE_ROUTE_GEOMETRY,
    assignedAt: ride.assignedAt ? ride.assignedAt.toISOString() : null,
    noShow: ride.noShow ?? false,
    cancelReasonCode: ride.cancelReasonCode ?? null,
    priorFeesVnd: ride.priorFeesVnd ?? 0,
    fareRaiseCount: ride.fareRaiseCount ?? 0,
    repostOfRideId: ride.repostOfRideId ?? null,
  };
}

export type RideNegotiationLimits = {
  maxOfferEditsPerDriver: number;
  maxFareRaises: number;
  fareRaisesLeft: number | null;
  maxLiveOffers: number;
};

/** Drivers never see other drivers' offers (amounts or ids) on the same ride. */
export function onlyOwnOffers<T extends { offers: RideOfferView[] }>(view: T, driverId: string): T {
  return { ...view, offers: view.offers.filter((offer) => offer.driverId === driverId) };
}

/**
 * DEC-PROD-024: cash the customer hands the driver (never negative). Plus earlier unpaid
 * cancel / no-show fees collected at this completion (priorFeesVnd).
 */
export function cashDue(
  ride: Pick<RideSnapshot, 'agreedFareVnd' | 'discountVnd'> & { priorFeesVnd?: number; waitFeeVnd?: number },
): number {
  return (
    Math.max(0, (ride.agreedFareVnd ?? 0) - ride.discountVnd) + (ride.priorFeesVnd ?? 0) + (ride.waitFeeVnd ?? 0)
  );
}

/** A bid, counter or raise goes up to the fare step; non-integers are left for assertFare to reject. */
function toFareStep(amountVnd: number): number {
  return Number.isSafeInteger(amountVnd) ? roundUpToFareStep(amountVnd) : amountVnd;
}
