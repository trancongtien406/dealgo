/**
 * Per-class reference fare. Ops can edit these rows.
 * They bound an inDrive-style bid; they are not an approved OPEN-003 tariff.
 */
export const MOTORBIKE_CLASS_CODE = 'MOTORBIKE';

/** Two-wheeler classes (MOTORBIKE, BIKE_*) use the bike fee/commission settings; others are cars. */
/** RIDE-004/005: what a class physically is; drives car KYC docs, licence and commission. */
export type VehicleKind = 'BIKE' | 'CAR';
export const VEHICLE_KINDS: readonly VehicleKind[] = ['BIKE', 'CAR'];

/** Kinds read from the catalog (refreshed whenever RideVehicleClassService loads it). */
const catalogKinds = new Map<string, VehicleKind>();

export function registerVehicleClassKinds(rows: ReadonlyArray<{ code: string; kind?: VehicleKind }>): void {
  catalogKinds.clear();
  for (const row of rows) {
    catalogKinds.set(row.code.toUpperCase(), row.kind ?? legacyVehicleKind(row.code));
  }
}

/** Backward compatibility for rows/codes without a stored kind (MOTORBIKE / CAR_4 / CAR_7). */
export function legacyVehicleKind(code: string | null | undefined): VehicleKind {
  return /^(MOTOR|BIKE)/i.test(code ?? MOTORBIKE_CLASS_CODE) ? 'BIKE' : 'CAR';
}

export function vehicleKindOf(code: string | null | undefined): VehicleKind {
  const key = (code ?? MOTORBIKE_CLASS_CODE).trim().toUpperCase();
  return catalogKinds.get(key) ?? legacyVehicleKind(key);
}

export function isBikeClass(vehicleClassCode: string | null | undefined): boolean {
  return vehicleKindOf(vehicleClassCode) === 'BIKE';
}

const MAX_STORED_VND = 2_147_483_647;

export type RideVehicleClass = {
  code: string;
  name: string;
  seats: number;
  enabled: boolean;
  baseFareVnd: number;
  perKmVnd: number;
  perMinuteVnd: number;
  minFareVnd: number;
  maxFareVnd: number;
  assumedSpeedKmh: number;
  sortOrder: number;
  imageUrl: string | null;
  /** DEC-PROD-071: bookable for parcel delivery (ops opt-in). */
  parcelEnabled: boolean;
  /** RIDE-004: BIKE | CAR (missing → derived from the legacy code). */
  kind?: VehicleKind;
  updatedByUserId: string | null;
};

export type VehicleClassQuote = {
  referenceFareVnd: number;
  durationMin: number;
  distanceComponentVnd: number;
  timeComponentVnd: number;
};

export type VehicleClassFareInput = Pick<
  RideVehicleClass,
  'baseFareVnd' | 'perKmVnd' | 'perMinuteVnd' | 'minFareVnd' | 'maxFareVnd' | 'assumedSpeedKmh'
>;

/**
 * Every ride price the server shows or settles (suggested fare, minimum bid,
 * bids, counters, raises, the agreed fare) is a whole multiple of this step,
 * so customers and drivers never see amounts like 23.487đ.
 */
export const RIDE_FARE_ROUNDING_STEP_VND = 1000;

/** Rounds up to the next {@link RIDE_FARE_ROUNDING_STEP_VND} (23.487 → 24.000). */
export function roundUpToFareStep(amountVnd: number): number {
  return Math.ceil(amountVnd / RIDE_FARE_ROUNDING_STEP_VND) * RIDE_FARE_ROUNDING_STEP_VND;
}

/** Rounds down to the previous {@link RIDE_FARE_ROUNDING_STEP_VND} (34.500 → 34.000). */
export function roundDownToFareStep(amountVnd: number): number {
  return Math.floor(amountVnd / RIDE_FARE_ROUNDING_STEP_VND) * RIDE_FARE_ROUNDING_STEP_VND;
}

/**
 * Rounds `amountVnd` up to the step, then keeps it inside the class bounds
 * using the stepped bounds (min rounded up, max rounded down). When the
 * bounds are narrower than one step, falls back to the plain clamp.
 */
