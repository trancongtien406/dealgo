import { cancelActorLabel } from "@/lib/cancel-actor";
import type { StatusTone } from "@/lib/admin-format";
import type { NestRideStatus, NestRideView } from "@/features/rides/nest-types";
import type { GeoPoint, RideListItem, RideStatus } from "@/features/rides/types";
import type { OpsPerson } from "@/lib/api/ops-people";
import { formatOpsClock } from "@/lib/ops-time";

const nestRideStatusMap: Record<NestRideStatus, RideStatus> = {
  NEGOTIATING: "WAITING",
  ASSIGNED: "WAITING",
  DRIVER_EN_ROUTE: "PICKING_UP",
  DRIVER_ARRIVED: "PICKING_UP",
  IN_TRIP: "IN_TRIP",
  COMPLETED: "COMPLETED",
  CANCELLED: "CANCELLED",
  EXPIRED: "CANCELLED",
};

export function nestRideStatusToFeature(status: NestRideStatus): RideStatus {
  return nestRideStatusMap[status];
}

export function mapNestRideToListItem(ride: NestRideView): RideListItem {
  const pickupLabel = ride.pickup.label.trim() || "—";
  const dropoffLabel = ride.dropoff.label.trim() || "—";
  const driverId = ride.assignedDriverId ?? selectedOfferDriverId(ride) ?? null;
  const driverProfile =
    ride.driverProfile ??
    ride.offers?.find((offer) => offer.driverId === driverId)?.driverProfile ??
    null;
  return {
    code: ride.id,
    customer: personLabel(ride.customerProfile, "KH", ride.customerId),
    phone: ride.customerProfile?.phoneMasked ?? "—",
    driver: driverId ? personLabel(driverProfile, "TX", driverId) : "—",
    plate: (driverId && driverProfile?.vehiclePlate) || "—",
    pickup: pickupLabel,
    pickupArea: areaHint(pickupLabel),
    dropoff: dropoffLabel,
    dropoffArea: areaHint(dropoffLabel),
    seats: ride.status === "NEGOTIATING" ? "Đang thương lượng" : "—",
    price: ride.agreedFareVnd ?? ride.offeredFareVnd,
    discountVnd: ride.discountVnd ?? 0,
    voucherCode: ride.voucherCode ?? null,
    cashDueVnd:
      ride.cashDueVnd ??
      Math.max(0, (ride.agreedFareVnd ?? ride.offeredFareVnd) - (ride.discountVnd ?? 0)),
    status: nestRideStatusToFeature(ride.status),
    cancelledBy: cancelActorLabel(ride.cancelledBy),
    time: formatOpsClock(ride.expiresAt),
    pickupPoint: geoPoint(ride.pickup),
    dropoffPoint: geoPoint(ride.dropoff),
  };
}

/** Real name, else masked phone, else a short id tag; "—" when nothing is known. */
export function personLabel(
  person: OpsPerson | null | undefined,
  prefix: string,
  id: string | null | undefined,
): string {
  const name = person?.displayName?.trim();
  if (name) return name;
  if (person?.phoneMasked) return person.phoneMasked;
  return id ? actorLabel(prefix, id) : "—";
}

export function geoPoint(
  point: { lat?: unknown; lng?: unknown } | null | undefined,
): GeoPoint | null {
  if (!point) return null;
  const { lat, lng } = point;
  if (typeof lat !== "number" || typeof lng !== "number") return null;
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
}

function selectedOfferDriverId(ride: NestRideView): string | null {
  if (!ride.selectedOfferId || !ride.offers?.length) {
    return null;
  }
  const offer = ride.offers.find((row) => row.id === ride.selectedOfferId);
  return offer?.driverId ?? null;
}

function actorLabel(prefix: string, id: string): string {
  return `${prefix} · ${shortId(id)}`;
}

function areaHint(label: string): string {
  const parts = label
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
  if (parts.length >= 2) {
    return parts[parts.length - 1] ?? "—";
  }
  return "—";
}

function shortId(id: string): string {
  return id.slice(0, 8);
}

const rideStatusLabels: Record<RideStatus, string> = {
  WAITING: "Đang chờ",
  PICKING_UP: "Đang đón khách",
  IN_TRIP: "Đang di chuyển",
  COMPLETED: "Hoàn thành",
  CANCELLED: "Đã hủy",
};

const rideStatusTones: Record<RideStatus, StatusTone> = {
  WAITING: "brand",
  PICKING_UP: "food",
  IN_TRIP: "delivery",
  COMPLETED: "success",
  CANCELLED: "danger",
};

export function rideStatusLabel(status: RideStatus): string {
  return rideStatusLabels[status];
}

export function rideStatusTone(status: RideStatus): StatusTone {
  return rideStatusTones[status];
}

export const rideStatusFilterOptions = [
  { value: "ALL" as const, label: "Tất cả trạng thái" },
  { value: "WAITING" as const, label: rideStatusLabels.WAITING },
  { value: "PICKING_UP" as const, label: rideStatusLabels.PICKING_UP },
  { value: "IN_TRIP" as const, label: rideStatusLabels.IN_TRIP },
  { value: "COMPLETED" as const, label: rideStatusLabels.COMPLETED },
  { value: "CANCELLED" as const, label: rideStatusLabels.CANCELLED },
];
