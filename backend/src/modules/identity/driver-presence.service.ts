import { HttpException, Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ModuleRef } from '@nestjs/core';
import type { AppEnv } from '../../platform/config/env.js';
import {
  DEFAULT_DRIVER_LOCATION_POLICY,
  policyFor,
  rejectReason,
  type DriverLocationPolicy,
  type DriverLocationPolicyConfig,
  type LocationRejectReason,
} from './driver-location-policy.js';
import { DriverLocationEvents } from './driver-location-events.js';
import { haversineKm } from '../../shared/geo/haversine.js';
import { DRIVER_PRESENCE_REPOSITORY, FOOD_ELIGIBILITY, IDENTITY_REPOSITORY } from './identity.constants.js';
import {
  DRIVER_LOCATION_FRESH_MS,
  DRIVER_PUSH_LOCATION_MAX_AGE_MS,
  type DispatchService,
  type DriverLocation,
  type DriverPresenceRepository,
  type DriverPresenceView,
  type UpsertPresenceInput,
} from './driver-presence.repository.js';
import type { IdentityRepository } from './identity.repository.js';

/** Offer/claim distance tolerance multiplier on DRIVER_SEARCH_RADIUS_KM. */
export const DRIVER_REACH_TOLERANCE = 1.5;

@Injectable()
export class DriverPresenceService {
  constructor(
    @Inject(DRIVER_PRESENCE_REPOSITORY)
    private readonly presence: DriverPresenceRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Optional() private readonly locationEvents?: DriverLocationEvents,
    @Optional() private readonly config?: ConfigService<AppEnv, true>,
    @Optional() private readonly moduleRef?: ModuleRef,
  ) {}

  /** Null when PartnerModule is not loaded (unit tests); then presence is stored as sent. */
  private foodEligibility(): FoodEligibility | null {
    try {
      return (this.moduleRef?.get(FOOD_ELIGIBILITY, { strict: false }) as FoodEligibility | undefined) ?? null;
    } catch {
      return null;
    }
  }

  /** Last accepted receive time per driver (per instance; ASSUMED good enough behind sticky LB). */
  private readonly lastAcceptedAt = new Map<string, number>();

  private policyConfig(): DriverLocationPolicyConfig {
    const read = (key: keyof AppEnv, fallback: number): number => {
      const raw = this.config?.get(key as never, { infer: true }) as unknown;
      return typeof raw === 'number' && Number.isFinite(raw) && raw > 0 ? raw : fallback;
    };
    const d = DEFAULT_DRIVER_LOCATION_POLICY;
    return {
      onTripIntervalMs: read('DRIVER_LOCATION_ON_TRIP_INTERVAL_MS', d.onTripIntervalMs),
      idleIntervalMs: read('DRIVER_LOCATION_IDLE_INTERVAL_MS', d.idleIntervalMs),
      onTripMinDistanceM: read('DRIVER_LOCATION_ON_TRIP_MIN_DISTANCE_M', d.onTripMinDistanceM),
      idleMinDistanceM: read('DRIVER_LOCATION_IDLE_MIN_DISTANCE_M', d.idleMinDistanceM),
      maxSilenceMs: read('DRIVER_LOCATION_MAX_SILENCE_MS', d.maxSilenceMs),
      minAcceptIntervalMs: read('DRIVER_LOCATION_MIN_ACCEPT_INTERVAL_MS', d.minAcceptIntervalMs),
    };
  }

  async upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView> {
    await this.requireActiveDriver(userId);
    // DEC-PROD-071: FOOD is motorbike-only. Non-motorbike drivers get foodEnabled=false
    // (default and on every write) so presence never claims a service the server refuses.
    const eligibility = this.foodEligibility();
    if (eligibility && !(await eligibility.canDeliverFood(userId).catch(() => false))) {
      return this.presence.upsert(userId, { ...input, foodEnabled: false });
    }
    return this.presence.upsert(userId, input);
  }

  async get(userId: string): Promise<DriverPresenceView | null> {
    return this.presence.findByUserId(userId);
  }

