import { Injectable, Logger, Optional, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import type { Subscription } from 'rxjs';
import { FoodService } from '../../food-order/food.service.js';
import { DriverLocationEvents, type DriverLocationFix } from '../../identity/driver-location-events.js';
import { RideService } from '../../ride/ride.service.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { PhaseRouteService } from './phase-route.service.js';

/** Server-side throttle per driver: drop fixes closer together than this. */
export const DRIVER_LOCATION_MIN_INTERVAL_MS = 2_000;

/**
 * Pushes each accepted driver heartbeat to the customer room of every ride / food order
 * the driver is actively serving (DEC-PROD-031, realtime). Customers no longer poll
 * GET .../driver-location; that endpoint stays as the initial snapshot + reconnect fallback.
 */
@Injectable()
export class DriverLocationFanoutService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(DriverLocationFanoutService.name);
  private readonly lastSentAt = new Map<string, number>();
  private subscription: Subscription | null = null;

  constructor(
    private readonly events: DriverLocationEvents,
    private readonly rides: RideService,
    private readonly food: FoodService,
    private readonly fanout: SnapshotFanoutService,
    @Optional() private readonly phaseRoutes?: PhaseRouteService,
  ) {}

  onModuleInit(): void {
    // Server-driven adaptive GPS: presence asks "on a job?" to pick ON_TRIP vs IDLE cadence.
    this.events.registerActiveJobProbe(async (driverId) => {
      const [rideIds, orderIds] = await Promise.all([
        this.rides.trackingRideIdsForDriver(driverId),
        this.food.trackingOrderIdsForDriver(driverId),
      ]);
      return rideIds.length + orderIds.length > 0;
    });
    this.subscription = this.events.fixes.subscribe((fix) => {
      void this.handle(fix);
    });
  }

  onModuleDestroy(): void {
    this.subscription?.unsubscribe();
    this.subscription = null;
  }

  async handle(fix: DriverLocationFix): Promise<void> {
    const last = this.lastSentAt.get(fix.driverId);
    const now = fix.at.getTime();
    if (last !== undefined && now - last < DRIVER_LOCATION_MIN_INTERVAL_MS) {
      return;
    }
    this.lastSentAt.set(fix.driverId, now);
    try {
      const [rideIds, orderIds] = await Promise.all([
        this.rides.trackingRideIdsForDriver(fix.driverId),
        this.food.trackingOrderIdsForDriver(fix.driverId),
      ]);
      const at = fix.at.toISOString();
      const motion = {
        ...(fix.heading !== undefined ? { heading: fix.heading } : {}),
        ...(fix.speedMps !== undefined ? { speedMps: fix.speedMps } : {}),
      };
      for (const id of rideIds) {
        this.fanout.emitDriverLocation({ aggregateType: 'Ride', aggregateId: id, lat: fix.lat, lng: fix.lng, at, ...motion });
      }
      for (const id of orderIds) {
        this.fanout.emitDriverLocation({ aggregateType: 'FoodOrder', aggregateId: id, lat: fix.lat, lng: fix.lng, at, ...motion });
      }
      // Phase-aware route legs piggy-back on the same throttled fix (no extra polling).
      void this.phaseRoutes?.onFix(fix, rideIds, orderIds);
      if (rideIds.length === 0 && orderIds.length === 0) {
        this.lastSentAt.delete(fix.driverId);
      }
    } catch (error) {
      this.logger.warn({ msg: 'realtime.driver_location_fanout_failed', error: String(error) });
    }
  }
}
