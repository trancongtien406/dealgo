import type { OpsIconName } from "@/components/ui/ops-icons";
import type {
  CategoryKey,
  PlatformSettingRow,
} from "@/features/platform-settings/types";

const LABELS: Record<string, { label: string; hint: string }> = {
  PAYMENT_METHODS_ENABLED: {
    label: "Kênh thanh toán bật (JSON)",
    hint: 'OPEN-002 — ví dụ ["COD","SANDBOX"]; không chứa secret PSP',
  },
  RIDE_MIN_FARE_VND: {
    label: "Giá Ride tối thiểu (VND)",
    hint: "OPEN-003/019 — TEST_ONLY bound",
  },
  RIDE_MAX_FARE_VND: {
    label: "Giá Ride tối đa (VND)",
    hint: "OPEN-003/019 — TEST_ONLY bound",
  },
  RIDE_REFERENCE_VND_PER_KM: {
    label: "Giá tham chiếu Ride / km (VND)",
    hint: "OPEN-003/019 — không phải phí chính thức",
  },
  FOOD_MIN_DELIVERY_VND: {
    label: "Phí giao Food tối thiểu (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  FOOD_MAX_DELIVERY_VND: {
    label: "Phí giao Food tối đa (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  DRIVER_SEARCH_RADIUS_KM: {
    label: "Bán kính tìm tài xế (km)",
    hint: "OPEN-004 — TEST_ONLY dispatch",
  },
  RIDE_OFFER_TTL_SECONDS: {
    label: "TTL đề nghị giá Ride (giây)",
    hint: "OPEN-004/019",
  },
  RIDE_NEGOTIATION_MAX_ROUNDS: {
    label: "Số vòng thương lượng tối đa",
    hint: "OPEN-019 — để trống nếu không giới hạn",
  },
  MAX_CONCURRENT_JOBS_PER_DRIVER: {
    label: "Job đồng thời / tài xế",
    hint: "OPEN-005 — lưu cấu hình; enforce dần",
  },
  CONTACT_WINDOW_MINUTES: {
    label: "Cửa sổ chat/voice (phút)",
    hint: "OPEN-014/021 — heuristic TEST_ONLY, chưa retention policy",
  },
};

export function categorizeSetting(key: string): CategoryKey {
  if (
    key.startsWith("RIDE_MIN") ||
    key.startsWith("RIDE_MAX") ||
    key.startsWith("RIDE_REF") ||
    key.startsWith("FOOD_MIN") ||
    key.startsWith("FOOD_MAX")
  ) {
    return "FARE";
  }
  if (
    key.includes("RADIUS") ||
    key.includes("TTL") ||
    key.includes("ROUNDS") ||
    key.includes("JOBS") ||
    key.includes("WINDOW")
  ) {
    return "DISPATCH";
  }
  return "ZONE_PAYMENT";
}

export function getSettingIcon(category: CategoryKey): OpsIconName {
  switch (category) {
    case "FARE":
      return "receipt";
    case "DISPATCH":
      return "car";
    case "ZONE_PAYMENT":
      return "pin";
    default:
      return "settings";
  }
}

export function enrichPlatformSetting(row: {
  key: string;
  value: string;
  valueType: PlatformSettingRow["valueType"];
  source: "db" | "env";
  openIds: string[];
  updatedAt: string | null;
  updatedByUserId: string | null;
}): PlatformSettingRow {
  const meta = LABELS[row.key] ?? {
    label: row.key,
    hint: row.openIds.join(", ") || "Platform setting",
  };
  return { ...row, ...meta };
}