export function clampToFareSteps(amountVnd: number, minVnd: number, maxVnd: number): number {
  const lo = roundUpToFareStep(minVnd);
  const hi = roundDownToFareStep(maxVnd);
  if (lo > hi) {
    return Math.min(maxVnd, Math.max(minVnd, amountVnd));
  }
  return Math.min(hi, Math.max(lo, roundUpToFareStep(amountVnd)));
}

/**
 * Highest bid / counter allowed: RIDE_BID_CEILING_PERCENT_OF_REFERENCE of the
 * suggested fare, rounded down to the step. Infinity when the ceiling is off.
 */
export function rideBidCeilingVnd(referenceFareVnd: number, ceilingPercent: number): number {
  if (ceilingPercent <= 0 || referenceFareVnd <= 0) {
    return Number.POSITIVE_INFINITY;
  }
  return roundDownToFareStep((referenceFareVnd * ceilingPercent) / 100);
}

/**
 * Lowest bid the customer may send: RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE of the
 * suggested fare, rounded up to the step. 0 when the floor is off.
 */
export function rideBidFloorVnd(referenceFareVnd: number, floorPercent: number): number {
  if (floorPercent <= 0 || referenceFareVnd <= 0) {
    return 0;
  }
  return roundUpToFareStep((referenceFareVnd * floorPercent) / 100);
}

/**
 * Round up to the fare step. A raw percent of the reference often sits between
 * two steps, and the bid ceiling is already rounded down, so rounding up can
 * land one step past the band. When the submitted amount is still within one
 * step of [capVnd], keep the cap. An amount a full step above the cap is left
 * above it so the range check rejects it.
 */
export function stepFareWithinCap(amountVnd: number, capVnd: number): number {
  if (!Number.isSafeInteger(amountVnd)) return amountVnd;
  const up = roundUpToFareStep(amountVnd);
  if (!Number.isFinite(capVnd) || up <= capVnd) return up;
  if (amountVnd > capVnd + RIDE_FARE_ROUNDING_STEP_VND - 1) return up;
  const kept = roundDownToFareStep(capVnd);
  return kept > 0 ? kept : up;
}

/**
 * Headroom the three suggestion chips may use: the configured max (ceiling − 100,
 * or the counter max − 100), or less when the stepped cap leaves a smaller gap.
 */
export function fareHeadroomPercent(baseVnd: number, maxVnd: number, configuredPercent: number): number {
  if (baseVnd <= 0 || maxVnd <= baseVnd || configuredPercent <= 0) return 0;
  const fits = Math.floor(((maxVnd - baseVnd) * 100) / baseVnd);
  return Math.min(configuredPercent, Math.max(0, fits));
}

/** Three slices of the headroom: max/3, 2×max/3, and max. 30 → 10, 20, 30. */
export function fareRaisePercents(maxHeadroomPercent: number): number[] {
  if (maxHeadroomPercent <= 0) return [];
  const first = Math.round(maxHeadroomPercent / 3);
  const second = Math.round((maxHeadroomPercent * 2) / 3);
  const out: number[] = [];
  for (const p of [first, second, maxHeadroomPercent]) {
    if (p > 0 && (out.length === 0 || out[out.length - 1] !== p)) out.push(p);
  }
  return out;
}

export function quoteVehicleClassFare(input: {
  distanceKm: number;
  vehicle: VehicleClassFareInput;
}): VehicleClassQuote {
  const km = Number.isFinite(input.distanceKm) && input.distanceKm > 0 ? input.distanceKm : 0;
  const speed = input.vehicle.assumedSpeedKmh > 0 ? input.vehicle.assumedSpeedKmh : 25;
  const durationMin = Math.round((km / speed) * 60);
  const distanceComponentVnd = Math.round(km * input.vehicle.perKmVnd);
  const timeComponentVnd = durationMin * input.vehicle.perMinuteVnd;
  const raw = input.vehicle.baseFareVnd + distanceComponentVnd + timeComponentVnd;
  return {
    referenceFareVnd: Math.min(
      MAX_STORED_VND,
      Math.max(0, clampToFareSteps(raw, input.vehicle.minFareVnd, input.vehicle.maxFareVnd)),
    ),
    durationMin,
    distanceComponentVnd,
    timeComponentVnd,
  };
}

