import {
  mapNestRideToListItem,
  nestRideStatusToFeature,
} from "@/features/rides/mappers";
import type { NestRidePage, NestRideView } from "@/features/rides/nest-types";
import type { RideListItem, RideStatus } from "@/features/rides/types";
import { apiFetch } from "@/lib/api/client";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchRidesParams = ListQuery & {
  status?: RideStatus | "ALL";
  zone?: string | null;
};

export async function fetchRides(
  params: FetchRidesParams,
): Promise<PaginatedList<RideListItem>> {
  return fetchRidesFromBff(params);
}

export async function fetchRideByCode(
  code: string,
): Promise<RideListItem | null> {
  try {
    const envelope = await apiFetch<{ success: boolean; data: NestRideView }>(
      apiPaths.opsRide(code),
    );
    return mapNestRideToListItem(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

export async function cancelRide(
  id: string,
  reason: string,
): Promise<RideListItem> {
  const envelope = await apiFetch<{ success: boolean; data: NestRideView }>(
    apiPaths.opsRideCancel(id),
    { method: "POST", body: { reason } },
  );
  return mapNestRideToListItem(envelope.data);
}

export async function reassignRide(
  id: string,
  reason: string,
): Promise<RideListItem> {
  const envelope = await apiFetch<{ success: boolean; data: NestRideView }>(
    apiPaths.opsRideReassign(id),
    { method: "POST", body: { reason } },
  );
  return mapNestRideToListItem(envelope.data);
}

async function fetchRidesFromBff(
  params: FetchRidesParams,
): Promise<PaginatedList<RideListItem>> {
  const queryRecord: Record<string, string> = {
    page: String(Math.max(1, params.page)),
    limit: String(Math.max(1, Math.min(50, params.limit))),
  };
  if (params.status && params.status !== "ALL") {
    queryRecord.status = params.status;
  }
  if (params.q?.trim()) {
    queryRecord.q = params.q.trim();
  }
  if (params.zone && params.zone !== "ALL") {
    queryRecord.zone = params.zone;
  }

  const search = new URLSearchParams(queryRecord);
  const envelope = await apiFetch<{ success: boolean; data: NestRidePage }>(
    `${apiPaths.opsRides()}?${search.toString()}`,
  );
  const page = envelope.data;
  const items = page.items.map(mapNestRideToListItem);

  return {
    page: page.page,
    limit: page.limit,
    total: page.total,
    items,
  };
}

function isNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code: string }).code === "NOT_FOUND"
  );
}

/** Exported for tests — Nest status → feature EN status. */
export { nestRideStatusToFeature };
