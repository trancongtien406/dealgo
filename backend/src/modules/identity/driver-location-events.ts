import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { Subject, type Observable } from 'rxjs';

/** One accepted driver GPS fix (DEC-PROD-031 heartbeat), published in-process. */
export type DriverLocationFix = {
  driverId: string;
  lat: number;
  lng: number;
  at: Date;
  /** Degrees clockwise from north, when the device reported it. */
  heading?: number;
  speedMps?: number;
};

/** Answers "is this driver serving a ride/food job right now?" (registered by RealtimeModule). */
export type ActiveJobProbe = (driverId: string) => Promise<boolean>;

/**
 * In-process bus: POST /v1/me/presence/location publishes here after the row is stored;
 * RealtimeModule fans it out to the customer's `ride-location:` / `food-location:` room.
 * Cross-instance delivery rides on the Socket.IO Redis adapter, not on this bus.
 */
@Injectable()
export class DriverLocationEvents implements OnModuleDestroy {
  private readonly subject = new Subject<DriverLocationFix>();
  private probe: ActiveJobProbe | null = null;

  /** RealtimeModule registers the ride/food lookup here (identity must not import ride). */
  registerActiveJobProbe(probe: ActiveJobProbe): void {
    this.probe = probe;
  }

  async hasActiveJob(driverId: string): Promise<boolean> {
    return this.probe ? this.probe(driverId) : false;
  }

  get fixes(): Observable<DriverLocationFix> {
    return this.subject.asObservable();
  }

  publish(fix: DriverLocationFix): void {
    this.subject.next(fix);
  }

  onModuleDestroy(): void {
    this.subject.complete();
  }
}
