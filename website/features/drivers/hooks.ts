"use client";
import { useQuery } from "@tanstack/react-query";
import { parseAsString, useQueryStates } from "nuqs";
import {
  fetchDriverByCode,
  fetchDrivers,
  type FetchDriversParams,
} from "@/features/drivers/api";
import { listSearchParams } from "@/lib/list-search-params";

export const driversQueryKeys = {
  all: ["drivers"] as const,
  list: (filters: FetchDriversParams) => ["drivers", "list", filters] as const,
  detail: (code: string) => ["drivers", "detail", code] as const,
};

export function useDriversFilters() {
  return useQueryStates({
    ...listSearchParams,
    service: parseAsString.withDefault("ALL"),
    region: parseAsString.withDefault("ALL"),
    activity: parseAsString.withDefault("ALL"),
    kyc: parseAsString.withDefault("ALL"),
  });
}

export function useDriversQuery() {
  const [filters] = useDriversFilters();
  const params: FetchDriversParams = {
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
    service: filters.service === "ALL" ? null : filters.service,
    region: filters.region === "ALL" ? null : filters.region,
    activity: filters.activity === "ALL" ? null : filters.activity,
    kyc: filters.kyc === "ALL" ? null : filters.kyc,
  };
  return useQuery({
    queryKey: driversQueryKeys.list(params),
    queryFn: () => fetchDrivers(params),
  });
}

export function useDriverDetailQuery(code: string) {
  return useQuery({
    queryKey: driversQueryKeys.detail(code),
    queryFn: () => fetchDriverByCode(code),
  });
}
