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
  /** t81u: make + model from the approved KYC ("Honda", "Vision"); null when not declared. */
  vehicleBrand: string | null;
  vehicleModel: string | null;
  /** "Honda Vision" — brand + model joined; null when neither was declared (client falls back to the class). */
  vehicleName: string | null;
  ratingAverage: number | null;
  ratingCount: number;
  /** t81u: lifetime rides/parcels COMPLETED + food orders DELIVERED (same rule as ops completedJobs). */
  completedTrips: number;
  /** Driver's phone for the customer of an in-progress assigned job; null on offers and finished jobs. */
  phone: string | null;
};

/** t81u: "Honda" + "Vision" → "Honda Vision"; avoids "Honda Honda Vision" when the model repeats the brand. */
export function vehicleDisplayName(brand: string | null, model: string | null): string | null {
  if (!brand && !model) return null;
  if (!brand) return model;
  if (!model) return brand;
  return model.toLowerCase().startsWith(brand.toLowerCase()) ? model : `${brand} ${model}`;
}

/**
 * What the assigned driver sees about the customer on the job: profile name, avatar and phone
 * (phone only while the job is in progress). Rating rides on the ride view.
 */
export type CustomerCardView = {
  customerId: string;
  displayName: string;
  avatarUrl: string | null;
  phone: string | null;
};

const CARD_FIELD_MAX = 80;

/**
 * Customer and assigned driver may call each other directly only while the job is running;
 * numbers stay hidden during bidding and once the job has finished.
 */
const PHONE_SHARED_STATUSES = new Set([
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
  'PICKED_UP',
]);

export function phoneSharedFor(status: string): boolean {
  return PHONE_SHARED_STATUSES.has(status);
}

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
    return this.card(subject.driverId, phoneSharedFor(subject.status));
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
    return this.card(subject.driverId, phoneSharedFor(subject.status));
  }

  /** The customer of a ride, for its assigned driver only. */
  async rideCustomer(actorId: string, rideId: string): Promise<CustomerCardView> {
    const subject = await this.rides.ratingSubject(rideId);
    if (!subject || !subject.driverId || subject.driverId !== actorId) {
      throw notFound('RIDE_NOT_FOUND', 'Ride not found');
    }
    return this.customerCard(subject.customerId, phoneSharedFor(subject.status));
  }

  /** The customer of a food order, for its assigned driver only. */
  async foodOrderCustomer(actorId: string, orderId: string): Promise<CustomerCardView> {
    const subject = await this.food.ratingSubject(orderId);
    if (!subject || !subject.driverId || subject.driverId !== actorId) {
      throw notFound('FOOD_ORDER_NOT_FOUND', 'Food order not found');
    }
    return this.customerCard(subject.customerId, phoneSharedFor(subject.status));
  }

  private async customerCard(customerId: string, sharePhone: boolean): Promise<CustomerCardView> {
    const user = await this.identity.findUserById(customerId);
    const phone = user?.phone ?? user?.contactPhone;
    return {
      customerId,
      displayName: cardText(user?.displayName) ?? '',
      avatarUrl: user?.avatarUrl ?? null,
      phone: sharePhone ? cardText(phone) : null,
    };
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
          phoneMasked: maskPhone(user.phone ?? user.contactPhone ?? null),
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

  async card(driverId: string, sharePhone = false): Promise<DriverCardView> {
    const [user, application, summary, rideCounts, foodCounts] = await Promise.all([
      this.identity.findUserById(driverId),
      this.partners.findByUserAndRole(driverId, 'DRIVER'),
      this.ratings.driverSummary(driverId),
      this.rides.countFinishedForDrivers([driverId]),
      this.food.countFinishedForDrivers([driverId]),
    ]);
    const approved = application?.status === 'APPROVED' ? application.metadata : {};
    const jobs = mergeJobCounts(mergeJobCounts(new Map(), rideCounts), foodCounts);
    const vehicleBrand = cardText(approved.vehicleBrand);
    const vehicleModel = cardText(approved.vehicleModel);
    return {
      driverId,
      displayName: cardText(user?.displayName) ?? '',
      avatarUrl: user?.avatarUrl ?? null,
      vehiclePlate: cardText(approved.vehiclePlate),
      vehicleType: cardText(approved.vehicleType),
      vehicleBrand,
      vehicleModel,
      vehicleName: vehicleDisplayName(vehicleBrand, vehicleModel),
      ratingAverage: summary.average,
      ratingCount: summary.count,
      completedTrips: (jobs.get(driverId) ?? EMPTY_JOB_COUNTS).completed,
      phone: sharePhone ? cardText(user?.phone ?? user?.contactPhone) : null,
    };
  }
}
