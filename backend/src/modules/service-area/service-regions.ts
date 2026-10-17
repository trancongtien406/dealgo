/**
 * Vietnam service-region catalog for Admin ops filters (Ride + Food MVP).
 * Codes are stable filter keys; bbox is used for backfill and geo fallback.
 *
 * Source of truth is the `service_regions` table (Admin-managed). `SERVICE_REGIONS`
 * below is only the bootstrap/default set (migration seed, in-memory mode, tests).
 * At runtime the registry is swapped via `setServiceRegionCatalog` so the many
 * synchronous call sites (ride/food repositories) keep working without DI.
 */

export type ServiceRegionStatus = 'ACTIVE' | 'PLANNED';

export type ServiceRegionBBox = {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
};

export type ServiceRegion = {
  code: string;
  label: string;
  centerLat: number;
  centerLng: number;
  bbox: ServiceRegionBBox;
  status: ServiceRegionStatus;
};

/** Bootstrap defaults (mirrors the migration seed). Pilot + major cities. */
export const SERVICE_REGIONS: readonly ServiceRegion[] = [
  {
    code: 'DN',
    label: 'Đà Nẵng',
    centerLat: 16.0544,
    centerLng: 108.2022,
    bbox: { minLat: 15.95, maxLat: 16.22, minLng: 108.05, maxLng: 108.35 },
    status: 'ACTIVE',
  },
  {
    code: 'HCM',
    label: 'TP. Hồ Chí Minh',
    centerLat: 10.8231,
    centerLng: 106.6297,
    bbox: { minLat: 10.35, maxLat: 11.15, minLng: 106.35, maxLng: 107.05 },
    status: 'ACTIVE',
  },
  {
    code: 'HN',
    label: 'Hà Nội',
    centerLat: 21.0285,
    centerLng: 105.8542,
    bbox: { minLat: 20.85, maxLat: 21.25, minLng: 105.7, maxLng: 106.1 },
    status: 'ACTIVE',
  },
  {
    code: 'HP',
    label: 'Hải Phòng',
    centerLat: 20.8449,
    centerLng: 106.6881,
    bbox: { minLat: 20.7, maxLat: 21.05, minLng: 106.5, maxLng: 106.9 },
    status: 'ACTIVE',
  },
  {
    code: 'CT',
    label: 'Cần Thơ',
    centerLat: 10.0452,
    centerLng: 105.7469,
    bbox: { minLat: 9.95, maxLat: 10.2, minLng: 105.65, maxLng: 105.9 },
    status: 'PLANNED',
  },
  {
    code: 'HUE',
    label: 'Huế',
    centerLat: 16.4637,
    centerLng: 107.5909,
    bbox: { minLat: 16.35, maxLat: 16.55, minLng: 107.45, maxLng: 107.7 },
    status: 'PLANNED',
  },
  {
    code: 'NT',
    label: 'Nha Trang',
    centerLat: 12.2388,
    centerLng: 109.1967,
    bbox: { minLat: 12.15, maxLat: 12.35, minLng: 109.1, maxLng: 109.3 },
    status: 'PLANNED',
  },
  {
    code: 'VT',
    label: 'Vũng Tàu',
    centerLat: 10.346,
    centerLng: 107.0843,
    bbox: { minLat: 10.25, maxLat: 10.45, minLng: 107.0, maxLng: 107.2 },
    status: 'PLANNED',
  },
  {
    code: 'DAD',
    label: 'Đà Lạt',
    centerLat: 11.9404,
    centerLng: 108.4583,
    bbox: { minLat: 11.85, maxLat: 12.05, minLng: 108.35, maxLng: 108.55 },
    status: 'PLANNED',
  },
  {
    code: 'QNI',
    label: 'Quy Nhơn',
    centerLat: 13.782,
    centerLng: 109.2197,
    bbox: { minLat: 13.7, maxLat: 13.9, minLng: 109.1, maxLng: 109.3 },
    status: 'PLANNED',
  },
  {
    code: 'BD',
    label: 'Bình Dương',
    centerLat: 11.004,
    centerLng: 106.659,
    bbox: { minLat: 10.85, maxLat: 11.25, minLng: 106.55, maxLng: 106.85 },
    status: 'PLANNED',
  },
  {
    code: 'DNA',
    label: 'Đồng Nai',
    centerLat: 10.9574,
    centerLng: 106.8426,
    bbox: { minLat: 10.8, maxLat: 11.15, minLng: 106.7, maxLng: 107.1 },
    status: 'PLANNED',
  },
] as const;

let catalog: readonly ServiceRegion[] = SERVICE_REGIONS;
let byCode = indexByCode(catalog);

function indexByCode(regions: readonly ServiceRegion[]): Map<string, ServiceRegion> {
  return new Map(regions.map((r) => [r.code, r]));
}

/** Swap the runtime catalog (called after loading `service_regions` from DB). */
export function setServiceRegionCatalog(regions: readonly ServiceRegion[]): void {
  catalog = regions;
  byCode = indexByCode(regions);
}

/** Restore bootstrap defaults (tests / in-memory mode reset). */
export function resetServiceRegionCatalog(): void {
  setServiceRegionCatalog(SERVICE_REGIONS);
}

export function listServiceRegions(): readonly ServiceRegion[] {
  return catalog;
}

