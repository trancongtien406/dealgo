"use client";

import { useQuery } from "@tanstack/react-query";
import { parseAsStringLiteral, useQueryStates } from "nuqs";
import { fetchParcel, fetchParcels } from "@/features/parcels/api";
import { PARCEL_OUTCOMES } from "@/features/parcels/types";
import { listSearchParams } from "@/lib/list-search-params";

const outcomeFilterValues = ["ALL", ...PARCEL_OUTCOMES] as const;

export const parcelQueryKeys = {
  all: ["parcels"] as const,
  list: (f: object) => [...parcelQueryKeys.all, "list", f] as const,
  detail: (id: string) => [...parcelQueryKeys.all, "detail", id] as const,
};

export function useParcelListFilters() {
  return useQueryStates({
    ...listSearchParams,
    outcome: parseAsStringLiteral(outcomeFilterValues).withDefault("ALL"),
  });
}

export function useParcelsQuery() {
  const [filters] = useParcelListFilters();
  const params = { page: filters.page, limit: filters.limit, q: filters.q, outcome: filters.outcome };
  return useQuery({ queryKey: parcelQueryKeys.list(params), queryFn: () => fetchParcels(params), staleTime: 0 });
}

export function useParcelQuery(id: string) {
  return useQuery({ queryKey: parcelQueryKeys.detail(id), queryFn: () => fetchParcel(id), staleTime: 0 });
}
