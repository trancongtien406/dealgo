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
import { UniqueConflictError, type IdentityRepository, type RoleName } from '../identity/identity.repository.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { MAPS_PORT } from '../../integrations/maps/maps.constants.js';
import { resolveRouteDistanceKm, type MapsPort } from '../../integrations/maps/maps-port.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { PartnerEligibilityService } from '../partner/partner-eligibility.service.js';
import { PAYMENT_PORT } from '../payment/payment.constants.js';
import type { PaymentPort } from '../payment/payment-port.js';
import { UnavailablePaymentError } from '../payment/payment-port.js';
import { quoteReferenceFareVnd } from './ride-geo.js';
import type { OpenRideListing, RideSnapshot } from './ride-ledger.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from './ride.constants.js';
import type { CreateOfferDto, CreateRideDto, SelectOfferDto } from './ride.dto.js';
import { RideRuleError, rideError } from './ride.error.js';
import type { OpsInterveneResult, RideRepository } from './ride.repository.js';

export type RideOfferView = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: 'ACCEPT' | 'COUNTER';
  status: 'PENDING' | 'SELECTED' | 'LOST';
  expiresAt: string;
};

export type OpenRideView = {
  id: string;
  status: 'NEGOTIATING';
  pickup: { lat: number; lng: number; label: string };
  dropoff: { lat: number; lng: number; label: string };
  offeredFareVnd: number;
  referenceFareVnd: number;
  expiresAt: string;
  offerCount: number;
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
  offeredFareVnd: number;
  referenceFareVnd: number;
  agreedFareVnd: number | null;
  assignedDriverId: string | null;
  selectedOfferId: string | null;
  expiresAt: string;
  offers: RideOfferView[];
};

