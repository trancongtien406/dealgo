import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

/** Public, read-only trip snapshot (`GET /v1/public/ride-shares/:token`). */
export type RideShareView = {
  status: string;
  pickupLabel: string;
  dropoffLabel: string;
  driver: {
    name: string;
    vehiclePlate: string | null;
    vehicleType: string | null;
    ratingAverage: number | null;
  } | null;
  updatedAt: string;
  expiresAt: string;
};

export type RideShareResult =
  | { kind: "ok"; view: RideShareView }
  | { kind: "not-found" }
  | { kind: "expired" }
  | { kind: "unavailable" };

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

const STATUS_LABELS: Record<string, string> = {
  NEGOTIATING: "Đang tìm tài xế",
  ASSIGNED: "Tài xế đã nhận chuyến",
  DRIVER_EN_ROUTE: "Tài xế đang đến điểm đón",
  DRIVER_ARRIVED: "Tài xế đã đến điểm đón",
  IN_TRIP: "Đang trong chuyến đi",
  COMPLETED: "Chuyến đi đã hoàn thành",
  CANCELLED: "Chuyến đi đã hủy",
  EXPIRED: "Yêu cầu đã hết hạn",
};

export function rideShareStatusLabel(status: string): string {
  return STATUS_LABELS[status] ?? "Đang cập nhật trạng thái";
}

const VEHICLE_LABELS: Record<string, string> = {
  MOTORBIKE: "Xe máy",
  CAR: "Ô tô",
};

export function rideShareVehicleLabel(type: string | null): string | null {
  if (!type) return null;
  return VEHICLE_LABELS[type] ?? type;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

export function parseRideShareView(data: unknown): RideShareView | null {
  if (!data || typeof data !== "object") return null;
  const d = data as Record<string, unknown>;
  const status = str(d.status);
  const updatedAt = str(d.updatedAt);
  const expiresAt = str(d.expiresAt);
  if (!status || !updatedAt || !expiresAt) return null;
  let driver: RideShareView["driver"] = null;
  if (d.driver && typeof d.driver === "object") {
    const raw = d.driver as Record<string, unknown>;
    const name = str(raw.name);
    if (name) {
      driver = {
        name,
        vehiclePlate: str(raw.vehiclePlate),
        vehicleType: str(raw.vehicleType),
        ratingAverage:
          typeof raw.ratingAverage === "number" ? raw.ratingAverage : null,
      };
    }
  }
  return {
    status,
    pickupLabel: str(d.pickupLabel) ?? "—",
    dropoffLabel: str(d.dropoffLabel) ?? "—",
    driver,
    updatedAt,
    expiresAt,
  };
}

export async function fetchRideShare(
  token: string,
  fetcher: typeof fetch = fetch,
): Promise<RideShareResult> {
  if (!TOKEN_PATTERN.test(token)) return { kind: "not-found" };
  const base = nestApiBaseUrl();
  if (!base) return { kind: "unavailable" };
  try {
    const res = await fetcher(
      `${base}/v1/public/ride-shares/${encodeURIComponent(token)}`,
      { cache: "no-store", signal: AbortSignal.timeout(4_000) },
    );
    if (res.status === 404) return { kind: "not-found" };
    if (res.status === 410) return { kind: "expired" };
    if (!res.ok) return { kind: "unavailable" };
    const envelope: unknown = await res.json().catch(() => null);
    const data =
      envelope && typeof envelope === "object" && "data" in envelope
        ? (envelope as { data: unknown }).data
        : null;
    const view = parseRideShareView(data);
    return view ? { kind: "ok", view } : { kind: "unavailable" };
  } catch {
    return { kind: "unavailable" };
  }
}

/** Poll interval while the trip is live; matches the per-link API budget (30 views/min). */
export const RIDE_SHARE_POLL_MS = 15_000;
/** Slower retry while the backend is unreachable or throttled. */
export const RIDE_SHARE_RETRY_MS = 30_000;

const FINISHED_STATUSES = new Set(["COMPLETED", "CANCELLED", "EXPIRED"]);

export function isRideShareFinished(status: string): boolean {
  return FINISHED_STATUSES.has(status);
}

/**
 * Delay before the share page refreshes itself, or null to stop: the trip ended,
 * the link expired, or the link does not exist.
 */
export function nextRideShareRefreshMs(
  result: RideShareResult,
  now: Date = new Date(),
): number | null {
  if (result.kind === "unavailable") return RIDE_SHARE_RETRY_MS;
  if (result.kind !== "ok") return null;
  if (isRideShareFinished(result.view.status)) return null;
  const expiresAt = Date.parse(result.view.expiresAt);
  if (Number.isFinite(expiresAt) && expiresAt <= now.getTime()) return null;
  return RIDE_SHARE_POLL_MS;
}
