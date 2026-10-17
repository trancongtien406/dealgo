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
