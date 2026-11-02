/**
 * t73u DEC-RIDE-CROSS-REGION (AGENT_PROPOSED): admin intercity settings.
 * No prices are invented here: an empty pricing map means the class / zone tariff.
 */
export interface IntercityClassPricing {
  perKmVnd?: number;
  minFareVnd?: number;
  maxFareVnd?: number;
}

const CODE = /^[A-Z0-9_]{1,32}$/;
const MAX_VND = 2_000_000_000;

/** JSON array of distinct vehicle class codes ([] = every enabled class). */
export function normalizeIntercityClasses(raw: unknown): string[] {
  if (!Array.isArray(raw) || !raw.every((c) => typeof c === 'string' && CODE.test(c))) {
    throw new Error('RIDE_INTERCITY_VEHICLE_CLASSES must be a JSON array of vehicle class codes');
  }
  return [...new Set(raw as string[])];
}

/** {"CAR_4": {"perKmVnd": 9000, "minFareVnd": 300000, "maxFareVnd": 5000000}}; every field optional. */
export function normalizeIntercityPricing(raw: unknown): Record<string, IntercityClassPricing> {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) {
    throw new Error('RIDE_INTERCITY_PRICING must be a JSON object keyed by vehicle class code');
  }
  const out: Record<string, IntercityClassPricing> = {};
  for (const [code, value] of Object.entries(raw as Record<string, unknown>)) {
    if (!CODE.test(code) || value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new Error(`RIDE_INTERCITY_PRICING.${code} must be an object`);
    }
    const entry: IntercityClassPricing = {};
    for (const field of ['perKmVnd', 'minFareVnd', 'maxFareVnd'] as const) {
      const n = (value as Record<string, unknown>)[field];
      if (n === undefined) continue;
      if (typeof n !== 'number' || !Number.isInteger(n) || n < 0 || n > MAX_VND) {
        throw new Error(`RIDE_INTERCITY_PRICING.${code}.${field} must be a whole VND amount`);
      }
      entry[field] = n;
    }
    if (entry.minFareVnd !== undefined && entry.maxFareVnd !== undefined && entry.minFareVnd > entry.maxFareVnd) {
      throw new Error(`RIDE_INTERCITY_PRICING.${code}: minFareVnd must not exceed maxFareVnd`);
    }
    out[code] = entry;
  }
  return out;
}