  /**
   * DEC-PROD-031: location heartbeat from the driver app (rev 2026-10-24: validated + adaptive).
   * Rejected fixes still answer 200 with accepted=false so the client keeps its cadence.
   * The response carries the reporting policy (server-driven: ON_TRIP vs IDLE).
   */
  async reportLocation(
    userId: string,
    position: { lat: number; lng: number; heading?: number; speedMps?: number; accuracyM?: number; recordedAt?: Date },
    now: Date = new Date(),
  ): Promise<ReportLocationResult> {
    await this.requireActiveDriver(userId);
    const cfg = this.policyConfig();
    const onTrip = (await this.locationEvents?.hasActiveJob(userId).catch(() => false)) ?? false;
    const policy = policyFor(onTrip ? 'ON_TRIP' : 'IDLE', cfg);
    const at = position.recordedAt ?? now;
    const reply = (accepted: boolean, reason?: LocationRejectReason): ReportLocationResult => ({
      lat: position.lat,
      lng: position.lng,
      at: at.toISOString(),
      accepted,
      ...(reason ? { reason } : {}),
      policy,
    });
    const lastAccepted = this.lastAcceptedAt.get(userId);
    if (lastAccepted !== undefined && now.getTime() - lastAccepted < cfg.minAcceptIntervalMs) {
      return reply(false, 'RATE_LIMITED');
    }
    const row = await this.presence.findByUserId(userId);
    const previous =
      row && row.lat !== null && row.lng !== null && row.locationAt
        ? { lat: row.lat, lng: row.lng, at: row.locationAt }
        : null;
    const reason = rejectReason(
      { lat: position.lat, lng: position.lng, at, ...(position.accuracyM !== undefined ? { accuracyM: position.accuracyM } : {}) },
      previous && now.getTime() - previous.at.getTime() <= DRIVER_LOCATION_FRESH_MS ? previous : null,
      now,
      DRIVER_LOCATION_FRESH_MS,
    );
    if (reason) {
      return reply(false, reason);
    }
    this.lastAcceptedAt.set(userId, now.getTime());
    await this.presence.updateLocation(userId, { lat: position.lat, lng: position.lng, at });
    // Realtime push to the tracking customer (socket); REST GET stays the snapshot.
    this.locationEvents?.publish({
      driverId: userId,
      lat: position.lat,
      lng: position.lng,
      at,
      ...(position.heading !== undefined ? { heading: position.heading } : {}),
      ...(position.speedMps !== undefined ? { speedMps: position.speedMps } : {}),
    });
    return reply(true);
  }

  /** The driver's last position when reported within DRIVER_LOCATION_FRESH_MS. */
  async freshLocation(driverId: string, now: Date): Promise<DriverLocation | null> {
    const row = await this.presence.findByUserId(driverId);
    if (!row || row.lat === null || row.lng === null || !row.locationAt) {
      return null;
    }
    if (now.getTime() - row.locationAt.getTime() > DRIVER_LOCATION_FRESH_MS) {
      return null;
    }
    return { lat: row.lat, lng: row.lng, at: row.locationAt };
  }

  /** Last position when reported within [maxAgeMs] (online drivers only). */
  private async recentLocation(driverId: string, now: Date, maxAgeMs: number): Promise<DriverLocation | null> {
    const row = await this.presence.findByUserId(driverId);
    if (!row || !row.online || row.lat === null || row.lng === null || !row.locationAt) {
      return null;
    }
    if (now.getTime() - row.locationAt.getTime() > maxAgeMs) {
      return null;
    }
    return { lat: row.lat, lng: row.lng, at: row.locationAt };
  }

  /**
   * Where to measure the dispatch radius from. Query coordinates win; otherwise the
   * driver's fresh reported position. With `requireFresh`, a driver with no presence row or no
   * fresh position gets DRIVER_LOCATION_STALE instead of an unfiltered list.
   */
  async dispatchOrigin(
    userId: string,
    query: { lat?: number; lng?: number },
    now: Date,
    requireFresh: boolean,
  ): Promise<{ lat: number; lng: number } | null> {
    if (
      query.lat !== undefined &&
      query.lng !== undefined &&
      Number.isFinite(query.lat) &&
      Number.isFinite(query.lng)
    ) {
      return { lat: query.lat, lng: query.lng };
    }
    const fix = await this.freshLocation(userId, now);
    if (fix) {
      return { lat: fix.lat, lng: fix.lng };
    }
    // Same window as the job push audience (onlineNearForPush): a driver whose
    // app was backgrounded (iOS pauses location 1–30 min) still gets
    // "Cuốc xe mới" pushes, so tapping one must list that job instead of an
    // empty / DRIVER_LOCATION_STALE feed. Taking a job still needs a live fix.
    const recent = await this.recentLocation(userId, now, DRIVER_PUSH_LOCATION_MAX_AGE_MS);
    if (recent) {
      return { lat: recent.lat, lng: recent.lng };
    }
    if (requireFresh) {
      throw new HttpException(
        {
          message: 'Go online and share your current location to see nearby requests',
          errorCode: 'DRIVER_LOCATION_STALE',
        },
        409,
      );
    }
    return null;
  }

