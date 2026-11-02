import { Injectable } from '@nestjs/common';

/** A heartbeat older than this no longer counts as "viewing". */
const VIEW_TTL_MS = 20_000;

/**
 * Who currently has this negotiating request on screen.
 * Process-local and ephemeral: it is a display count, never an assignment input.
 */
@Injectable()
export class RideViewerPresence {
  private readonly byRide = new Map<string, Map<string, number>>();

  touch(rideId: string, driverId: string, now = Date.now()): number {
    const viewers = this.live(rideId, now);
    viewers.set(driverId, now + VIEW_TTL_MS);
    this.byRide.set(rideId, viewers);
    return viewers.size;
  }

  leave(rideId: string, driverId: string, now = Date.now()): number {
    const viewers = this.live(rideId, now);
    viewers.delete(driverId);
    if (viewers.size === 0) {
      this.byRide.delete(rideId);
      return 0;
    }
    this.byRide.set(rideId, viewers);
    return viewers.size;
  }

  count(rideId: string, now = Date.now()): number {
    return this.live(rideId, now).size;
  }

  private live(rideId: string, now: number): Map<string, number> {
    const current = this.byRide.get(rideId);
    if (!current) {
      return new Map();
    }
    for (const [driverId, until] of current) {
      if (until <= now) {
        current.delete(driverId);
      }
    }
    if (current.size === 0) {
      this.byRide.delete(rideId);
      return new Map();
    }
    return current;
  }
}
