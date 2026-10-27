/**
 * Region codes, labels and boxes all come from the zones managed at /zones
 * (`/api/ops/zones` → `registerServiceRegions`); nothing is hardcoded here.
 */
export type ServiceRegionCode = string;

export const DEFAULT_CENTER: [number, number] = [16.0544, 108.2022];

/**
 * Dynamic registry of service region labels, populated exclusively from
 * backend API (`/api/ops/zones`).
 */
export const SERVICE_REGION_LABELS: Record<string, string> = {};

/** Dynamic bounding boxes populated from backend service zones. */
export const REGION_BBOX: Record<
  string,
  { minLat: number; maxLat: number; minLng: number; maxLng: number }
> = {};

export function registerServiceRegions(
  regions: Array<{
    code: string;
    label: string;
    bbox?: { minLat: number; maxLat: number; minLng: number; maxLng: number };
  }>,
) {
  for (const r of regions) {
    if (!r.code) continue;
    const key = r.code.trim().toUpperCase();
    (SERVICE_REGION_LABELS as Record<string, string>)[key] = r.label;
    if (r.bbox) {
      (
        REGION_BBOX as Record<
          string,
          { minLat: number; maxLat: number; minLng: number; maxLng: number }
        >
      )[key] = r.bbox;
    }
  }
}

export function serviceRegionLabel(
  code: string | null | undefined,
): string | null {
  if (!code) return null;
  const key = code.trim().toUpperCase();
  if (key in SERVICE_REGION_LABELS) {
    return SERVICE_REGION_LABELS[key];
  }
  return code;
}

export function resolveServiceRegionCodeFromCoords(
  lat: number | null | undefined,
  lng: number | null | undefined,
): ServiceRegionCode | null {
  if (lat == null || lng == null) return null;
  for (const [code, box] of Object.entries(REGION_BBOX)) {
    if (
      box &&
      lat >= box.minLat &&
      lat <= box.maxLat &&
      lng >= box.minLng &&
      lng <= box.maxLng
    ) {
      return code;
    }
  }
  return null;
}

export function areaLabelFromRegionOrCoords(input: {
  serviceRegionCode?: string | null;
  lat?: number | null;
  lng?: number | null;
}): string {
  const fromCode = serviceRegionLabel(input.serviceRegionCode);
  if (fromCode) return fromCode;
  const resolved = resolveServiceRegionCodeFromCoords(input.lat, input.lng);
  if (resolved) return SERVICE_REGION_LABELS[resolved];
  if (input.lat != null && input.lng != null) {
    return `${input.lat.toFixed(3)}, ${input.lng.toFixed(3)}`;
  }
  return "—";
}
