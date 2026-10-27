/**
 * Admin › Khu vực form helpers: province presets, auto code, bbox checks.
 * The backend (service-regions.service.ts) stays authoritative; these only
 * pre-fill and warn so ops rarely type coordinates by hand.
 */
import type { GeoBox } from "@/components/ui/map-box-edit";
import type { ZoneBBox, ZoneItem } from "@/features/zones/types";

export type ProvincePreset = {
  name: string;
  /** Preferred zone code; suggestZoneCode falls back if it is taken. */
  code: string;
  lat: number;
  lng: number;
};

/** 34 provincial-level units (from 2025-07-01), centre = administrative seat. */
export const VN_PROVINCES: readonly ProvincePreset[] = [
  { name: "Hà Nội", code: "HN", lat: 21.0285, lng: 105.8542 },
  { name: "Huế", code: "HUE", lat: 16.4637, lng: 107.5909 },
  { name: "Hải Phòng", code: "HP", lat: 20.8449, lng: 106.6881 },
  { name: "Đà Nẵng", code: "DN", lat: 16.0544, lng: 108.2022 },
  { name: "TP. Hồ Chí Minh", code: "HCM", lat: 10.8231, lng: 106.6297 },
  { name: "Cần Thơ", code: "CT", lat: 10.0452, lng: 105.7469 },
  { name: "Tuyên Quang", code: "TQ", lat: 21.8236, lng: 105.214 },
  { name: "Cao Bằng", code: "CB", lat: 22.6657, lng: 106.257 },
  { name: "Lai Châu", code: "LCH", lat: 22.3964, lng: 103.4582 },
  { name: "Lào Cai", code: "LCA", lat: 21.7229, lng: 104.9113 },
  { name: "Thái Nguyên", code: "TNG", lat: 21.5942, lng: 105.8482 },
  { name: "Điện Biên", code: "DB", lat: 21.386, lng: 103.023 },
  { name: "Lạng Sơn", code: "LS", lat: 21.8537, lng: 106.7615 },
  { name: "Sơn La", code: "SL", lat: 21.3256, lng: 103.9188 },
  { name: "Phú Thọ", code: "PT", lat: 21.3227, lng: 105.4019 },
  { name: "Bắc Ninh", code: "BN", lat: 21.2731, lng: 106.1946 },
  { name: "Quảng Ninh", code: "QNH", lat: 20.9517, lng: 107.08 },
  { name: "Hưng Yên", code: "HY", lat: 20.6464, lng: 106.0511 },
  { name: "Ninh Bình", code: "NB", lat: 20.2506, lng: 105.9745 },
  { name: "Thanh Hóa", code: "TH", lat: 19.8067, lng: 105.7852 },
  { name: "Nghệ An", code: "NA", lat: 18.6796, lng: 105.6813 },
  { name: "Hà Tĩnh", code: "HT", lat: 18.3428, lng: 105.9057 },
  { name: "Quảng Trị", code: "QT", lat: 17.4689, lng: 106.6223 },
  { name: "Quảng Ngãi", code: "QNG", lat: 15.1214, lng: 108.8044 },
  { name: "Gia Lai", code: "GL", lat: 13.782, lng: 109.2197 },
  { name: "Khánh Hòa", code: "KH", lat: 12.2388, lng: 109.1967 },
  { name: "Lâm Đồng", code: "LD", lat: 11.9404, lng: 108.4583 },
  { name: "Đắk Lắk", code: "DLK", lat: 12.6667, lng: 108.05 },
  { name: "Đồng Nai", code: "DNA", lat: 10.9574, lng: 106.8426 },
  { name: "Tây Ninh", code: "TNI", lat: 10.5359, lng: 106.4137 },
  { name: "Vĩnh Long", code: "VL", lat: 10.2537, lng: 105.9722 },
  { name: "Đồng Tháp", code: "DT", lat: 10.36, lng: 106.36 },
  { name: "Cà Mau", code: "CM", lat: 9.1769, lng: 105.1524 },
  { name: "An Giang", code: "AG", lat: 10.0124, lng: 105.0809 },
];

/** Same rule as the backend DTO (stored upper-case). */
export const ZONE_CODE_PATTERN = /^[A-Z][A-Z0-9]{1,7}$/;
/** service-regions.service.ts MAX_BBOX_SPAN_DEG */
export const MAX_ZONE_SPAN_DEG = 3;
/** Default half-size of a new city-level service box (~17 km each way). */
export const DEFAULT_ZONE_HALF_SPAN = 0.15;

export function foldVietnamese(input: string): string {
  return input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D");
}

/** Free text → candidate code characters (folded, A–Z0–9, ≤ 8). */
export function normalizeZoneCodeInput(input: string): string {
  return foldVietnamese(input)
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "")
    .slice(0, 8);
}

const PREFIX_WORDS = new Set(["TP", "TINH", "THANH", "PHO", "THI", "XA", "QUAN", "HUYEN"]);

function labelWords(label: string): string[] {
  const words = foldVietnamese(label)
    .toUpperCase()
    .split(/[^A-Z0-9]+/)
    .filter(Boolean);
  const core = words.filter((w) => !PREFIX_WORDS.has(w));
  return core.length > 0 ? core : words;
}

/**
 * Suggest a unique code from a label: preferred code → initials (HCM) →
 * initials + letters of the last word (QNGA) → first letters of a single
 * word (HUE) → numbered (HCM2). `taken` is compared case-insensitively.
 */
