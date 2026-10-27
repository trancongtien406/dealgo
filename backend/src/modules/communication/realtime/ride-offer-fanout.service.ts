import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit, Optional } from '@nestjs/common';
import { PUSH_SENDER } from '../../../integrations/push/push.constants.js';
import type { PushSender } from '../../../integrations/push/push-sender.js';
import {
  rideOfferReceivedNotification,
  rideRequestNearbyNotification,
} from '../notification/notification-audience.js';
import { AccountSettingsService } from '../../account-settings/account-settings.service.js';
import type { Subscription } from 'rxjs';
import {
  RIDE_REQUEST_BROADCAST_REASONS,
  RideOfferEvents,
  type RideOfferChange,
} from '../../ride/ride-offer-events.js';
import { RideService } from '../../ride/ride.service.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { PlatformSettingsService } from '../../../platform/settings/platform-settings.service.js';
import { pushPathFor } from '../notification/push-path.js';
import { resolveNewJobAlert } from '../notification/new-job-alert.js';

/** One push per driver per ride within this window (fare raises re-notify after it). */
export const RIDE_REQUEST_PUSH_DEDUPE_MS = 60_000;

/**
 * Bid/offer realtime (DEC-PROD-031 rev 2026-10-24): pushes the full offer list to the
 * customer-only `ride-offers:{id}` room on offer / counter / selection / cancel / expiry.
 * Drivers learn the outcome from the existing `ride:{id}` status snapshot (ASSIGNED /
 * CANCELLED / EXPIRED) and re-GET the ride, which only returns their own offers.
 */
