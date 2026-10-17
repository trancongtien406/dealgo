import { HttpException, Inject, Injectable } from '@nestjs/common';
import { DRIVER_PRESENCE_REPOSITORY, IDENTITY_REPOSITORY } from './identity.constants.js';
import type {
  DriverPresenceRepository,
  DriverPresenceView,
  UpsertPresenceInput,
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

  /**
   * When a presence row exists and online=false, dispatch lists should be empty.
   * Missing presence keeps legacy behavior (driver may browse open/ready).
   */
  async isDispatchEligible(userId: string): Promise<boolean> {
    const row = await this.presence.findByUserId(userId);
    if (!row) {
      return true;
    }
    return row.online;
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
