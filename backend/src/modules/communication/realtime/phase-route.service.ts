import { Injectable, Logger, Optional } from '@nestjs/common';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import { FoodService } from '../../food-order/food.service.js';
import type { DriverLocationFix } from '../../identity/driver-location-events.js';
import { RideService } from '../../ride/ride.service.js';
import {
  distanceToPolylineM,
  PhaseRouteCache,
  ROUTE_MIN_REROUTE_INTERVAL_MS,
  ROUTE_OFF_ROUTE_THRESHOLD_M,
  RoutingService,
  toRouteGeometryView,
  type RouteGeometryView,
  type RoutePhase,
} from '../../routing/index.js';
import type { RouteUpdatedEventPayload } from './realtime.constants.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';

type Aggregate = 'Ride' | 'FoodOrder';
type Point = { lat: number; lng: number };
/** `via` = multi-stop TRIP stops not yet departed, in order (route goes through them). */
type Legs = { phase: RoutePhase; pickup: Point; dropoff: Point; via?: Point[] };

function viaKeyOf(via: readonly Point[] | undefined): string {
  return (via ?? []).map((p) => `${p.lat.toFixed(5)},${p.lng.toFixed(5)}`).join('|');
}

/**
 * Server-side phase route (r25: no in-app navigation). ONE Directions leg per phase:
 * APPROACH = driver fix → pickup, TRIP = pickup → dropoff (same key as the ride's overview
 * route, so usually a RoutingService cache hit). The leg is cached in [PhaseRouteCache]
 * and re-looked-up only when the driver is farther than ROUTE_OFF_ROUTE_THRESHOLD_M from it
 * AND at least ROUTE_REROUTE_MIN_INTERVAL_SECONDS passed since the last lookup (both admin
 * settings). No periodic refresh: clients derive the live ETA from the cached leg and the
 * driver's GPS. Results go to `ride:`/`food:` rooms as `routeUpdated`; an unavailable route
 * is pushed as available=false — clients never draw a straight line.
 */
@Injectable()
export class PhaseRouteService {
  private readonly logger = new Logger(PhaseRouteService.name);
  private readonly cache: PhaseRouteCache;

  constructor(
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly routing: RoutingService,
    private readonly fanout: SnapshotFanoutService,
    @Optional() cache?: PhaseRouteCache,
    @Optional() private readonly settings?: PlatformSettingsService,
  ) {
    this.cache = cache ?? new PhaseRouteCache();
  }

  async onFix(fix: DriverLocationFix, rideIds: string[], orderIds: string[]): Promise<void> {
    const tasks: Promise<void>[] = [];
    for (const id of rideIds) tasks.push(this.track('Ride', id, fix, () => this.rides.routeLegsForDriver(id, fix.driverId)));
    for (const id of orderIds) tasks.push(this.track('FoodOrder', id, fix, () => this.food.routeLegsForDriver(id, fix.driverId)));
    await Promise.all(tasks);
  }

  /** Exposed for tests. */
  forget(aggregate: Aggregate, id: string): void {
    this.cache.forget(aggregate, id);
  }

  private async track(aggregate: Aggregate, id: string, fix: DriverLocationFix, legs: () => Promise<Legs | null>): Promise<void> {
    try {
      const leg = await legs();
      if (!leg) {
        this.cache.forget(aggregate, id);
        return;
      }
      const now = fix.at.getTime();
      const prev = this.cache.get(aggregate, id, now);
      const here = { lat: fix.lat, lng: fix.lng };
      let reason: RouteUpdatedEventPayload['reason'] | null = null;
      const viaKey = leg.phase === 'TRIP' ? viaKeyOf(leg.via) : '';
      if (!prev || prev.phase !== leg.phase || (prev.viaKey ?? '') !== viaKey) {
        reason = 'INITIAL';
      } else {
        const { minIntervalMs, offRouteM } = await this.thresholds();
        if (now - prev.at >= minIntervalMs && distanceToPolylineM(here, prev.route.coords) > offRouteM) {
          reason = 'OFF_ROUTE';
        }
      }
      if (!reason) return;
      // TRIP starts as the pickup→dropoff overview; a deviation re-route starts from the driver.
      const from = leg.phase === 'APPROACH' || reason !== 'INITIAL' ? here : leg.pickup;
      const to = leg.phase === 'APPROACH' ? leg.pickup : leg.dropoff;
      const via = leg.phase === 'TRIP' ? (leg.via ?? []) : [];
      // After the first stop is left, the INITIAL overview starts from the driver too.
      const start = viaKey !== '' && prev && prev.phase === leg.phase ? here : from;
      const route = await this.lookup(start, to, via);
      this.cache.set(aggregate, id, { phase: leg.phase, route, at: now, ...(viaKey ? { viaKey } : {}) });
      this.fanout.emitRouteUpdated({
        aggregateType: aggregate,
        aggregateId: id,
        phase: leg.phase,
        reason,
        route,
        at: fix.at.toISOString(),
      });
    } catch (error) {
      this.logger.warn({ msg: 'realtime.phase_route_failed', key: `${aggregate}:${id}`, error: String(error) });
    }
  }

  private async thresholds(): Promise<{ minIntervalMs: number; offRouteM: number }> {
    let minIntervalMs = ROUTE_MIN_REROUTE_INTERVAL_MS;
    let offRouteM = ROUTE_OFF_ROUTE_THRESHOLD_M;
    if (this.settings) {
      try {
        minIntervalMs = (await this.settings.getNumber('ROUTE_REROUTE_MIN_INTERVAL_SECONDS')) * 1000;
        offRouteM = await this.settings.getNumber('ROUTE_OFF_ROUTE_THRESHOLD_M');
      } catch {
        // Settings unavailable: keep the code defaults.
      }
    }
    return { minIntervalMs, offRouteM };
  }

  private async lookup(from: Point, to: Point, via: readonly Point[] = []): Promise<RouteGeometryView> {
    try {
      if (via.length > 0) {
        return toRouteGeometryView(await this.routing.routeVia([from, ...via, to]));
      }
      return toRouteGeometryView(await this.routing.route(from, to));
    } catch {
      return { available: false, provider: this.routing.provider(), coords: [], distanceM: null, durationSec: null };
    }
  }
}
