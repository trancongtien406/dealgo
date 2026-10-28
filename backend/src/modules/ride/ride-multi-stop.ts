import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { clampToFareSteps, isBikeClass } from '../ride-vehicle/ride-vehicle-class.js';
import type { RideStopPolicy } from './ride-ledger.js';
import type { RideRuleCode } from './ride.error.js';

/** Hard cap regardless of admin settings (Mapbox Directions takes ≤ 25 coordinates). */
export const RIDE_STOPS_HARD_MAX = 5;

export type MultiStopService = 'BIKE' | 'CAR';

/** Admin-configured multi-stop rules for one service (Admin › Cài đặt). */
export type MultiStopConfig = {
  service: MultiStopService;
  /** Feature flag: false = the service only books single-destination rides. */
  enabled: boolean;
  /** Extra stops allowed between pickup and dropoff (0 = none). */
  maxStops: number;
  stopFeeVnd: number;
  freeWaitMinutes: number;
  waitFeeVndPerMinute: number;
};

export function multiStopService(vehicleClassCode: string): MultiStopService {
  return isBikeClass(vehicleClassCode) ? 'BIKE' : 'CAR';
}

export async function loadMultiStopConfig(
  settings: Pick<PlatformSettingsService, 'getBoolean' | 'getNumber'>,
  service: MultiStopService,
): Promise<MultiStopConfig> {
  const bike = service === 'BIKE';
  const [enabled, maxStops, stopFeeVnd, freeWaitMinutes, waitFeeVndPerMinute] = await Promise.all([
    settings.getBoolean(bike ? 'RIDE_MULTI_STOP_BIKE_ENABLED' : 'RIDE_MULTI_STOP_CAR_ENABLED'),
    settings.getNumber(bike ? 'RIDE_MAX_STOPS_BIKE' : 'RIDE_MAX_STOPS_CAR'),
    settings.getNumber(bike ? 'RIDE_STOP_FEE_BIKE_VND' : 'RIDE_STOP_FEE_CAR_VND'),
    settings.getNumber('RIDE_STOP_FREE_WAIT_MINUTES'),
    settings.getNumber('RIDE_STOP_WAIT_FEE_VND_PER_MINUTE'),
  ]);
  const max = Math.max(0, Math.min(RIDE_STOPS_HARD_MAX, Math.floor(maxStops)));
  return {
    service,
    enabled: enabled && max > 0,
    maxStops: enabled ? max : 0,
    stopFeeVnd: Math.max(0, Math.floor(stopFeeVnd)),
    freeWaitMinutes: Math.max(0, Math.floor(freeWaitMinutes)),
    waitFeeVndPerMinute: Math.max(0, Math.floor(waitFeeVndPerMinute)),
  };
}

/** null = ok. Zero stops is always allowed (single destination works with the flag off). */
export function stopsRuleError(stopCount: number, config: MultiStopConfig): RideRuleCode | null {
  if (stopCount === 0) return null;
  if (!config.enabled) return 'RIDE_STOPS_DISABLED';
  if (stopCount > config.maxStops) return 'RIDE_TOO_MANY_STOPS';
  return null;
}

export function stopPolicy(config: MultiStopConfig): RideStopPolicy {
  return {
    feeVnd: config.stopFeeVnd,
    freeWaitMinutes: config.freeWaitMinutes,
    waitFeeVndPerMinute: config.waitFeeVndPerMinute,
  };
}

/**
 * Reference fare with stops: distance fare over every leg + per-stop fee, kept inside the class
 * window (the customer still bids; this only moves the suggested price and the bid floor).
 */
export function referenceWithStopsVnd(
  distanceReferenceVnd: number,
  stopCount: number,
  stopFeeVnd: number,
  bounds: { minFareVnd: number; maxFareVnd: number },
): number {
  if (stopCount <= 0) return distanceReferenceVnd;
  return clampToFareSteps(distanceReferenceVnd + stopCount * stopFeeVnd, bounds.minFareVnd, bounds.maxFareVnd);
}

/** pickup → stops… → dropoff, in visiting order. */
export function waypoints<P extends { lat: number; lng: number }>(pickup: P, stops: readonly P[], dropoff: P): P[] {
  return [pickup, ...stops, dropoff];
}