const DRIVER_VISIBLE_STATUSES = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
  'COMPLETED',
]);

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
  ) {}

  async create(actor: RequestActor, idempotencyKey: string, dto: CreateRideDto): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    await this.assertFare(dto.offeredFareVnd);
    const now = this.clock.now();
    const minimum = await this.settings.getNumber('RIDE_MIN_FARE_VND');
    const perKm = await this.settings.getNumber('RIDE_REFERENCE_VND_PER_KM');
    const distanceKm = await resolveRouteDistanceKm(this.maps, dto.pickup, dto.dropoff);
    const expiresAt = await this.expiresAt(now);
    return this.unwrap(() =>
      this.rides.create({
        customerId: actor.userId,
        idempotencyKey,
        pickup: dto.pickup,
        dropoff: dto.dropoff,
        offeredFareVnd: dto.offeredFareVnd,
        referenceFareVnd: quoteReferenceFareVnd(distanceKm, perKm, minimum),
        expiresAt,
        now,
      }),
    );
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
    return {
      items: result.items.map(toView),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async listOpen(actor: RequestActor, query: DispatchQuery = {}): Promise<OpenRideView[]> {
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
    const rides = await this.rides.listOpen(this.clock.now(), fetchLimit);
    const filtered = filterByDispatchRadius(
      rides,
      query,
      radiusKm,
      fallbackLimit,
      (ride) => ride.pickup,
    );
    return filtered.map(toOpenView);
  }

  async get(actor: RequestActor, rideId: string): Promise<RideView> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride || !(await this.canRead(actor.userId, ride))) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (ride.customerId === actor.userId) {
      await this.requireActiveCustomer(actor.userId);
    }
    return toView(ride);
  }

  /** Socket room join uses the same participant checks as GET /rides/:id. */
  async canSubscribe(userId: string, rideId: string): Promise<boolean> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return false;
    }
    return this.canRead(userId, ride);
  }

  /** Status + updatedAt for contact-window checks (chat/voice). */
  async contactMeta(rideId: string): Promise<{ status: string; updatedAt: Date } | null> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      return null;
    }
    return { status: ride.status, updatedAt: ride.updatedAt };
  }

  /** Known participant userIds for push fan-out (customer + assigned driver). */
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
    await this.assertFare(dto.amountVnd);
    const now = this.clock.now();
    const expiresAt = await this.expiresAt(now);
    const maxRounds = await this.settings.getOptionalNumber('RIDE_NEGOTIATION_MAX_ROUNDS');
    return this.unwrap(() =>
      this.rides.offer({
        rideId,
        driverId: actor.userId,
        amountVnd: dto.amountVnd,
        expiresAt,
        now,
        ...(maxRounds !== undefined && maxRounds > 0 ? { maxRounds } : {}),
      }),
    );
  }

  async select(
    actor: RequestActor,
    rideId: string,
    idempotencyKey: string,
    dto: SelectOfferDto,
  ): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    const maxConcurrentJobs = await this.settings.getNumber('MAX_CONCURRENT_JOBS_PER_DRIVER');
    return this.unwrap(() =>
      this.rides.select({
        rideId,
        customerId: actor.userId,
        offerId: dto.offerId,
        idempotencyKey,
        now: this.clock.now(),
        maxConcurrentJobs,
      }),
    );
  }

  async cancel(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveCustomer(actor.userId);
    return this.unwrap(() =>
      this.rides.cancel({
        rideId,
        customerId: actor.userId,
        now: this.clock.now(),
      }),
    );
  }

  async opsCancel(actor: RequestActor, rideId: string, reason: string): Promise<RideView> {
    const result = await this.unwrapIntervene(() =>
      this.rides.opsCancel({ rideId, now: this.clock.now() }, actor.userId, reason),
    );
    return toView(result.ride);
  }

  /** Clear assignment back to NEGOTIATING when still pre-trip. */
  async opsReassign(actor: RequestActor, rideId: string, reason: string): Promise<RideView> {
    const result = await this.unwrapIntervene(() =>
      this.rides.opsReassign({ rideId, now: this.clock.now() }, actor.userId, reason),
    );
    return toView(result.ride);
  }

  /** Worker entry: expire NEGOTIATING rides past expiresAt (idempotent). */
  async expireDue(now?: Date, limit = 100): Promise<{ expiredIds: string[] }> {
    const at = now ?? this.clock.now();
    const expiredIds = await this.rides.expireDue(at, limit);
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

  async startTrip(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    return this.unwrap(() =>
      this.rides.startTrip({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
  }

  async complete(actor: RequestActor, rideId: string): Promise<RideView> {
    await this.requireActiveDriver(actor.userId);
    const ride = await this.unwrap(() =>
      this.rides.complete({ rideId, driverId: actor.userId, now: this.clock.now() }),
    );
    if (ride.agreedFareVnd === null) {
      throw rideError(409, 'RIDE_STATUS_CONFLICT', 'Completed ride is missing agreed fare');
    }
    await this.ledger.postCodObligation({
      entityType: 'RIDE',
      entityId: ride.id,
      amountVnd: ride.agreedFareVnd,
    });
    await this.recordSandboxCodIntent('RIDE', ride.id, ride.agreedFareVnd);
    return ride;
  }

  async listForOps(
    page?: number,
    limit?: number,
    filter?: { status?: string; q?: string; zone?: string; serviceType?: string },
  ): Promise<PageResult<RideView>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const result = await this.rides.listPage(
      safePage,
      safeLimit,
      this.clock.now(),
      filter,
    );
    return {
      items: result.items.map(toView),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async getForOps(rideId: string): Promise<RideView> {
    const ride = await this.unwrapNullable(() => this.rides.findById(rideId, this.clock.now()));
    if (!ride) {
      throw rideError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    return toView(ride);
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
    return ride.status === 'NEGOTIATING' || assignedToDriver;
  }

  private async requireActiveCustomer(userId: string): Promise<void> {
    if (await this.hasActiveGrant(userId, 'CUSTOMER')) {
      return;
    }
    const grants = await this.identity.listGrants(userId);
    const customerGrant = grants.find((grant) => grant.role === 'CUSTOMER');
    // Phone login creates a user with no role. Dev/test issues ACTIVE CUSTOMER; production does not.
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

  private async assertFare(amountVnd: number): Promise<void> {
    const minimum = await this.settings.getNumber('RIDE_MIN_FARE_VND');
    const maximum = await this.settings.getNumber('RIDE_MAX_FARE_VND');
    if (!Number.isSafeInteger(amountVnd) || amountVnd < minimum || amountVnd > maximum) {
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

  private async expiresAt(now: Date): Promise<Date> {
    const seconds = await this.settings.getNumber('RIDE_OFFER_TTL_SECONDS');
    return new Date(now.getTime() + seconds * 1000);
  }

  private async unwrap(work: () => Promise<RideSnapshot>): Promise<RideView> {
    try {
      return toView(await work());
    } catch (error) {
      throw this.asHttp(error);
    }
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
    return error;
  }
}

function toOpenView(ride: OpenRideListing): OpenRideView {
  return {
    id: ride.id,
    status: ride.status,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    offeredFareVnd: ride.offeredFareVnd,
    referenceFareVnd: ride.referenceFareVnd,
    expiresAt: ride.expiresAt.toISOString(),
    offerCount: ride.offerCount,
  };
}

function toView(ride: RideSnapshot): RideView {
  return {
    id: ride.id,
    status: ride.status,
    pickup: ride.pickup,
    dropoff: ride.dropoff,
    offeredFareVnd: ride.offeredFareVnd,
    referenceFareVnd: ride.referenceFareVnd,
    agreedFareVnd: ride.agreedFareVnd,
    assignedDriverId: ride.assignedDriverId,
    selectedOfferId: ride.selectedOfferId,
    expiresAt: ride.expiresAt.toISOString(),
    offers: ride.offers.map((offer) => ({
      id: offer.id,
      driverId: offer.driverId,
      amountVnd: offer.amountVnd,
      kind: offer.kind,
      status: offer.status,
      expiresAt: offer.expiresAt.toISOString(),
    })),
  };
}
