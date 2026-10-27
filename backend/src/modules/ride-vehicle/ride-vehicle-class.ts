/**
 * Per-class reference fare. Ops can edit these rows.
 * They bound an inDrive-style bid; they are not an approved OPEN-003 tariff.
 */
export const MOTORBIKE_CLASS_CODE = 'MOTORBIKE';

/** Two-wheeler classes (MOTORBIKE, BIKE_*) use the bike fee/commission settings; others are cars. */
export function isBikeClass(vehicleClassCode: string | null | undefined): boolean {
  return /^(MOTOR|BIKE)/i.test(vehicleClassCode ?? MOTORBIKE_CLASS_CODE);
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
  const clamped = Math.min(input.vehicle.maxFareVnd, Math.max(input.vehicle.minFareVnd, raw));
  return {
    referenceFareVnd: Math.min(MAX_STORED_VND, Math.max(0, clamped)),
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
    if (KNOWN_VEHICLE_CLASS_CODE_SET.has(code)) {
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
  return code === 'CAR_4' || code === 'CAR_7';
}

/**
 * First-boot catalog (DG-DEC-VEH-001: MOTORBIKE + CAR).
 *
 * MOTORBIKE seeds from platform fare bounds (RIDE_* settings).
 * CAR_4 / CAR_7 seeds are **DRAFT / ADMIN_EDITABLE** proposals only —
 * NOT approved OPEN-003 production tariffs. Ops edits via ride-vehicle-classes
 * Admin UI; owner may replace these numbers at any time.
 * TODO(OPEN-003): replace DRAFT seeds with owner-approved per-class tariffs.
 */
export function defaultRideVehicleClasses(settings: {
  minFareVnd: number;
  maxFareVnd: number;
  perKmVnd: number;
}): RideVehicleClass[] {
  const min = Math.max(1, money(settings.minFareVnd));
  const max = Math.max(min, money(settings.maxFareVnd));
  const perKm = Math.max(1, money(settings.perKmVnd));
  const shared = {
    enabled: true,
    imageUrl: null as string | null,
    updatedByUserId: null as string | null,
  };
  // DRAFT/ADMIN_EDITABLE Car knobs — relative to platform per-km; not production law.
  const car4PerKm = Math.max(perKm, money(perKm * 1.5));
  const car7PerKm = Math.max(car4PerKm, money(perKm * 1.75));
  return [
    {
      ...shared,
      code: MOTORBIKE_CLASS_CODE,
      name: 'Xe máy',
      seats: 1,
      sortOrder: 0,
      baseFareVnd: 0,
      perKmVnd: perKm,
      perMinuteVnd: 0,
      minFareVnd: min,
      maxFareVnd: max,
      assumedSpeedKmh: 25,
    },
    {
      ...shared,
      code: 'CAR_4',
      name: 'Xe 4 chỗ',
      seats: 4,
      sortOrder: 1,
      // DRAFT/ADMIN_EDITABLE — OPEN-003 pending owner edit
      baseFareVnd: 15_000,
      perKmVnd: car4PerKm,
      perMinuteVnd: 300,
      minFareVnd: Math.max(min, 25_000),
      maxFareVnd: Math.max(max, 800_000),
      assumedSpeedKmh: 22,
    },
    {
      ...shared,
      code: 'CAR_7',
      name: 'Xe 7 chỗ',
      seats: 7,
      sortOrder: 2,
      // DRAFT/ADMIN_EDITABLE — OPEN-003 pending owner edit
      baseFareVnd: 20_000,
      perKmVnd: car7PerKm,
      perMinuteVnd: 400,
      minFareVnd: Math.max(min, 35_000),
      maxFareVnd: Math.max(max, 1_000_000),
      assumedSpeedKmh: 20,
    },
  ];
}
