import { parseAccountDeletion } from "@/lib/account-deletion";
import { personInitials, type StatusTone } from "@/lib/admin-format";
import { areaLabelFromRegionOrCoords } from "@/lib/service-region-labels";
import type { NestOpsDriver } from "@/features/drivers/nest-types";
import type {
  DriverActivityStatus,
  DriverKycStatus,
  DriverListItem,
} from "@/features/drivers/types";

const kycLabels: Record<DriverKycStatus, string> = {
  VERIFIED: "Đã xác thực",
  NEEDS_MORE_INFO: "Chờ bổ sung",
  UNDER_REVIEW: "Đang xét duyệt",
  NEEDS_REVERIFY: "Cần xác minh lại",
};
const kycTones: Record<DriverKycStatus, StatusTone> = {
  VERIFIED: "success",
  NEEDS_MORE_INFO: "food",
  UNDER_REVIEW: "delivery",
  NEEDS_REVERIFY: "danger",
};

const activityLabels: Record<DriverActivityStatus, string> = {
  ON_TRIP: "Đang chạy",
  DELIVERING: "Đang giao",
  ONLINE: "Online",
  PAUSED: "Tạm ngưng",
  OFFLINE: "Offline",
  SUSPENDED: "Tạm khóa",
};
const activityTones: Record<
  Exclude<DriverActivityStatus, "OFFLINE">,
  StatusTone
> = {
  ON_TRIP: "success",
  DELIVERING: "success",
  ONLINE: "success",
  PAUSED: "food",
  SUSPENDED: "danger",
};

export function driverKycStatusLabel(status: DriverKycStatus) {
  return kycLabels[status];
}
export function driverKycStatusTone(status: DriverKycStatus) {
  return kycTones[status];
}
export function driverActivityStatusLabel(status: DriverActivityStatus) {
  return activityLabels[status];
}
export function driverActivityStatusTone(
  status: Exclude<DriverActivityStatus, "OFFLINE">,
) {
  return activityTones[status];
}

export function mapNestDriverToListItem(driver: NestOpsDriver): DriverListItem {
  const name = driver.displayName.trim() || "Tài xế";
  const grant = driver.grants.find((row) => row.role === "DRIVER");
  return {
    code: driver.id,
    initials: personInitials(name) || "TX",
    name,
    area: areaLabelFromRegionOrCoords({
      serviceRegionCode: driver.presence?.serviceRegionCode,
      lat: driver.presence?.lat,
      lng: driver.presence?.lng,
    }),
    service: driverServiceLabel(driver.presence),
    vehicle: driver.profile?.vehicleType?.trim() || "—",
    vehicleKind: vehicleKindLabel(driver.profile?.vehicleType),
    plate: driver.profile?.vehiclePlate?.trim() || "—",
    kyc: kycFromGrant(grant?.status),
    activity: activityFromPresence(driver, grant?.status),
    rating:
      driver.profile && driver.profile.ratingCount > 0
        ? driver.profile.ratingAverage
        : null,
    trips: countOrNull(driver.profile?.completedJobs),
    finishedJobs: countOrNull(driver.profile?.finishedJobs),
    completionRate:
      typeof driver.profile?.completionRate === "number" &&
      Number.isFinite(driver.profile.completionRate)
        ? driver.profile.completionRate
        : null,
    deletion: parseAccountDeletion(driver.deletion),
  };
}

function countOrNull(value: number | null | undefined): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : null;
}

/** "92%" style label; "—" when unknown. */
export function completionRateLabel(rate: number | null): string {
  if (rate == null) return "—";
  return `${Math.round(rate * 100)}%`;
}

/** Services from the driver's presence toggles; "—" when never reported. */
export function driverServiceLabel(
  presence: NestOpsDriver["presence"],
): string {
  if (!presence) return "—";
  const services = [
    presence.rideEnabled ? "Xe" : null,
    presence.foodEnabled ? "Đồ ăn" : null,
  ].filter(Boolean);
  return services.length > 0 ? services.join(" · ") : "—";
}

function vehicleKindLabel(type: string | null | undefined): string {
  const value = type?.trim().toLowerCase();
  if (!value) return "—";
  if (/(car|ô tô|oto|4 chỗ|7 chỗ)/.test(value)) return "Ô tô";
  if (/(bike|motor|xe máy|xe may|moto)/.test(value)) return "Xe máy";
  return type!.trim();
}

function kycFromGrant(
  status: NestOpsDriver["grants"][number]["status"] | undefined,
): DriverKycStatus {
  if (status === "ACTIVE") {
    return "VERIFIED";
  }
  if (status === "SUSPENDED") {
    return "NEEDS_REVERIFY";
  }
  return "UNDER_REVIEW";
}

function activityFromPresence(
  driver: NestOpsDriver,
  grantStatus: NestOpsDriver["grants"][number]["status"] | undefined,
): DriverActivityStatus {
  if (grantStatus === "SUSPENDED") {
    return "SUSPENDED";
  }
  if (driver.presence?.online) {
    return "ONLINE";
  }
  return "OFFLINE";
}
