import { HttpException, Inject, Injectable } from '@nestjs/common';
import { DRIVER_PRESENCE_REPOSITORY, IDENTITY_REPOSITORY } from './identity.constants.js';
import {
  DRIVER_LOCATION_FRESH_MS,
  type DispatchService,
  type DriverLocation,
  type DriverPresenceRepository,
  type DriverPresenceView,
  type UpsertPresenceInput,
} from './driver-presence.repository.js';
import type { IdentityRepository } from './identity.repository.js';

@Injectable()
export class DriverPresenceService {
  constructor(
    @Inject(DRIVER_PRESENCE_REPOSITORY)
    private readonly presence: DriverPresenceRepository,
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
  ) {}

  async upsert(userId: string, input: UpsertPresenceInput): Promise<DriverPresenceView> {
    await this.requireActiveDriver(userId);
    return this.presence.upsert(userId, input);
  }

  async get(userId: string): Promise<DriverPresenceView | null> {
    return this.presence.findByUserId(userId);
  }

  /** DEC-PROD-031: location heartbeat from the driver app while on duty or on a job. */
  async reportLocation(
    userId: string,
    position: { lat: number; lng: number },
    now: Date = new Date(),
  ): Promise<{ lat: number; lng: number; at: string }> {
    await this.requireActiveDriver(userId);
    await this.presence.updateLocation(userId, { ...position, at: now });
    return { lat: position.lat, lng: position.lng, at: now.toISOString() };
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

  /**
   * When a presence row exists and online=false, dispatch lists should be empty; the same
   * when the driver switched that service off (DEC-PROD-023).
   * Missing presence keeps legacy behavior (driver may browse open/ready).
   */
  async isDispatchEligible(userId: string, service?: DispatchService): Promise<boolean> {
    const row = await this.presence.findByUserId(userId);
    if (!row) {
      return true;
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