@Injectable()
export class RideOfferFanoutService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RideOfferFanoutService.name);
  private subscription: Subscription | null = null;
  /** `${rideId}:${driverId}` → last push (ms). In-memory; the device collapse key covers multi-node. */
  private readonly lastRequestPush = new Map<string, number>();

  constructor(
    private readonly events: RideOfferEvents,
    private readonly rides: RideService,
    private readonly fanout: SnapshotFanoutService,
    @Optional() @Inject(PUSH_SENDER) private readonly push?: PushSender,
    @Optional() private readonly prefs?: AccountSettingsService,
    @Optional() private readonly settings?: PlatformSettingsService,
  ) {}

  onModuleInit(): void {
    this.subscription = this.events.changes.subscribe((change) => {
      void this.handle(change);
    });
  }

  onModuleDestroy(): void {
    this.subscription?.unsubscribe();
    this.subscription = null;
  }

  /**
   * Background push for "a driver sent a price" — only for the first pending offer so a
   * burst of bids is one notification (the open app gets every offer over the socket).
   */
  private async pushFirstOffer(change: RideOfferChange, pending: number): Promise<void> {
    if (!this.push || change.reason !== 'OFFER' || pending !== 1) {
      return;
    }
    const roles = await this.rides.participantRoles(change.rideId);
    if (!roles) {
      return;
    }
    const n = rideOfferReceivedNotification(roles.customerId, change.rideId);
    await this.push.send({
      userId: n.userId,
      title: n.title,
      body: n.body,
      data: {
        aggregateType: 'Ride',
        aggregateId: change.rideId,
        status: 'NEGOTIATING',
        eventType: 'Ride.offer.received',
        // The tap opens the offers list for this ride (was missing → app stayed on home).
        role: 'CUSTOMER',
        path: pushPathFor({ aggregateType: 'Ride', aggregateId: change.rideId, role: 'CUSTOMER', kind: 'offer' }) ?? '',
      },
    });
  }

  /**
   * Every eligible online driver
   * of the ride's class within DRIVER_SEARCH_RADIUS_KM gets the request; the customer still
   * picks among the offers.
   */
  async broadcastRequest(change: RideOfferChange): Promise<void> {
    if (!RIDE_REQUEST_BROADCAST_REASONS.has(change.reason)) {
      return;
    }
    try {
      const audience = await this.rides.requestAudience(change.rideId);
      if (!audience) {
        return;
      }
      if (audience.driverIds.length > 0) {
        this.fanout.emitRideRequest(audience.driverIds, {
          reason: change.reason,
          ride: audience.ride,
          at: change.at.toISOString(),
        });
      }
      // Push list also covers online drivers whose app is backgrounded/killed (older fix).
      await this.pushRequest(audience.pushDriverIds ?? audience.driverIds, audience.ride, change.at);
    } catch (error) {
      this.logger.warn({ msg: 'realtime.ride_request_fanout_failed', error: String(error) });
    }
  }

  /**
   * Drivers whose app is backgrounded or killed lose the socket,
   * so a nearby request also goes out as a high-priority push that expires with the request,
   * collapses per ride on the device, and is sent at most once per driver per ride per minute.
   */
  async pushRequest(
    driverIds: readonly string[],
    ride: { id: string; offeredFareVnd: number; expiresAt: string; pickup: { label: string }; dropoff: { label: string } },
    at: Date,
  ): Promise<number> {
    if (!this.push || driverIds.length === 0) {
      return 0;
    }
    // Admin settings (DEC-PROD-061 DRAFT): on/off and the nearest-first cap (0 = none).
    const enabled = this.settings ? await this.settings.getBoolean('RIDE_REQUEST_PUSH_ENABLED') : true;
    const maxDrivers = this.settings ? await this.settings.getNumber('RIDE_REQUEST_PUSH_MAX_DRIVERS') : 30;
    if (!enabled || maxDrivers <= 0) {
      return 0;
    }
    const nowMs = at.getTime();
    for (const [key, sentMs] of this.lastRequestPush) {
      if (nowMs - sentMs >= RIDE_REQUEST_PUSH_DEDUPE_MS) this.lastRequestPush.delete(key);
    }
    const fresh = driverIds
      .filter((id) => !this.lastRequestPush.has(`${ride.id}:${id}`))
      .slice(0, maxDrivers);
    const allowed = this.prefs ? await this.prefs.filterRecipients([...fresh], 'RIDE') : fresh;
    const expiresMs = Date.parse(ride.expiresAt);
    const ttlSeconds = Number.isFinite(expiresMs) ? Math.max(15, Math.floor((expiresMs - nowMs) / 1000)) : 120;
    let sent = 0;
    for (const driverId of allowed) {
      this.lastRequestPush.set(`${ride.id}:${driverId}`, nowMs);
      const n = rideRequestNearbyNotification(driverId, ride);
      try {
        await this.push.send({
          userId: n.userId,
          title: n.title,
          body: n.body,
          data: {
            aggregateType: 'Ride',
            aggregateId: ride.id,
            status: 'NEGOTIATING',
            eventType: 'Ride.request.nearby',
            role: 'DRIVER',
            path: pushPathFor({ aggregateType: 'Ride', aggregateId: ride.id, role: 'DRIVER', kind: 'request' }) ?? '/driver/jobs',
          },
          collapseKey: `ride-request-${ride.id}`,
          ttlSeconds,
          urgent: true,
          alert: await resolveNewJobAlert('NEW_RIDE', driverId, { settings: this.settings, prefs: this.prefs }),
        });
        sent += 1;
      } catch (error) {
        this.logger.warn({ msg: 'push.ride_request_failed', error: String(error) });
      }
    }
    this.logger.debug({ msg: 'push.ride_request', rideId: ride.id, audience: driverIds.length, allowed: allowed.length, sent });
    return sent;
  }

  async handle(change: RideOfferChange): Promise<void> {
    void this.broadcastRequest(change);
    try {
      const snapshot = await this.rides.customerOffersSnapshot(change.rideId);
      if (!snapshot) {
        return;
      }
      this.fanout.emitRideOffers({
        rideId: change.rideId,
        reason: change.reason,
        status: snapshot.status,
        offers: snapshot.offers,
        revision: snapshot.updatedAt,
        at: change.at.toISOString(),
      });
      await this.pushFirstOffer(change, snapshot.offers.filter((o) => o.status === 'PENDING').length);
    } catch (error) {
      this.logger.warn({ msg: 'realtime.ride_offers_fanout_failed', error: String(error) });
    }
  }
}
