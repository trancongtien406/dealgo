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
  const vehicleName =
    driver.kycDetail?.vehicleBrand && driver.kycDetail?.vehicleModel
      ? `${driver.kycDetail.vehicleBrand} ${driver.kycDetail.vehicleModel}`
      : driver.kycDetail?.vehicleType || driver.profile?.vehicleType?.trim() || "—";
  const plate =
    driver.kycDetail?.vehiclePlate?.trim() ||
    driver.profile?.vehiclePlate?.trim() ||
    "—";

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
    vehicle: vehicleName,
    vehicleKind: vehicleKindLabel(driver.kycDetail?.vehicleType || driver.profile?.vehicleType),
    vehicleBrand: driver.kycDetail?.vehicleBrand || undefined,
    vehicleModel: driver.kycDetail?.vehicleModel || undefined,
    plate,
    licenseClass: driver.kycDetail?.licenseClass || undefined,
    licenseNumber: driver.kycDetail?.licenseNumber || undefined,
    kyc: kycFromGrant(grant?.status),
    activity: activityFromPresence(driver, grant?.status),
    rating:
      driver.stats?.ratingAverage ??
      (driver.profile && driver.profile.ratingCount > 0
        ? driver.profile.ratingAverage
        : null),
    trips:
      driver.stats != null
        ? driver.stats.completedRides + driver.stats.completedFoodOrders
        : countOrNull(driver.profile?.completedJobs),
    finishedJobs:
      driver.stats != null
        ? driver.stats.finishedJobs
        : countOrNull(driver.profile?.finishedJobs),
    completionRate:
      driver.stats?.completionRate ??
      (typeof driver.profile?.completionRate === "number" &&
      Number.isFinite(driver.profile.completionRate)
        ? driver.profile.completionRate
        : null),
    phone: driver.profile?.phoneMasked || driver.phone || "—",
    phoneMasked: driver.profile?.phoneMasked || undefined,
    email: driver.email || undefined,
    createdAt: driver.createdAt,
    deletion: parseAccountDeletion(driver.deletion),
    presence: driver.presence,
    kycDetail: driver.kycDetail,
    activeJob: driver.activeJob,
    performance7d: driver.performance7d,
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
