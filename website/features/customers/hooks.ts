"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import {
  fetchCustomerActivities,
  fetchCustomerByCode,
  fetchCustomers,
  type FetchCustomersParams,
} from "@/features/customers/api";
import { listSearchParams } from "@/lib/list-search-params";

const customerStatusFilterValues = [
  "ALL",
  "ACTIVE",
  "NEEDS_SUPPORT",
  "SUSPENDED",
] as const;

export type CustomerListFilterStatus =
  (typeof customerStatusFilterValues)[number];

export const customerQueryKeys = {
  all: ["customers"] as const,
  list: (filters: FetchCustomersParams) =>
    [...customerQueryKeys.all, "list", filters] as const,
  detail: (code: string) => [...customerQueryKeys.all, "detail", code] as const,
  activities: (code: string, tab?: string, page?: number) =>
    [
      ...customerQueryKeys.all,
      "activities",
      code,
      tab ?? "ALL",
      page ?? 1,
    ] as const,
};

export function useCustomerListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(customerStatusFilterValues).withDefault("ALL"),
    region: parseAsString.withDefault("ALL"),
    service: parseAsString.withDefault("ALL"),
  });
}

export function useCustomersQuery() {
  const [filters] = useCustomerListFilters();
  const params: FetchCustomersParams = {
    status: filters.status,
    region: filters.region === "ALL" ? null : filters.region,
    service: filters.service === "ALL" ? null : filters.service,
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
  };
  return useQuery({
    queryKey: customerQueryKeys.list(params),
    queryFn: () => fetchCustomers(params),
  });
}

export function useCustomerDetailQuery(code: string) {
  return useQuery({
    queryKey: customerQueryKeys.detail(code),
    queryFn: () => fetchCustomerByCode(code),
  });
}

export function useCustomerActivitiesQuery(
  code: string,
  tab: string,
  page = 1,
) {
  return useQuery({
    queryKey: customerQueryKeys.activities(code, tab, page),
    queryFn: () => fetchCustomerActivities({ code, tab, page, limit: 6 }),
  });
}
