import { fetchOpsUpstream } from "@/lib/api/ops-upstream";

/** Row of Nest `GET /v1/ops/people` (phone already masked server-side). */
export type OpsPerson = {
  id: string;
  displayName: string | null;
  phoneMasked: string | null;
  vehiclePlate: string | null;
  vehicleType: string | null;
  ratingAverage: number | null;
  ratingCount: number;
  /** DEC-PROD-034: rides COMPLETED + food DELIVERED while assigned (lifetime). */
  completedJobs?: number;
  /** Completed + cancelled/failed after assignment. */
  finishedJobs?: number;
  /** completedJobs / finishedJobs (0..1); null when nothing finished. */
  completionRate?: number | null;
};

export type OpsPeopleMap = Record<string, OpsPerson>;

const MAX_IDS = 100;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Best-effort batch lookup used by BFF routes to put real names, masked phones
 * and plates on Admin rows. A failed lookup yields `{}` so the list still
 * renders (UI shows "—" instead of invented labels).
 */
export async function fetchOpsPeople(
  ids: ReadonlyArray<string | null | undefined>,
): Promise<OpsPeopleMap> {
  const unique = [
    ...new Set(
      ids.filter(
        (id): id is string => typeof id === "string" && UUID_RE.test(id),
      ),
    ),
  ].slice(0, MAX_IDS);
  if (unique.length === 0) return {};
  const result = await fetchOpsUpstream({
    path: "/v1/ops/people",
    searchParams: { ids: unique.join(",") },
  });
  if (!result.ok || !Array.isArray(result.data)) return {};
  const map: OpsPeopleMap = {};
  for (const row of result.data as OpsPerson[]) {
    if (row && typeof row.id === "string") map[row.id] = row;
  }
  return map;
}

type RideLike = {
  customerId?: string | null;
  assignedDriverId?: string | null;
  offers?: Array<{ driverId?: string | null } & Record<string, unknown>>;
} & Record<string, unknown>;

/** Adds `customerProfile`, `driverProfile` and `offers[].driverProfile` to Nest ride views. */
export async function enrichOpsRides<T extends RideLike>(
  rides: T[],
): Promise<
  Array<
    T & {
      customerProfile: OpsPerson | null;
      driverProfile: OpsPerson | null;
    }
  >
> {
  const ids: Array<string | null | undefined> = [];
  for (const ride of rides) {
    ids.push(ride.customerId, ride.assignedDriverId);
    for (const offer of ride.offers ?? []) ids.push(offer.driverId);
  }
  const people = await fetchOpsPeople(ids);
  return rides.map((ride) => ({
    ...ride,
    customerProfile: (ride.customerId && people[ride.customerId]) || null,
    driverProfile:
      (ride.assignedDriverId && people[ride.assignedDriverId]) || null,
    ...(ride.offers
      ? {
          offers: ride.offers.map((offer) => ({
            ...offer,
            driverProfile: (offer.driverId && people[offer.driverId]) || null,
          })),
        }
      : {}),
  }));
}

/**
 * Ride / food-order payload helper for BFF routes: page (`items`) or a single
 * view. Works on anything carrying `customerId` / `assignedDriverId`.
 */
export async function enrichOpsRidePayload(data: unknown): Promise<unknown> {
  if (!data || typeof data !== "object") return data;
  const record = data as Record<string, unknown>;
  if (Array.isArray(record.items)) {
    return {
      ...record,
      items: await enrichOpsRides(record.items as RideLike[]),
    };
  }
  if (typeof record.id === "string") {
    const [ride] = await enrichOpsRides([record as RideLike]);
    return ride;
  }
  return data;
}

/** Adds `profile` (vehicle plate/type, rating) to Nest ops driver rows. */
export async function enrichOpsDriverPayload(data: unknown): Promise<unknown> {
  if (!data || typeof data !== "object") return data;
  const record = data as Record<string, unknown>;
  const withProfile = (rows: Array<Record<string, unknown>>, people: OpsPeopleMap) =>
    rows.map((row) => ({
      ...row,
      profile:
        (typeof row.id === "string" && people[row.id as string]) || null,
    }));
  if (Array.isArray(record.items)) {
    const rows = record.items as Array<Record<string, unknown>>;
    const people = await fetchOpsPeople(rows.map((row) => row.id as string));
    return { ...record, items: withProfile(rows, people) };
  }
  if (typeof record.id === "string") {
    const people = await fetchOpsPeople([record.id]);
    return withProfile([record], people)[0];
  }
  return data;
}

/** Food orders carry the same `customerId` / `assignedDriverId` pair. */
export const enrichOpsFoodOrderPayload = enrichOpsRidePayload;