/** Catalog codes accepted from partner KYC metadata (DG-P1-006). */
export const KNOWN_VEHICLE_CLASS_CODES = [
  MOTORBIKE_CLASS_CODE,
  'CAR_4',
  'CAR_7',
] as const;

const KNOWN_VEHICLE_CLASS_CODE_SET = new Set<string>(KNOWN_VEHICLE_CLASS_CODES);

/**
 * Class stored on a driver application (DG-P1-006 / DG-DEC-VEH-001).
 * Only an explicit `vehicleClassCode` in the catalog whitelist is accepted.
 * Unknown or missing metadata returns null (fail closed) — never silent MOTORBIKE.
 * Callers must refuse Ride listOpen / offer when null.
 */
export function vehicleClassCodeFromMetadata(
  metadata: Record<string, unknown> | null | undefined,
): string | null {
  if (!metadata) {
    return null;
  }
  const explicit = metadata.vehicleClassCode;
  if (typeof explicit === 'string' && explicit.trim()) {
    const code = explicit.trim().toUpperCase();
    if (KNOWN_VEHICLE_CLASS_CODE_SET.has(code) || catalogKinds.has(code)) {
      return code;
    }
  }
  return null;
}

function money(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.min(MAX_STORED_VND, Math.max(0, Math.round(value)));
}

export function isCarVehicleClassCode(code: string): boolean {
  const key = code.trim().toUpperCase();
  const kind = catalogKinds.get(key);
  return kind ? kind === 'CAR' : key === 'CAR_4' || key === 'CAR_7';
}

/**
 * First-boot catalog (DG-DEC-VEH-001: MOTORBIKE + CAR).
 *
 * Owner-provided tariff (pure per-km, no base / per-minute component):
 *   MOTORBIKE 5.000đ/km, min 10.000đ · CAR_4 9.000đ/km, min 20.000đ ·
 *   CAR_7 13.000đ/km, min 25.000đ.
 * Still ADMIN_EDITABLE via the ride-vehicle-classes Admin UI; OPEN-003 stays
 * open. The platform max fare (RIDE_MAX_FARE_VND) caps every class.
 */
export const DEFAULT_CLASS_TARIFF = {
  MOTORBIKE: { perKmVnd: 5_000, minFareVnd: 10_000 },
  CAR_4: { perKmVnd: 9_000, minFareVnd: 20_000 },
  CAR_7: { perKmVnd: 13_000, minFareVnd: 25_000 },
} as const;

export function defaultRideVehicleClasses(settings: {
  maxFareVnd: number;
  /** Ignored: kept so callers may still pass the platform values. */
  minFareVnd?: number;
  perKmVnd?: number;
}): RideVehicleClass[] {
  const max = Math.max(
    DEFAULT_CLASS_TARIFF.CAR_7.minFareVnd,
    money(settings.maxFareVnd),
  );
  const shared = {
    enabled: true,
    imageUrl: null as string | null,
    parcelEnabled: false,
    updatedByUserId: null as string | null,
    baseFareVnd: 0,
    perMinuteVnd: 0,
    maxFareVnd: max,
  };
  return [
    {
      ...shared,
      ...DEFAULT_CLASS_TARIFF.MOTORBIKE,
      code: MOTORBIKE_CLASS_CODE,
      kind: 'BIKE',
      name: 'Xe máy',
      seats: 1,
      sortOrder: 0,
      assumedSpeedKmh: 25,
    },
    {
      ...shared,
      ...DEFAULT_CLASS_TARIFF.CAR_4,
      code: 'CAR_4',
      kind: 'CAR',
      name: 'Xe 4 chỗ',
      seats: 4,
      sortOrder: 1,
      assumedSpeedKmh: 22,
    },
    {
      ...shared,
      ...DEFAULT_CLASS_TARIFF.CAR_7,
      code: 'CAR_7',
      kind: 'CAR',
      name: 'Xe 7 chỗ',
      seats: 7,
      sortOrder: 2,
      assumedSpeedKmh: 20,
    },
  ];
}
