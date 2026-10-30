/**
 * DEC-PROD-071 (DRAFT): parcel size classes (admin setting PARCEL_SIZE_CLASSES).
 * Figures are DRAFT defaults inside the market range in docs/research/parcel-delivery-research.md;
 * admins edit them, code never hard-codes a tariff.
 */
export const PARCEL_SIZE_CODES = ['S', 'M', 'L', 'XL'] as const;
export type ParcelSizeCode = (typeof PARCEL_SIZE_CODES)[number];

export type ParcelSizeClassConfig = {
  code: ParcelSizeCode;
  label: string;
  maxWeightKg: number;
  /** Longest sides in cm (L, W, H). */
  maxDimsCm: [number, number, number];
  /** Added to the server reference fare (VND, whole thousands). */
  surchargeVnd: number;
  /** Vehicle classes allowed to carry this size. */
  vehicleClassCodes: string[];
  enabled: boolean;
};

export const PARCEL_SIZE_CLASSES_DEFAULT: ParcelSizeClassConfig[] = [
  { code: 'S', label: 'Nhỏ (≤5 kg, 30×30×30 cm)', maxWeightKg: 5, maxDimsCm: [30, 30, 30], surchargeVnd: 0, vehicleClassCodes: ['MOTORBIKE', 'CAR_4', 'CAR_7'], enabled: true },
  { code: 'M', label: 'Vừa (≤30 kg, 50×40×50 cm)', maxWeightKg: 30, maxDimsCm: [50, 40, 50], surchargeVnd: 0, vehicleClassCodes: ['MOTORBIKE', 'CAR_4', 'CAR_7'], enabled: true },
  { code: 'L', label: 'Lớn (≤50 kg, 60×70×60 cm)', maxWeightKg: 50, maxDimsCm: [60, 70, 60], surchargeVnd: 10_000, vehicleClassCodes: ['MOTORBIKE', 'CAR_4', 'CAR_7'], enabled: true },
  { code: 'XL', label: 'Cồng kềnh (ô tô, ≤100 kg)', maxWeightKg: 100, maxDimsCm: [100, 80, 80], surchargeVnd: 30_000, vehicleClassCodes: ['CAR_4', 'CAR_7'], enabled: true },
];

const CODE_RE = /^[A-Z0-9_]{1,32}$/;

/** Throws an Error with a readable message when the admin value is malformed. */
export function normalizeParcelSizeClasses(raw: unknown): ParcelSizeClassConfig[] {
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new Error('PARCEL_SIZE_CLASSES must be a non-empty JSON array');
  }
  const seen = new Set<string>();
  return raw.map((entry, index) => {
    const row = entry as Record<string, unknown>;
    const code = row?.code;
    if (typeof code !== 'string' || !(PARCEL_SIZE_CODES as readonly string[]).includes(code)) {
      throw new Error(`PARCEL_SIZE_CLASSES[${index}].code must be one of ${PARCEL_SIZE_CODES.join(', ')}`);
    }
    if (seen.has(code)) throw new Error(`PARCEL_SIZE_CLASSES has duplicate code ${code}`);
    seen.add(code);
    const label = typeof row.label === 'string' && row.label.trim() ? row.label.trim().slice(0, 80) : code;
    const maxWeightKg = Number(row.maxWeightKg);
    if (!Number.isFinite(maxWeightKg) || maxWeightKg <= 0 || maxWeightKg > 2000) {
      throw new Error(`PARCEL_SIZE_CLASSES[${index}].maxWeightKg must be in (0, 2000]`);
    }
    const dims = row.maxDimsCm;
    if (!Array.isArray(dims) || dims.length !== 3 || !dims.every((d) => Number.isFinite(Number(d)) && Number(d) > 0)) {
      throw new Error(`PARCEL_SIZE_CLASSES[${index}].maxDimsCm must be [L, W, H] in cm`);
    }
    const surchargeVnd = Number(row.surchargeVnd ?? 0);
    if (!Number.isInteger(surchargeVnd) || surchargeVnd < 0 || surchargeVnd > 1_000_000 || surchargeVnd % 1000 !== 0) {
      throw new Error(`PARCEL_SIZE_CLASSES[${index}].surchargeVnd must be whole thousands in [0, 1000000]`);
    }
    const classes = row.vehicleClassCodes;
    if (!Array.isArray(classes) || classes.length === 0 || !classes.every((c) => typeof c === 'string' && CODE_RE.test(c))) {
      throw new Error(`PARCEL_SIZE_CLASSES[${index}].vehicleClassCodes must be a non-empty array of class codes`);
    }
    return {
      code: code as ParcelSizeCode,
      label,
      maxWeightKg,
      maxDimsCm: dims.map(Number) as [number, number, number],
      surchargeVnd,
      vehicleClassCodes: [...new Set(classes as string[])],
      enabled: row.enabled !== false,
    };
  });
}
