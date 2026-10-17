export const RIDE_REPOSITORY = Symbol('RIDE_REPOSITORY');
export const RIDE_CLOCK = Symbol('RIDE_CLOCK');

export interface RideClock {
  now(): Date;
}

export class SystemRideClock implements RideClock {
  now(): Date {
    return new Date();
  }
}
