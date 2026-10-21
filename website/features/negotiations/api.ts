import type { PaginatedList } from "@/lib/api/pagination";
import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";
import { formatOpsClock, formatOpsDate } from "@/lib/ops-time";

import type {
  NestRideOffer,
  NestRidePage,
  NestRideView,
} from "@/features/rides/nest-types";
import { geoPoint, personLabel } from "@/features/rides/mappers";
import type {
  NegotiationOffer,
  NegotiationSession,
  NegotiationSessionStatus,
} from "@/features/negotiations/types";

export type {
  NegotiationOffer,
  NegotiationSession,
} from "@/features/negotiations/types";

export type FetchNegotiationsParams = {
  page: number;
  limit: number;
  q?: string;
  status?: string | null;
  region?: string | null;
};

function mapRideStatus(status: string): NegotiationSessionStatus {
  if (status === "NEGOTIATING") return "OPEN";
  if (status === "CANCELLED" || status === "EXPIRED") return "EXPIRED";
  if (
    status === "ASSIGNED" ||
    status === "DRIVER_EN_ROUTE" ||
    status === "DRIVER_ARRIVED"
  ) {
    return "LOCKED";
  }
  return "ACCEPTED";
}

function mapOffer(offer: NestRideOffer): NegotiationOffer {
  return {
    id: offer.id,
    driverId: offer.driverId,
    amountVnd: offer.amountVnd,
    kind: offer.kind,
    status: offer.status,
    expiresAt: offer.expiresAt,
    driverLabel: personLabel(offer.driverProfile, "TX", offer.driverId),
    driverPlate: offer.driverProfile?.vehiclePlate ?? null,
  };
}

function lowestOfferAmount(offers: NestRideOffer[]): number | null {
  return offers.reduce<number | null>((min, offer) => {
    if (typeof offer.amountVnd !== "number") return min;
    return min === null || offer.amountVnd < min ? offer.amountVnd : min;
  }, null);
}

function mapNestRide(ride: NestRideView): NegotiationSession {
  const pickup = ride.pickup?.label?.trim() || "Điểm đón";
  const dropoff = ride.dropoff?.label?.trim() || "Điểm đến";
  const offers = (ride.offers ?? []).map(mapOffer);

  return {
    code: ride.id,
    customer: personLabel(ride.customerProfile, "KH", ride.customerId),
    customerPhone: ride.customerProfile?.phoneMasked ?? null,
    pickupPoint: geoPoint(ride.pickup),
    dropoffPoint: geoPoint(ride.dropoff),
    route: `${pickup} → ${dropoff}`,
    budget: ride.offeredFareVnd ?? ride.referenceFareVnd ?? 0,
    lowest: ride.agreedFareVnd ?? lowestOfferAmount(ride.offers ?? []),
    bids: offers.length,
    offers,
    expires: formatOpsClock(ride.expiresAt),
    expiresDate: formatOpsDate(ride.expiresAt),
    status: mapRideStatus(ride.status),
  };
}

function toNestStatus(status: string | null | undefined): string | undefined {
  if (!status || status === "ALL") return undefined;
  if (status === "OPEN") return "NEGOTIATING";
  if (status === "EXPIRED") return "EXPIRED";
  if (status === "LOCKED") return "ASSIGNED";
  if (status === "ACCEPTED") return "COMPLETED";
  return status;
}

export async function fetchNegotiations(
  params: FetchNegotiationsParams,
): Promise<PaginatedList<NegotiationSession>> {
  const search = new URLSearchParams();
  search.set("page", String(params.page));
  search.set("limit", String(params.limit));

  const nestStatus = toNestStatus(params.status);
  if (nestStatus) {
    search.set("status", nestStatus);
  }
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.region && params.region !== "ALL") {
    search.set("zone", params.region);
  }

  const envelope = await apiFetch<{
    success: boolean;
    data: NestRidePage;
  }>(`${apiPaths.opsRides()}?${search.toString()}`);

  const data = envelope.data;
  return {
    items: (data.items || []).map(mapNestRide),
    total: data.total,
    page: data.page,
    limit: data.limit,
  };
}

export async function fetchNegotiationByCode(
  code: string,
): Promise<NegotiationSession | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestRideView;
    }>(apiPaths.opsRide(code));
    return mapNestRide(envelope.data);
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return null;
    }
    throw err;
  }
}
