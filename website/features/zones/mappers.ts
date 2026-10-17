import { vnd, type StatusTone } from "@/lib/admin-format";
import { formatOpsDateTime } from "@/lib/ops-time";
import { CITY_COORDS, DEFAULT_CENTER } from "@/features/zones/constants";
import type {
  PriceStatus,
  ZoneItem,
  ZoneService,
} from "@/features/zones/types";

const priceLabels: Record<PriceStatus, string> = {
  ACTIVE: "Đang áp dụng",
  DRAFT: "Bản nháp",
};

const serviceLabels: Record<string, string> = {
  RIDE: "Chuyến xe",
  FOOD: "Đồ ăn",
  PLATFORM: "Toàn sàn",
};

const serviceTones: Record<string, StatusTone> = {
  RIDE: "brand",
  FOOD: "food",
  PLATFORM: "delivery",
};

export function priceStatusLabel(status: PriceStatus) {
  return priceLabels[status] ?? status;
}

export function zoneServiceLabel(service: ZoneService | string) {
  return serviceLabels[service] ?? service;
}

export function zoneServiceTone(service: ZoneService | string): StatusTone {
  return serviceTones[service] ?? "brand";
}

export function formatZoneRuleValue(value: string, unit: string): string {
  const trimmed = value.trim();
  if (!trimmed) return "—";
  if (unit === "VND" || unit.startsWith("VND")) {
    const n = Number(trimmed);
    if (Number.isFinite(n)) {
      return unit === "VND"
        ? vnd(n)
        : `${vnd(n)} ${unit.replace("VND", "").trim()}`;
    }
  }
  if (unit === "km") {
    return `${trimmed} km`;
  }
  return unit ? `${trimmed} ${unit}` : trimmed;
}

export function resolveCityCenter(
  zone: ZoneItem | undefined,
): [number, number] {
  if (!zone) return DEFAULT_CENTER;
  if (
    typeof zone.centerLat === "number" &&
    typeof zone.centerLng === "number" &&
    Number.isFinite(zone.centerLat) &&
    Number.isFinite(zone.centerLng)
  ) {
    return [zone.centerLat, zone.centerLng];
  }
  return CITY_COORDS[zone.code] ?? DEFAULT_CENTER;
}

export const formatUpdatedAt = formatOpsDateTime;
