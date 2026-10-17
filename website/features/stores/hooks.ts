"use client";
import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchStoreByCode,
  fetchStores,
  type FetchStoresParams,
} from "@/features/stores/api";
import { listSearchParams } from "@/lib/list-search-params";

export const storesQueryKeys = {
  all: ["stores"] as const,
  list: (filters: FetchStoresParams) => ["stores", "list", filters] as const,
  detail: (code: string) => ["stores", "detail", code] as const,
};

export function useStoresFilters() {
  return useQueryStates({
    ...listSearchParams,
    sale: parseAsString.withDefault("ALL"),
    region: parseAsString.withDefault("ALL"),
    category: parseAsString.withDefault("ALL"),
    kyb: parseAsString.withDefault("ALL"),
  });
}

export function useStoresQuery() {
  const [filters] = useStoresFilters();
  const params: FetchStoresParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    sale: filters.sale === "ALL" ? null : filters.sale,
    region: filters.region === "ALL" ? null : filters.region,
    category: filters.category === "ALL" ? null : filters.category,
    kyb: filters.kyb === "ALL" ? null : filters.kyb,
  };
  return useQuery({
    queryKey: storesQueryKeys.list(params),
    queryFn: () => fetchStores(params),
  });
}

export function useStoreDetailQuery(code: string) {
  return useQuery({
    queryKey: storesQueryKeys.detail(code),
    queryFn: () => fetchStoreByCode(code),
  });
}
