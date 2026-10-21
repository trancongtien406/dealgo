import { createHash, randomBytes } from 'node:crypto';
import { HttpException, Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/index.js';
import { maskPersonName } from '../../shared/privacy/pii-mask.js';
import { DriverCardService } from '../driver-card/driver-card.service.js';
import { RideService } from '../ride/ride.service.js';
import { RIDE_SHARE_REPOSITORY, type RideShareRepository } from './ride-share.repository.js';

/** Rides a customer may share: a driver is assigned and the trip is not over. */
export const SHAREABLE_RIDE_STATUSES = ['ASSIGNED', 'DRIVER_EN_ROUTE', 'DRIVER_ARRIVED', 'IN_TRIP'] as const;
const FINISHED = new Set(['COMPLETED', 'CANCELLED', 'EXPIRED']);
/** A link lives at most this long. */
export const RIDE_SHARE_TTL_MS = 12 * 60 * 60 * 1000;
/** After the trip ends the page stays readable briefly so family see the outcome. */
export const RIDE_SHARE_AFTER_END_MS = 30 * 60 * 1000;
export const RIDE_SHARE_MAX_ACTIVE = 5;
export const RIDE_SHARE_PATH = '/chia-se-chuyen';

export type RideShareLinkView = { url: string; token: string; expiresAt: string };

export type PublicRideShareView = {
  status: string;
  pickupLabel: string;
  dropoffLabel: string;
  driver: {
    name: string | null;
    vehiclePlate: string | null;
    vehicleType: string | null;
    ratingAverage: number | null;
  } | null;
  updatedAt: string;
  expiresAt: string;
};

function httpError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

export function hashShareToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

@Injectable()
export class RideShareService {
  constructor(
    @Inject(RIDE_SHARE_REPOSITORY) private readonly links: RideShareRepository,
    private readonly rides: RideService,
    private readonly cards: DriverCardService,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async create(customerId: string, rideId: string, now = new Date()): Promise<RideShareLinkView> {
    const ride = await this.rides.shareSnapshot(rideId);
    if (!ride || ride.customerId !== customerId) {
      throw httpError(404, 'RIDE_NOT_FOUND', 'Ride not found');
    }
    if (!(SHAREABLE_RIDE_STATUSES as readonly string[]).includes(ride.status) || !ride.assignedDriverId) {
      throw httpError(409, 'RIDE_SHARE_NOT_ACTIVE', 'Only an ongoing trip with a driver can be shared');
    }
    if ((await this.links.countActive(rideId, now)) >= RIDE_SHARE_MAX_ACTIVE) {
      throw httpError(429, 'RIDE_SHARE_LIMIT', 'Too many active share links for this trip');
    }
    const token = randomBytes(24).toString('base64url');
    const expiresAt = new Date(now.getTime() + RIDE_SHARE_TTL_MS);
    await this.links.create({
      rideId,
      tokenHash: hashShareToken(token),
      createdByUserId: customerId,
      expiresAt,
    });
    return { url: `${this.baseUrl()}${RIDE_SHARE_PATH}/${token}`, token, expiresAt: expiresAt.toISOString() };
  }

  async view(token: string, now = new Date()): Promise<PublicRideShareView> {
    const link = /^[A-Za-z0-9_-]{20,64}$/.test(token)
      ? await this.links.findByHash(hashShareToken(token))
      : null;
    if (!link) {
      throw httpError(404, 'RIDE_SHARE_NOT_FOUND', 'Share link not found');
    }
    const ride = await this.rides.shareSnapshot(link.rideId);
    const endedTooLongAgo =
      ride && FINISHED.has(ride.status) && now.getTime() - ride.updatedAt.getTime() > RIDE_SHARE_AFTER_END_MS;
    if (!ride || link.expiresAt <= now || endedTooLongAgo) {
      throw httpError(410, 'RIDE_SHARE_EXPIRED', 'Share link expired');
    }
    let driver: PublicRideShareView['driver'] = null;
    if (ride.assignedDriverId) {
      const card = await this.cards.card(ride.assignedDriverId);
      driver = {
        name: maskPersonName(card.displayName),
        vehiclePlate: card.vehiclePlate,
        vehicleType: card.vehicleType,
        ratingAverage: card.ratingAverage,
      };
    }
    return {
      status: ride.status,
      pickupLabel: ride.pickup.label,
      dropoffLabel: ride.dropoff.label,
      driver,
      updatedAt: ride.updatedAt.toISOString(),
      expiresAt: link.expiresAt.toISOString(),
    };
  }

  private baseUrl(): string {
    const raw = this.config.get('PUBLIC_WEB_BASE_URL', { infer: true })?.trim();
    return (raw || 'http://localhost:3000').replace(/\/+$/, '');
  }
}
