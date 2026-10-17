import { apiFetch } from "@/lib/api/client";
import { ApiError } from "@/lib/api/errors";
import { apiPaths } from "@/lib/api/paths";
import type { PaginatedList } from "@/lib/api/pagination";
import type { DeliveryStatus } from "@/features/deliveries/types";

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
};

export type FetchDeliveriesParams = {
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
      data: {
        id: string;
        customerId: string;
        storeId: string;
        status: string;
        deliveryFareVnd: number;
        totalVnd: number;
        dropoff?: { label?: string };
        assignedDriverId: string | null;
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
      sender: `CH · ${order.storeId.slice(0, 8)}`,
      route: order.dropoff?.label?.trim() || "Điểm giao",
      cargo,
      fee: order.deliveryFareVnd ?? order.totalVnd ?? 0,
      driver: order.assignedDriverId
        ? `TX · ${order.assignedDriverId.slice(0, 8)}`
        : null,
      status: statusMap[order.status] ?? "WAITING_DRIVER",
      time: "—",
    };
  } catch (err) {
    if (err instanceof ApiError && err.status === 404) {
      return null;
    }
    throw err;
  }
}
