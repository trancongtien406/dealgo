import {
  mapNestStoreToListItem,
  mapNestStoreDetailToItem,
} from "@/features/stores/mappers";
import type {
  NestOpsStore,
  NestOpsStoreDetail,
  NestOpsStorePage,
} from "@/features/stores/nest-types";
import type { StoreListItem } from "@/features/stores/types";
import { apiFetch } from "@/lib/api/client";
import type { PaginatedList } from "@/lib/api/pagination";
import { apiPaths } from "@/lib/api/paths";
import {
  parseMerchantStatement,
  type MerchantStatement,
} from "@/lib/merchant-statement";

export type FetchStoresParams = {
  page?: number;
  limit?: number;
  q?: string;
  sale?: string | null;
  region?: string | null;
  category?: string | null;
  kyb?: string | null;
  /** "MISSING" = stores without map coordinates. */
  location?: string | null;
};

export async function fetchStores(
  params: FetchStoresParams,
): Promise<PaginatedList<StoreListItem>> {
  return fetchStoresFromBff(params);
}

export async function fetchStoreByCode(
  code: string,
): Promise<StoreListItem | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestOpsStoreDetail;
    }>(apiPaths.opsStore(code));
    return mapNestStoreDetailToItem(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

async function fetchStoresFromBff(
  params: FetchStoresParams,
): Promise<PaginatedList<StoreListItem>> {
  const page = Math.max(1, params.page ?? 1);
  const limit = Math.max(1, Math.min(50, params.limit ?? 20));
  const search = new URLSearchParams({
    page: String(page),
    limit: String(limit),
  });
  if (params.q?.trim()) {
    search.set("q", params.q.trim());
  }
  if (params.sale && params.sale !== "ALL") {
    search.set("sale", params.sale);
  }
  if (params.region && params.region !== "ALL") {
    search.set("region", params.region);
  }
  if (params.category && params.category !== "ALL") {
    search.set("category", params.category);
  }
  if (params.kyb && params.kyb !== "ALL") {
    search.set("kyb", params.kyb);
  }
  if (params.location === "MISSING") {
    search.set("location", "MISSING");
  }
  const envelope = await apiFetch<{
    success: boolean;
    data: NestOpsStorePage;
  }>(`${apiPaths.opsStores()}?${search.toString()}`);
  const pageData = envelope.data;

  return {
    page: pageData.page,
    limit: pageData.limit,
    total: pageData.total,
    items: pageData.items.map(mapNestStoreToListItem),
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

/** Commission statement for one store over an ICT day range. */
export async function fetchStoreStatement(
  storeId: string,
  range: { from: string; to: string },
): Promise<MerchantStatement> {
  const search = new URLSearchParams(range);
  const envelope = await apiFetch<{ success: boolean; data: unknown }>(
    `${apiPaths.opsStoreStatement(storeId)}?${search.toString()}`,
  );
  return parseMerchantStatement(envelope.data);
}

/** Record that the store paid the commission for closed days (audited). */
export async function recordStoreSettlement(
  storeId: string,
  input: { from: string; to: string; reason: string; note?: string },
): Promise<void> {
  await apiFetch(apiPaths.opsStoreSettlements(storeId), {
    method: "POST",
    body: input,
  });
}
