/**
 * t73u DEC-RIDE-CROSS-REGION (AGENT_PROPOSED): intercity rides ("Liên tỉnh").
 *
 * Market pattern (Grab Chuyến Xa, Be Đi Tỉnh, inDrive Liên tỉnh): pickup must be inside a city
 * DealGo serves; the drop-off may be in another region / province. Every enabled class (bike and
 * car) by default, same bid negotiation, same dispatch around the pickup.
 * Prices come from the class / zone tariff unless ops set RIDE_INTERCITY_PRICING overrides;
 * the city max-fare cap does not apply (the % bid band still does).
 */
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import {
  normalizeIntercityClasses,
  normalizeIntercityPricing,
  type IntercityClassPricing,
} from '../../platform/settings/intercity-settings.js';
import { activeRegionCodeAt } from '../service-area/service-regions.js';

/** Largest fare the rides table stores (INT4); the bid band % is the real cap intercity. */
export const INTERCITY_UNCAPPED_MAX_FARE_VND = 2_000_000_000;

export type IntercityConfig = {
  enabled: boolean;
  /** [] = every enabled class, bike included. */
  vehicleClassCodes: string[];
  pricing: Record<string, IntercityClassPricing>;
  /** 0 = no limit. */
  maxDistanceKm: number;
};

export const INTERCITY_DISABLED: IntercityConfig = {
  enabled: false,
  vehicleClassCodes: [],
  pricing: {},
  maxDistanceKm: 0,
};

export async function loadIntercityConfig(
  settings: Pick<PlatformSettingsService, 'getBoolean' | 'getNumber' | 'getJson'>,
): Promise<IntercityConfig> {
  const enabled = await settings.getBoolean('RIDE_INTERCITY_ENABLED').catch(() => false);
  if (!enabled) return INTERCITY_DISABLED;
  const [classes, pricing, maxKm] = await Promise.all([
    settings.getJson<unknown>('RIDE_INTERCITY_VEHICLE_CLASSES').then(normalizeIntercityClasses).catch(() => []),
    settings.getJson<unknown>('RIDE_INTERCITY_PRICING').then(normalizeIntercityPricing).catch(() => ({})),
    settings.getNumber('RIDE_INTERCITY_MAX_KM').catch(() => 0),
  ]);
  return { enabled, vehicleClassCodes: classes, pricing, maxDistanceKm: Math.max(0, maxKm) };
}

/** Pickup in an ACTIVE region and a drop-off (or stop) outside that region. */
export function isIntercityTrip(
  pickup: { lat: number; lng: number },
  dropoff: { lat: number; lng: number },
  stops: ReadonlyArray<{ lat: number; lng: number }> = [],
): boolean {
  const origin = activeRegionCodeAt(pickup.lat, pickup.lng);
  if (!origin) return false;
  return [...stops, dropoff].some((point) => activeRegionCodeAt(point.lat, point.lng) !== origin);
}

export function intercityClassAllowed(config: IntercityConfig, code: string): boolean {
  return config.vehicleClassCodes.length === 0 || config.vehicleClassCodes.includes(code);
}

/** Class (already zone-priced) with the intercity overrides applied and the city max lifted. */
export function applyIntercityPricing<
  T extends { code: string; perKmVnd: number; minFareVnd: number; maxFareVnd: number },
>(vehicle: T, config: IntercityConfig): T {
  const o = config.pricing[vehicle.code] ?? {};
  const minFareVnd = o.minFareVnd ?? vehicle.minFareVnd;
  return {
    ...vehicle,
    perKmVnd: o.perKmVnd ?? vehicle.perKmVnd,
    minFareVnd,
    maxFareVnd: Math.max(minFareVnd, o.maxFareVnd ?? INTERCITY_UNCAPPED_MAX_FARE_VND),
  };
}
