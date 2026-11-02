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

/** How often the re-push loop looks at open requests (the admin interval is the real throttle). */
export const RIDE_REQUEST_REPUSH_TICK_MS = 5_000;

type OpenRequest = { driverIds: Set<string>; lastPushMs: number; repushes: number };

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
  /** Requests this node announced and that may still be open → re-push + close hint. */
  private readonly openRequests = new Map<string, OpenRequest>();
  private repushTimer: ReturnType<typeof setInterval> | null = null;
  /** `${rideId}:${offerId}:${expiresAt}` → timer that announces that offer's expiry (t71u). */
  private readonly offerExpiryTimers = new Map<string, ReturnType<typeof setTimeout>>();

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
    if (process.env.NODE_ENV !== 'test') {
      this.repushTimer = setInterval(() => void this.repushOpenRequests(), RIDE_REQUEST_REPUSH_TICK_MS);
      this.repushTimer.unref?.();
    }
  }

  onModuleDestroy(): void {
    this.subscription?.unsubscribe();
    this.subscription = null;
    if (this.repushTimer) clearInterval(this.repushTimer);
    this.repushTimer = null;
    for (const timer of this.offerExpiryTimers.values()) clearTimeout(timer);
    this.offerExpiryTimers.clear();
  }

  /**
   * t71u: arm one timer per live offer at its server `expiresAt`. The ledger already refuses a
   * late select (409 RIDE_OFFER_EXPIRED); this only tells both sides promptly.
   */
  private scheduleOfferExpiry(
    rideId: string,
    offers: ReadonlyArray<{ id: string; status: string; expiresAt: string }>,
    nowMs: number,
  ): void {
    if (process.env.NODE_ENV === 'test' && !this.armTimersInTest) return;
    for (const offer of offers) {
      if (offer.status !== 'PENDING') continue;
      const expiresMs = Date.parse(offer.expiresAt);
      if (!Number.isFinite(expiresMs) || expiresMs <= nowMs) continue;
      const key = `${rideId}:${offer.id}:${offer.expiresAt}`;
      if (this.offerExpiryTimers.has(key)) continue;
      const timer = setTimeout(() => {
        this.offerExpiryTimers.delete(key);
        void this.announceOfferExpiry(rideId, offer.id, new Date());
      }, expiresMs - nowMs + 250);
      timer.unref?.();
      this.offerExpiryTimers.set(key, timer);
    }
  }

  /** Test hook: arm real expiry timers even under NODE_ENV=test. */
  armTimersInTest = false;

  /**
   * If the offer is still PENDING but past `expiresAt`, refresh the customer's offer list
   * (reason OFFER_EXPIRED → the card disappears) and tell that driver (`rideRequest` with
   * reason OFFER_EXPIRED) so their app may re-offer while the ride is still NEGOTIATING.
   */
  async announceOfferExpiry(rideId: string, offerId: string, now: Date = new Date()): Promise<boolean> {
    try {
      const snapshot = await this.rides.customerOffersSnapshot(rideId);
      if (!snapshot || snapshot.status !== 'NEGOTIATING') return false;
      const offer = snapshot.offers.find((o) => o.id === offerId);
      if (!offer || offer.status !== 'PENDING' || Date.parse(offer.expiresAt) > now.getTime()) return false;
      this.fanout.emitRideOffers({
        rideId,
        reason: 'OFFER_EXPIRED',
        status: snapshot.status,
        offers: snapshot.offers,
        revision: snapshot.updatedAt,
        at: now.toISOString(),
      });
      this.fanout.emitRideRequest([offer.driverId], {
        reason: 'OFFER_EXPIRED',
        ride: { id: rideId, status: 'NEGOTIATING', offerId, canReoffer: true },
        at: now.toISOString(),
      });
      return true;
    } catch (error) {
      this.logger.warn({ msg: 'realtime.ride_offer_expiry_failed', rideId, error: String(error) });
      return false;
    }
  }

  private track(rideId: string, driverIds: readonly string[], nowMs: number, repush: boolean): void {
    const open = this.openRequests.get(rideId) ?? { driverIds: new Set<string>(), lastPushMs: nowMs, repushes: 0 };
    for (const id of driverIds) open.driverIds.add(id);
    open.lastPushMs = nowMs;
    open.repushes = repush ? open.repushes + 1 : 0;
    this.openRequests.set(rideId, open);
  }

  /**
   * The request left NEGOTIATING (customer cancelled, picked a driver, expired): every driver
   * we alerted gets a `rideRequest` hint so their app re-syncs the feed and drops the
   * full-screen incoming-job card right away.
   */
  private closeRequest(rideId: string, reason: string, at: Date): void {
    const open = this.openRequests.get(rideId);
    if (!open) return;
    this.openRequests.delete(rideId);
    for (const key of this.lastRequestPush.keys()) {
      if (key.startsWith(`${rideId}:`)) this.lastRequestPush.delete(key);
    }
    this.fanout.emitRideRequest([...open.driverIds], {
      reason: `CLOSED_${reason}`,
      ride: { id: rideId, status: 'CLOSED' },
      at: at.toISOString(),
    });
  }

  /**
   * Grab/inDrive-style persistence: while a request stays open, nearby drivers are re-pushed
   * every RIDE_REQUEST_REPUSH_INTERVAL_SEC (0 = off), at most RIDE_REQUEST_REPUSH_MAX times.
   */
  async repushOpenRequests(now: Date = new Date()): Promise<number> {
    if (this.openRequests.size === 0) return 0;
    const setting = async (key: 'RIDE_REQUEST_REPUSH_INTERVAL_SEC' | 'RIDE_REQUEST_REPUSH_MAX', fallback: number) =>
      (await this.settings?.getOptionalNumber(key).catch(() => undefined)) ?? fallback;
    const intervalSec = await setting('RIDE_REQUEST_REPUSH_INTERVAL_SEC', 30);
    const max = await setting('RIDE_REQUEST_REPUSH_MAX', 3);
    const nowMs = now.getTime();
    let sent = 0;
    for (const [rideId, open] of [...this.openRequests]) {
      try {
        const due = intervalSec > 0 && open.repushes < max && nowMs - open.lastPushMs >= intervalSec * 1000;
        if (!due && open.repushes < max && intervalSec > 0) continue;
        const audience = await this.rides.requestAudience(rideId);
        if (!audience) {
          this.closeRequest(rideId, 'GONE', now);
          continue;
        }
        if (!due) continue; // Budget used: keep tracking only to send the close hint.
        const targets = audience.pushDriverIds ?? audience.driverIds;
        sent += await this.pushRequest(targets, audience.ride, now, { throttleMs: intervalSec * 1000 });
        if (audience.driverIds.length > 0) {
          this.fanout.emitRideRequest(audience.driverIds, { reason: 'REPEAT', ride: audience.ride, at: now.toISOString() });
        }
        this.track(rideId, targets, nowMs, true);
      } catch (error) {
        this.logger.warn({ msg: 'push.ride_request_repush_failed', rideId, error: String(error) });
      }
    }
    return sent;
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
      const targets = audience.pushDriverIds ?? audience.driverIds;
      await this.pushRequest(targets, audience.ride, change.at);
      this.track(change.rideId, [...targets, ...audience.driverIds], change.at.getTime(), false);
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
    opts: { throttleMs?: number } = {},
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
    const windowMs = Math.min(opts.throttleMs ?? RIDE_REQUEST_PUSH_DEDUPE_MS, RIDE_REQUEST_PUSH_DEDUPE_MS);
    const fresh = driverIds
      .filter((id) => {
        const last = this.lastRequestPush.get(`${ride.id}:${id}`);
        return last === undefined || nowMs - last >= windowMs;
      })
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
      if (snapshot && snapshot.status !== 'NEGOTIATING') {
        // Drivers who quoted are told too, even if this node did not announce the ride.
        this.track(change.rideId, snapshot.offers.map((o) => o.driverId), change.at.getTime(), false);
        this.closeRequest(change.rideId, change.reason, change.at);
      }
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
      if (snapshot.status === 'NEGOTIATING') {
        this.scheduleOfferExpiry(change.rideId, snapshot.offers, change.at.getTime());
      }
      await this.pushFirstOffer(change, snapshot.offers.filter((o) => o.status === 'PENDING').length);
    } catch (error) {
      this.logger.warn({ msg: 'realtime.ride_offers_fanout_failed', error: String(error) });
    }
  }
}