  /**
   * RIDE-001 / FOOD-005: taking a job (offer / claim) must happen within reach of its pickup.
   * Tolerance: DRIVER_REACH_TOLERANCE × radius + 1 km for GPS drift and movement since the list
   * loaded. No usable fix → not checked here (dispatch eligibility already gates presence).
   */
  async assertWithinReach(
    userId: string,
    point: { lat: number; lng: number },
    radiusKm: number,
    now: Date,
  ): Promise<void> {
    if (!(radiusKm > 0)) return;
    const fix =
      (await this.freshLocation(userId, now)) ??
      (await this.recentLocation(userId, now, DRIVER_PUSH_LOCATION_MAX_AGE_MS));
    if (!fix) return;
    const limitKm = radiusKm * DRIVER_REACH_TOLERANCE + 1;
    if (haversineKm(fix, point) > limitKm) {
      throw new HttpException(
        { message: 'You are too far from this pickup to take it', errorCode: 'DRIVER_TOO_FAR' },
        409,
      );
    }
  }

  /** Online drivers near a point for a new / raised / returned request. */
  async onlineNear(
    service: DispatchService,
    point: { lat: number; lng: number },
    radiusKm: number,
    now: Date,
    limit = 200,
  ): Promise<string[]> {
    const rows = await this.presence.listOnlineNear({
      service,
      lat: point.lat,
      lng: point.lng,
      radiusKm,
      freshSince: new Date(now.getTime() - DRIVER_LOCATION_FRESH_MS),
      limit,
    });
    return rows.map((row) => row.userId);
  }

  /**
   * Online drivers with that service on and a last position near the point reported within
   * `maxAgeMs` (nearest-first is up to the caller). Used for job pushes, which must also reach
   * a driver whose app is in the background or killed.
   */
  async onlineNearForPush(
    service: DispatchService,
    point: { lat: number; lng: number },
    radiusKm: number,
    now: Date,
    maxAgeMs = DRIVER_PUSH_LOCATION_MAX_AGE_MS,
    limit = 200,
  ): Promise<Array<{ userId: string; lat: number; lng: number; fresh: boolean }>> {
    const rows = await this.presence.listOnlineNear({
      service,
      lat: point.lat,
      lng: point.lng,
      radiusKm,
      freshSince: new Date(now.getTime() - maxAgeMs),
      limit,
    });
    const out: Array<{ userId: string; lat: number; lng: number; fresh: boolean }> = [];
    for (const row of rows) {
      if (row.lat === null || row.lng === null || !row.locationAt) continue;
      out.push({
        userId: row.userId,
        lat: row.lat,
        lng: row.lng,
        fresh: now.getTime() - row.locationAt.getTime() <= DRIVER_LOCATION_FRESH_MS,
      });
    }
    return out;
  }

  /**
   * When a presence row exists and online=false, dispatch lists should be empty; the same
   * when the driver switched that service off (DEC-PROD-023).
   * Missing presence keeps legacy behavior (driver may browse open/ready) unless
   * `requirePresence` (DISPATCH_REQUIRE_FRESH_PRESENCE) is set — then it fails closed.
   */
  async isDispatchEligible(
    userId: string,
    service?: DispatchService,
    requirePresence = false,
  ): Promise<boolean> {
    const row = await this.presence.findByUserId(userId);
    if (!row) {
      // Parcel delivery is opt-in (DEC-PROD-071): no presence row means not opted in.
      return service === 'PARCEL' ? false : !requirePresence;
    }
    if (!row.online) {
      return false;
    }
    if (service === 'RIDE') {
      return row.rideEnabled;
    }
    if (service === 'FOOD') {
      return row.foodEnabled;
    }
    if (service === 'PARCEL') {
      return row.parcelEnabled;
    }
    return true;
  }

  private async requireActiveDriver(userId: string): Promise<void> {
    const grants = await this.identity.listGrants(userId);
    if (!grants.some((grant) => grant.role === 'DRIVER' && grant.status === 'ACTIVE')) {
      throw new HttpException(
        { message: 'An active driver role is required', errorCode: 'ROLE_NOT_ACTIVE' },
        403,
      );
    }
  }
}

export type ReportLocationResult = {
  lat: number;
  lng: number;
  at: string;
  accepted: boolean;
  reason?: LocationRejectReason;
  policy: DriverLocationPolicy;
};

export interface FoodEligibility {
  canDeliverFood(userId: string): Promise<boolean>;
}