/** Default for ambiguous pilot seed rows that cannot be classified. */
export const DEFAULT_SERVICE_REGION_CODE = 'DN';

export function activeServiceRegions(): ServiceRegion[] {
  return catalog.filter((r) => r.status === 'ACTIVE');
}

/** Display label derived from ACTIVE zones (replaces the old free-text pilot label). */
export function activeServiceRegionsLabel(): string {
  return activeServiceRegions()
    .map((r) => r.label)
    .join(' & ');
}

export function getServiceRegion(code: string | null | undefined): ServiceRegion | undefined {
  if (!code) {
    return undefined;
  }
  return byCode.get(code.trim().toUpperCase());
}

export function isKnownServiceRegionCode(code: string): boolean {
  return byCode.has(code.trim().toUpperCase());
}

export function normalizeRegionFilter(
  regionOrZone: string | null | undefined,
): string | undefined {
  if (!regionOrZone || regionOrZone === 'ALL') {
    return undefined;
  }
  const raw = regionOrZone.trim().toUpperCase();
  if (byCode.has(raw)) {
    return raw;
  }
  const fromLabel = inferRegionCodeFromLabel(regionOrZone);
  return fromLabel ?? undefined;
}

export function pointInBBox(
  lat: number,
  lng: number,
  bbox: ServiceRegionBBox,
): boolean {
  return (
    lat >= bbox.minLat &&
    lat <= bbox.maxLat &&
    lng >= bbox.minLng &&
    lng <= bbox.maxLng
  );
}

export function inferRegionCodeFromCoords(
  lat: number | null | undefined,
  lng: number | null | undefined,
): string | null {
  if (lat == null || lng == null || !Number.isFinite(lat) || !Number.isFinite(lng)) {
    return null;
  }
  for (const region of catalog) {
    if (pointInBBox(lat, lng, region.bbox)) {
      return region.code;
    }
  }
  return null;
}

/**
 * Label heuristics for backfill when coords are missing or outside bbox.
 * Prefer longer / more specific needles first.
 */
export function inferRegionCodeFromLabel(
  label: string | null | undefined,
): string | null {
  if (!label?.trim()) {
    return null;
  }
  const n = normalizeVi(label);
  if (
    n.includes('ho chi minh') ||
    n.includes('tp hcm') ||
    n.includes('tphcm') ||
    /\bhcm\b/.test(n) ||
    n.includes('sai gon') ||
    n.includes('quan 1') ||
    n.includes('ben thanh') ||
    n.includes('thu duc') ||
    n.includes('binh thanh')
  ) {
    return 'HCM';
  }
  if (
    n.includes('ha noi') ||
    n.includes('hanoi') ||
    /\bhn\b/.test(n) ||
    n.includes('cau giay') ||
    n.includes('hoan kiem') ||
    n.includes('ba dinh')
  ) {
    return 'HN';
  }
  if (
    n.includes('hai phong') ||
    /\bhp\b/.test(n) ||
    n.includes('le chan') ||
    n.includes('ngo quyen')
  ) {
    return 'HP';
  }
  if (
    n.includes('da nang') ||
    n.includes('danang') ||
    /\bdn\b/.test(n) ||
    n.includes('hai chau') ||
    n.includes('son tra') ||
    n.includes('thanh khe') ||
    n.includes('ngu hanh son') ||
    n.includes('cam le') ||
    n.includes('lien chieu') ||
    n.includes('my khe') ||
    n.includes('hoi an')
  ) {
    return 'DN';
  }
  if (n.includes('can tho')) {
    return 'CT';
  }
  if (n.includes('hue') || n.includes('thua thien')) {
    return 'HUE';
  }
  if (n.includes('nha trang') || n.includes('khanh hoa')) {
    return 'NT';
  }
  // Admin-created / non-builtin zones: match the zone's own label (e.g. "Cần Thơ").
  for (const region of catalog) {
    const needle = labelNeedle(region.label);
    if (needle.length >= 3 && n.includes(needle)) {
      return region.code;
    }
  }
  return null;
}

export function resolveServiceRegionCode(input: {
  lat?: number | null;
  lng?: number | null;
  label?: string | null;
  fallback?: string | null;
}): string {
  return (
    inferRegionCodeFromCoords(input.lat, input.lng) ??
    inferRegionCodeFromLabel(input.label) ??
    input.fallback ??
    DEFAULT_SERVICE_REGION_CODE
  );
}

/**
 * Prisma where fragment: prefer equality on serviceRegionCode;
 * fall back to label contains only when code is still null.
 */
export function regionCodeOrLabelFallbackWhere(
  code: string,
  labelFields: string[],
): Record<string, unknown> {
  const region = byCode.get(code);
  const needles = region
    ? [region.label, code]
    : [code];
  const labelOr = labelFields.flatMap((field) =>
    needles.map((needle) => ({
      [field]: { contains: needle, mode: 'insensitive' as const },
    })),
  );
  return {
    OR: [
      { serviceRegionCode: code },
      {
        AND: [{ serviceRegionCode: null }, { OR: labelOr }],
      },
    ],
  };
}

function labelNeedle(label: string): string {
  return normalizeVi(label)
    .replace(/^(tp\.?|thanh pho)\s+/, '')
    .trim();
}

function normalizeVi(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/\s+/g, ' ')
    .trim();
}
