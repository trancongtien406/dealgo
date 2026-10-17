import {
  mapNestFoodOrderToListItem,
  nestFoodOrderStatusToFeature,
} from "@/features/food-orders/mappers";
import type {
  NestFoodOrderPage,
  NestFoodOrderView,
} from "@/features/food-orders/nest-types";
import type {
  FoodOrderListItem,
  FoodOrderStatus,
} from "@/features/food-orders/types";
import { apiFetch } from "@/lib/api/client";
import type { ListQuery, PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";

export type FetchFoodOrdersParams = ListQuery & {
  status?: FoodOrderStatus | "ALL";
  store?: string | null;
  payment?: string | null;
  zone?: string | null;
};

export async function fetchFoodOrders(
  params: FetchFoodOrdersParams,
): Promise<PaginatedList<FoodOrderListItem>> {
  return fetchFoodOrdersFromBff(params);
}

export async function fetchFoodOrderByCode(
  code: string,
): Promise<FoodOrderListItem | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestFoodOrderView;
    }>(apiPaths.opsFoodOrder(code));
    return mapNestFoodOrderToListItem(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

export async function cancelFoodOrder(
  id: string,
  reason: string,
): Promise<FoodOrderListItem> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestFoodOrderView;
  }>(apiPaths.opsFoodOrderCancel(id), {
    method: "POST",
    body: { reason },
  });
  return mapNestFoodOrderToListItem(envelope.data);
}

export async function reassignFoodOrder(
  id: string,
  reason: string,
): Promise<FoodOrderListItem> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestFoodOrderView;
  }>(apiPaths.opsFoodOrderReassign(id), {
    method: "POST",
    body: { reason },
  });
  return mapNestFoodOrderToListItem(envelope.data);
}

async function fetchFoodOrdersFromBff(
  params: FetchFoodOrdersParams,
): Promise<PaginatedList<FoodOrderListItem>> {
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
  if (params.store && params.store !== "ALL") {
    queryRecord.store = params.store;
  }
  if (params.payment && params.payment !== "ALL") {
    queryRecord.payment = params.payment;
  }
  if (params.zone && params.zone !== "ALL") {
    queryRecord.zone = params.zone;
  }

  const search = new URLSearchParams(queryRecord);
  const envelope = await apiFetch<{
    success: boolean;
    data: NestFoodOrderPage;
  }>(`${apiPaths.opsFoodOrders()}?${search.toString()}`);
  const page = envelope.data;
  const items = page.items.map(mapNestFoodOrderToListItem);

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

export { nestFoodOrderStatusToFeature };
