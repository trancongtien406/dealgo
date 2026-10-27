import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";
import { formatOpsDateTime } from "@/lib/ops-time";
import { setOpsDateRange, type OpsDateRange } from "@/lib/api/ops-date-range";
import type { PaginatedList } from "@/lib/api/pagination";
import type { DeliveryStatus } from "@/features/deliveries/types";
import type { NestFoodOrderView } from "@/features/food-orders/nest-types";
import { geoPoint, personLabel } from "@/features/rides/mappers";

export type DeliveryItem = {
  code: string;
  sender: string;
  route: string;
  cargo: string;
  fee: number;
  driver: string | null;
  status: DeliveryStatus;
  time: string;
  regionLabel?: string;
  pickupPoint?: { lat: number; lng: number } | null;
  dropoffPoint?: { lat: number; lng: number } | null;
};

export type FetchDeliveriesParams = OpsDateRange & {
  page?: number;
  limit?: number;
  q?: string;
  status?: string | null;
};

export async function fetchDeliveries(
  params: FetchDeliveriesParams,
): Promise<PaginatedList<DeliveryItem>> {
  const search = new URLSearchParams();
  search.set("page", String(Math.max(1, params.page ?? 1)));
  search.set("limit", String(Math.max(1, params.limit ?? 10)));
  if (params.q?.trim()) search.set("q", params.q.trim());
  if (params.status && params.status !== "ALL")
    search.set("status", params.status);
  setOpsDateRange(search, params);

  const envelope = await apiFetch<{
    success: boolean;
    data: PaginatedList<DeliveryItem>;
  }>(`${apiPaths.opsDeliveries()}?${search.toString()}`);
  return envelope.data;
}

export async function fetchDeliveryByCode(
  code: string,
): Promise<DeliveryItem | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: Pick<
        NestFoodOrderView,
        | "id"
        | "customerId"
        | "storeId"
        | "storeName"
        | "status"
        | "deliveryFareVnd"
        | "totalVnd"
        | "pickup"
        | "assignedDriverId"
        | "driverProfile"
        | "createdAt"
      > & {
        dropoff?: { lat?: number; lng?: number; label?: string };
        lines?: Array<{ name: string; quantity: number }>;
      };
    }>(apiPaths.opsFoodOrder(code));
    const order = envelope.data;
    const cargo =
      order.lines && order.lines.length > 0
        ? order.lines.map((l) => `${l.name} x${l.quantity}`).join(", ")
        : "Đơn đồ ăn";
    const statusMap: Record<string, DeliveryStatus> = {
      PLACED: "WAITING_DRIVER",
      PREPARING: "WAITING_DRIVER",
      READY: "WAITING_DRIVER",
      ASSIGNED: "DELIVERING",
      PICKED_UP: "PICKED_UP",
      DELIVERED: "COMPLETED",
      FAILED: "FAILED",
      CANCELLED: "FAILED",
    };
    return {
      code: order.id,
      sender: order.storeName?.trim() || `CH · ${order.storeId.slice(0, 8)}`,
      route: order.dropoff?.label?.trim() || "Điểm giao",
      cargo,
      fee: order.deliveryFareVnd ?? order.totalVnd ?? 0,
      driver: order.assignedDriverId
        ? personLabel(order.driverProfile, "TX", order.assignedDriverId)
        : null,
      status: statusMap[order.status] ?? "WAITING_DRIVER",
      time: formatOpsDateTime(order.createdAt),
      pickupPoint: geoPoint(order.pickup),
      dropoffPoint: geoPoint(order.dropoff),
    };
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return null;
    }
    throw err;
  }
}
