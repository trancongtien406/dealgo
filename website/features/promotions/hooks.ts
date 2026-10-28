"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchPromotions,
  type FetchPromotionsParams,
} from "@/features/promotions/api";
import { listSearchParams } from "@/lib/list-search-params";

export const promotionsQueryKeys = {
  all: ["promotions"] as const,
  list: (params: FetchPromotionsParams) =>
    ["promotions", "list", params] as const,
};

export function usePromotionsFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsString.withDefault(""),
    channel: parseAsString.withDefault(""),
    audience: parseAsString.withDefault(""),
    scope: parseAsString.withDefault(""),
  });
}

export function usePromotionsQuery() {
  const [filters] = usePromotionsFilters();
  const params: FetchPromotionsParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    status: filters.status || null,
    channel: filters.channel || null,
    audience: filters.audience || null,
    scope: filters.scope || null,
  };
  return useQuery({
    queryKey: promotionsQueryKeys.list(params),
    queryFn: () => fetchPromotions(params),
  });
}
