"use client";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchStoreByCode,
  fetchStores,
  fetchStoreStatement,
  recordStoreSettlement,
  type FetchStoresParams,
} from "@/features/stores/api";
import { listSearchParams } from "@/lib/list-search-params";

export const storesQueryKeys = {
  all: ["stores"] as const,
  list: (filters: FetchStoresParams) => ["stores", "list", filters] as const,
  detail: (code: string) => ["stores", "detail", code] as const,
  statement: (code: string, from: string, to: string) =>
    ["stores", "statement", code, from, to] as const,
};

export function useStoresFilters() {
  return useQueryStates({
    ...listSearchParams,
    sale: parseAsString.withDefault("ALL"),
    region: parseAsString.withDefault("ALL"),
    category: parseAsString.withDefault("ALL"),
    kyb: parseAsString.withDefault("ALL"),
    location: parseAsString.withDefault("ALL"),
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
    location: filters.location === "ALL" ? null : filters.location,
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

/** Store commission statement (settlements.read). */
export function useStoreStatementQuery(
  code: string,
  range: { from: string; to: string } | null,
) {
  return useQuery({
    queryKey: storesQueryKeys.statement(
      code,
      range?.from ?? "",
      range?.to ?? "",
    ),
    queryFn: () => fetchStoreStatement(code, range!),
    enabled: Boolean(code && range),
  });
}

/** Record a commission payment; refreshes every statement of the store. */
export function useRecordStoreSettlementMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      from: string;
      to: string;
      reason: string;
      note?: string;
    }) => recordStoreSettlement(code, input),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: ["stores", "statement", code],
      });
    },
  });
}
