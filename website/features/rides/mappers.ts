import type { StatusTone } from "@/lib/admin-format";
import type { NestRideStatus, NestRideView } from "@/features/rides/nest-types";
import type { RideListItem, RideStatus } from "@/features/rides/types";
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
  return {
    code: ride.id,
    customer: "Khách hàng",
    phone: "—",
    driver: driverId ? actorLabel("TX", driverId) : "—",
    plate: "—",
    pickup: pickupLabel,
    pickupArea: areaHint(pickupLabel),
    dropoff: dropoffLabel,
    dropoffArea: areaHint(dropoffLabel),
    seats: ride.status === "NEGOTIATING" ? "Đang thương lượng" : "—",
    price: ride.agreedFareVnd ?? ride.offeredFareVnd,
    status: nestRideStatusToFeature(ride.status),
    time: formatOpsClock(ride.expiresAt),
  };
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