export function suggestZoneCode(
  label: string,
  taken: Iterable<string>,
  preferred?: string,
): string {
  const used = new Set([...taken].map((c) => c.toUpperCase()));
  const ok = (c: string) => ZONE_CODE_PATTERN.test(c) && !used.has(c);
  const candidates: string[] = [];
  if (preferred) candidates.push(normalizeZoneCodeInput(preferred));

  const words = labelWords(label);
  if (words.length === 0) return "";
  const initials = words.map((w) => w[0]).join("").slice(0, 8);
  const last = words[words.length - 1];
  if (words.length > 1) {
    candidates.push(initials);
    for (let n = 2; n <= last.length; n++) {
      candidates.push((initials.slice(0, -1) + last.slice(0, n)).slice(0, 8));
    }
  }
  const joined = words.join("");
  for (let n = 2; n <= Math.min(8, joined.length); n++) {
    candidates.push(joined.slice(0, n));
  }

  for (const c of candidates) if (ok(c)) return c;

  const base = (initials.length >= 2 ? initials : joined.slice(0, 3)).slice(0, 6);
  for (let i = 2; i < 100; i++) {
    const c = `${base}${i}`.slice(0, 8);
    if (ok(c)) return c;
  }
  return "";
}

export function zoneCodeProblem(code: string, taken: Iterable<string>): string | null {
  if (!code) return "Nhập mã khu vực.";
  if (!ZONE_CODE_PATTERN.test(code)) {
    return "Mã 2–8 ký tự, bắt đầu bằng chữ (A–Z, 0–9).";
  }
  for (const t of taken) {
    if (t.toUpperCase() === code) return `Mã ${code} đã có khu vực khác dùng.`;
  }
  return null;
}

const round4 = (n: number) => Math.round(n * 10_000) / 10_000;

export function defaultZoneBbox(
  lat: number,
  lng: number,
  half = DEFAULT_ZONE_HALF_SPAN,
): ZoneBBox {
  return {
    minLat: round4(lat - half),
    maxLat: round4(lat + half),
    minLng: round4(lng - half),
    maxLng: round4(lng + half),
  };
}

export function bboxCenter(b: GeoBox): [number, number] {
  return [round4((b.minLat + b.maxLat) / 2), round4((b.minLng + b.maxLng) / 2)];
}

/** Mirrors the backend checks so the form can explain before submit. */
export function zoneBboxProblem(
  center: { lat: number; lng: number },
  b: ZoneBBox,
): string | null {
  const nums = [center.lat, center.lng, b.minLat, b.maxLat, b.minLng, b.maxLng];
  if (!nums.every(Number.isFinite)) return "Toạ độ chưa hợp lệ.";
  if (b.minLat < -90 || b.maxLat > 90 || b.minLng < -180 || b.maxLng > 180) {
    return "Toạ độ nằm ngoài phạm vi hợp lệ.";
  }
  if (b.minLat >= b.maxLat || b.minLng >= b.maxLng) {
    return "Vùng phải có diện tích (kéo rộng khung trên bản đồ).";
  }
  if (b.maxLat - b.minLat > MAX_ZONE_SPAN_DEG || b.maxLng - b.minLng > MAX_ZONE_SPAN_DEG) {
    return `Vùng quá lớn (tối đa ${MAX_ZONE_SPAN_DEG}° mỗi chiều).`;
  }
  if (
    center.lat < b.minLat ||
    center.lat > b.maxLat ||
    center.lng < b.minLng ||
    center.lng > b.maxLng
  ) {
    return "Tâm phải nằm trong vùng.";
  }
  return null;
}

export function bboxesOverlap(a: ZoneBBox, b: ZoneBBox): boolean {
  return a.minLat < b.maxLat && b.minLat < a.maxLat && a.minLng < b.maxLng && b.minLng < a.maxLng;
}

/** Other zones whose box intersects `b` (warning only; overlap is allowed). */
export function overlappingZones(
  b: ZoneBBox,
  zones: readonly ZoneItem[],
  exceptCode?: string,
): ZoneItem[] {
  return zones.filter(
    (z) => z.code !== exceptCode && z.bbox != null && bboxesOverlap(b, z.bbox),
  );
}

/** Provinces matching a query, diacritics-insensitive. */
export function matchProvinces(query: string, limit = 8): ProvincePreset[] {
  const q = foldVietnamese(query).toLowerCase().trim();
  if (!q) return VN_PROVINCES.slice(0, limit);
  return VN_PROVINCES.filter((p) => foldVietnamese(p.name).toLowerCase().includes(q)).slice(
    0,
    limit,
  );
}

/** Centre + zoom that fit a box in a viewport (no city-level zoom floor). */
export function fitZoneBox(
  b: ZoneBBox,
  width: number,
  height: number,
  padding = 48,
): { center: [number, number]; zoom: number } {
  const lngSpan = Math.max(0.005, b.maxLng - b.minLng);
  const latSpan = Math.max(0.005, b.maxLat - b.minLat);
  const w = Math.max(120, width - padding * 2);
  const hgt = Math.max(120, height - padding * 2);
  const zLng = Math.log2((360 * w) / (lngSpan * 256));
  const zLat = Math.log2((180 * hgt) / (latSpan * 256));
  const zoom = Math.min(16, Math.max(5, Math.floor(Math.min(zLng, zLat) * 2) / 2));
  return { center: bboxCenter(b), zoom };
}
