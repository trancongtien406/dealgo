"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";

import {
  fetchDeliveries,
  fetchDeliveryByCode,
} from "@/features/deliveries/api";
import { listSearchParams } from "@/lib/list-search-params";

export const deliveriesQueryKeys = {
  all: ["deliveries"] as const,
  list: (filters: {
    q: string;
    page: number;
    limit: number;
    status?: string | null;
  }) => ["deliveries", "list", filters] as const,
  detail: (code: string) => ["deliveries", "detail", code] as const,
};

export function useDeliveriesFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsString.withDefault(""),
  });
}

export function useDeliveriesQuery() {
  const [filters] = useDeliveriesFilters();
  const queryParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    status: filters.status || null,
  };
  return useQuery({
    queryKey: deliveriesQueryKeys.list(queryParams),
    queryFn: () => fetchDeliveries(queryParams),
  });
}

export function useDeliveryDetailQuery(code: string) {
  return useQuery({
    queryKey: deliveriesQueryKeys.detail(code),
    queryFn: () => fetchDeliveryByCode(code),
  });
}
