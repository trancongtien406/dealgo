import type {
  MapsCapability,
  MapsProviderChoice,
  MapsProvidersView,
  NestMapsProviders,
} from "@/features/maps-providers/types";
import { formatOpsDateTime } from "@/lib/ops-time";

const capabilityLabels: Record<MapsCapability, string> = {
  search: "Tìm địa chỉ",
  reverse: "Địa chỉ từ vị trí",
  route: "Lộ trình & quãng đường",
};

const capabilityHints: Record<MapsCapability, string> = {
  search:
    "Ô tìm điểm đón/điểm đến trong app. Google: Autocomplete + Place Details cho tối đa 5 gợi ý mỗi lần gõ (đã cache).",
  reverse:
    "Đổi toạ độ ghim trên bản đồ thành địa chỉ. Google: Geocoding API.",
  route:
    "Đường vẽ trên bản đồ và quãng đường tính cước. Google: Routes API (không tính kẹt xe).",
};

export const PROVIDER_LABELS: Record<MapsProviderChoice, string> = {
  mapbox: "Mapbox",
  google: "Google Maps",
};

export function mapsCapabilityLabel(capability: MapsCapability): string {
  return capabilityLabels[capability];
}

export function mapMapsProviders(raw: NestMapsProviders): MapsProvidersView {
  return {
    googleConfigured: raw.googleConfigured,
    primary: raw.primary,
    rows: raw.capabilities.map((row) => ({
      ...row,
      label: capabilityLabels[row.capability],
      hint: capabilityHints[row.capability],
      updatedAtLabel: row.updatedAt ? formatOpsDateTime(row.updatedAt) : "mặc định",
      degraded: row.chosen !== row.effective,
    })),
  };
}

/** Google can only be picked when a Google key is set (Admin or env). */
export function canChooseProvider(
  view: Pick<MapsProvidersView, "googleConfigured">,
  value: MapsProviderChoice,
): boolean {
  return value === "mapbox" || view.googleConfigured;
}
