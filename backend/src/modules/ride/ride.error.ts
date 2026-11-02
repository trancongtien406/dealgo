import { HttpException } from '@nestjs/common';

export function rideError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ message, errorCode }, status);
}

export const RIDE_RULES = {
  RIDE_ALREADY_OPEN: { status: 409, message: 'A negotiating ride is already open' },
  RIDE_NOT_FOUND: { status: 404, message: 'Ride not found' },
  RIDE_SELF_OFFER: { status: 403, message: 'You cannot offer on your own ride' },
  RIDE_OFFER_UNAVAILABLE: { status: 409, message: 'That offer is no longer available' },
  RIDE_NEGOTIATION_ROUNDS_EXCEEDED: {
    status: 409,
    message: 'Negotiation round limit reached for this ride',
  },
  // Correct name — the cap is on live offers from different drivers, not rounds.
  RIDE_LIVE_OFFERS_FULL: {
    status: 409,
    message: 'This ride already has the maximum number of live offers',
  },
  RIDE_FARE_RAISE_LIMIT: { status: 409, message: 'You cannot raise the fare on this ride again' },
  // Too many cancellations after a driver was assigned.
  RIDE_CANCEL_COOLDOWN: {
    status: 429,
    message: 'Too many cancelled rides recently; please try again later',
  },
  RIDE_REPOST_INVALID: { status: 409, message: 'Only your own expired request can be re-posted' },
  RIDE_OFFER_EXPIRED: { status: 409, message: 'That offer has expired' },
  RIDE_ALREADY_ASSIGNED: { status: 409, message: 'The ride is already assigned' },
  RIDE_NOT_NEGOTIATING: { status: 409, message: 'The ride is not open for negotiation' },
  RIDE_NOT_ASSIGNED_DRIVER: { status: 403, message: 'Only the assigned driver may perform this action' },
  RIDE_STATUS_CONFLICT: { status: 409, message: 'The ride is not in the required status' },
  RIDE_NOT_CANCELLABLE: { status: 409, message: 'The ride can no longer be cancelled' },
  DRIVER_AT_CAPACITY: {
    status: 409,
    message: 'Driver is at max concurrent jobs',
  },
  // Negotiation / lifecycle rules.
  RIDE_OFFER_EDIT_LIMIT: { status: 409, message: 'You cannot change this offer again' },
  RIDE_OFFER_DECLINED: { status: 409, message: 'The customer declined your offer on this ride' },
  RIDE_COUNTER_OUT_OF_RANGE: { status: 400, message: 'The offer is outside the allowed range' },
  RIDE_FARE_OUT_OF_RANGE: { status: 400, message: 'The fare is outside the allowed range' },
  RIDE_FARE_RAISE_INVALID: { status: 400, message: 'The new fare must be higher than the current one' },
  RIDE_NO_SHOW_TOO_EARLY: { status: 409, message: 'Wait a little longer before reporting a no-show' },
  RIDE_CANCEL_REASON_REQUIRED: { status: 400, message: 'A cancellation reason is required' },
  RIDE_ALREADY_RATED: { status: 409, message: 'This ride has already been rated' },
  RIDE_OUTSIDE_SERVICE_ZONE: { status: 422, message: 'The pickup is outside our service area' },
  RIDE_CROSS_REGION_NOT_SUPPORTED: {
    status: 422,
    message: 'Trips between service regions are not supported yet',
  },
  // t73u intercity (Liên tỉnh).
  RIDE_INTERCITY_STOPS_NOT_SUPPORTED: { status: 422, message: 'Intercity trips go straight to one destination' },
  RIDE_INTERCITY_TOO_FAR: { status: 422, message: 'This intercity trip is longer than allowed' },
  RIDE_INTERCITY_VEHICLE_NOT_ALLOWED: { status: 422, message: 'This vehicle class does not run intercity trips' },
  RIDE_INTERCITY_NO_VEHICLE: { status: 422, message: 'No vehicle class is available for intercity trips' },
  DRIVER_LOCATION_STALE: {
    status: 409,
    message: 'Go online and share your current location to see nearby requests',
  },
  // Multi-stop rides.
  RIDE_STOPS_DISABLED: { status: 400, message: 'Multi-stop rides are not available for this service' },
  RIDE_TOO_MANY_STOPS: { status: 400, message: 'Too many stops for this service' },
  RIDE_STOPS_LOCKED: { status: 409, message: 'Stops can only be changed before a driver is chosen' },
  RIDE_ROUTE_CHANGED: { status: 409, message: 'The customer changed the route; review it and offer again' },
  RIDE_STOP_OUT_OF_ORDER: { status: 409, message: 'Stops must be visited in order' },
  RIDE_STOPS_PENDING: { status: 409, message: 'Finish every stop before completing the ride' },
  DRIVER_DEBT_LIMIT_REACHED: {
    status: 403,
    message: 'Settle your outstanding platform fees to keep receiving jobs',
  },
} as const;

export type RideRuleCode = keyof typeof RIDE_RULES;

export class RideRuleError extends Error {
  readonly status: number;
  readonly code: RideRuleCode;

  constructor(code: RideRuleCode) {
    const rule = RIDE_RULES[code];
    super(rule.message);
    this.name = 'RideRuleError';
    this.code = code;
    this.status = rule.status;
  }
}
