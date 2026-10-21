import { HttpException, Inject, Injectable } from '@nestjs/common';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { PARTNER_REPOSITORY } from '../partner/partner.constants.js';
import type { PartnerRepository } from '../partner/partner.repository.js';
import { RATING_REPOSITORY } from '../rating/rating.constants.js';
import type { RatingRepository } from '../rating/rating.repository.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { maskPhone } from '../../shared/privacy/pii-mask.js';
import { FoodService } from '../food-order/food.service.js';
import { RideService } from '../ride/ride.service.js';
import {
  EMPTY_JOB_COUNTS,
  completionRate,
  mergeJobCounts,
} from '../../shared/driver-job-counts.js';

/**
 * What a customer sees about the driver on their own job: real profile name, the vehicle the
 * driver declared in their approved KYC application, and the rating summary. Replaces the
 * hardcoded driver name / plate / "⭐ 4,9" in the tracking screens.
 */
export type DriverCardView = {
  driverId: string;
  displayName: string;
  avatarUrl: string | null;
  vehiclePlate: string | null;
  vehicleType: string | null;
  ratingAverage: number | null;
  ratingCount: number;
};

const CARD_FIELD_MAX = 40;

/** Admin row enrichment: who a customer/driver id is, without credentials or full phone. */
export type OpsPersonView = {
  id: string;
  displayName: string;
  phoneMasked: string | null;
  vehiclePlate: string | null;
  vehicleType: string | null;
  /** Driver rating from customers (null when unrated or not a driver). */
  ratingAverage: number | null;
  ratingCount: number;
  /** Lifetime rides COMPLETED + food orders DELIVERED while assigned (DEC-PROD-034). */
  completedJobs: number;
  /** Completed + cancelled/failed after assignment. */
  finishedJobs: number;
  /** completedJobs / finishedJobs (0..1), null when the driver has no finished job. */
  completionRate: number | null;
};

export const OPS_PEOPLE_MAX_IDS = 100;

function cardText(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, CARD_FIELD_MAX) : null;
}

function notFound(code: string, message: string): HttpException {
  return new HttpException({ errorCode: code, message }, 404);
}

@Injectable()
export class DriverCardService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(PARTNER_REPOSITORY) private readonly partners: PartnerRepository,
    @Inject(RATING_REPOSITORY) private readonly ratings: RatingRepository,
    private readonly rides: RideService,
    private readonly food: FoodService,
  ) {}

  async forRide(actorId: string, rideId: string): Promise<DriverCardView> {
    const subject = await this.rides.ratingSubject(rideId);
    if (!subject || subject.customerId !== actorId) {
      throw notFound('RIDE_NOT_FOUND', 'Ride not found');
    }
    if (!subject.driverId) {
      throw notFound('DRIVER_NOT_ASSIGNED', 'No driver assigned yet');
    }
    return this.card(subject.driverId);
  }

  /** Card of a driver who made an offer on the customer's negotiating ride (S010 offer list). */
  async forRideOffer(actor: RequestActor, rideId: string, offerId: string): Promise<DriverCardView> {
    const subject = await this.rides.ratingSubject(rideId);
    if (!subject || subject.customerId !== actor.userId) {
      throw notFound('RIDE_NOT_FOUND', 'Ride not found');
    }
    const ride = await this.rides.get(actor, rideId);
    const offer = ride.offers.find((candidate) => candidate.id === offerId);
    if (!offer) {
      throw notFound('RIDE_OFFER_NOT_FOUND', 'Offer not found');
    }
    return this.card(offer.driverId);
  }

  async forFoodOrder(actorId: string, orderId: string): Promise<DriverCardView> {
    const subject = await this.food.ratingSubject(orderId);
    if (!subject || subject.customerId !== actorId) {
      throw notFound('FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    if (!subject.driverId) {
      throw notFound('DRIVER_NOT_ASSIGNED', 'No driver assigned yet');
    }
    return this.card(subject.driverId);
  }

  /** Batch lookup for Admin lists (rides, negotiations, drivers). Unknown ids are omitted. */
  async opsPeople(ids: string[]): Promise<OpsPersonView[]> {
    const unique = [...new Set(ids)].slice(0, OPS_PEOPLE_MAX_IDS);
    const [rideCounts, foodCounts] = await Promise.all([
      this.rides.countFinishedForDrivers(unique),
      this.food.countFinishedForDrivers(unique),
    ]);
    const jobs = mergeJobCounts(mergeJobCounts(new Map(), rideCounts), foodCounts);
    const rows = await Promise.all(
      unique.map(async (id): Promise<OpsPersonView | null> => {
        const [user, application, summary] = await Promise.all([
          this.identity.findUserById(id),
          this.partners.findByUserAndRole(id, 'DRIVER'),
          this.ratings.driverSummary(id),
        ]);
        if (!user) {
          return null;
        }
        const approved = application?.status === 'APPROVED' ? application.metadata : {};
        const counts = jobs.get(id) ?? EMPTY_JOB_COUNTS;
        return {
          id,
          displayName: cardText(user.displayName) ?? '',
          phoneMasked: maskPhone(user.phone ?? null),
          vehiclePlate: cardText(approved.vehiclePlate),
          vehicleType: cardText(approved.vehicleType),
          ratingAverage: summary.average,
          ratingCount: summary.count,
          completedJobs: counts.completed,
          finishedJobs: counts.finished,
          completionRate: completionRate(counts),
        };
      }),
    );
    return rows.filter((row): row is OpsPersonView => row !== null);
  }

  async card(driverId: string): Promise<DriverCardView> {
    const [user, application, summary] = await Promise.all([
      this.identity.findUserById(driverId),
      this.partners.findByUserAndRole(driverId, 'DRIVER'),
      this.ratings.driverSummary(driverId),
    ]);
    const approved = application?.status === 'APPROVED' ? application.metadata : {};
    return {
      driverId,
      displayName: cardText(user?.displayName) ?? '',
      avatarUrl: user?.avatarUrl ?? null,
      vehiclePlate: cardText(approved.vehiclePlate),
      vehicleType: cardText(approved.vehicleType),
      ratingAverage: summary.average,
      ratingCount: summary.count,
    };
  }
}
