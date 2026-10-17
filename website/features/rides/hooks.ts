"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import {
  cancelRide,
  fetchRideByCode,
  fetchRides,
  reassignRide,
} from "@/features/rides/api";
import { ledgerQueryKeys } from "@/features/ledger/hooks";
import { listSearchParams } from "@/lib/list-search-params";

const rideStatusFilterValues = [
  "ALL",
  "WAITING",
  "PICKING_UP",
  "IN_TRIP",
  "COMPLETED",
  "CANCELLED",
] as const;

export type RideListFilterStatus = (typeof rideStatusFilterValues)[number];

export const rideQueryKeys = {
  all: ["rides"] as const,
  list: (filters: {
    status: RideListFilterStatus;
    zone?: string | null;
    q: string;
    page: number;
    limit: number;
  }) => [...rideQueryKeys.all, "list", filters] as const,
  detail: (code: string) => [...rideQueryKeys.all, "detail", code] as const,
};

export function useRideListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(rideStatusFilterValues).withDefault("ALL"),
    zone: parseAsString.withDefault("ALL"),
  });
}

export function useRidesQuery() {
  const [filters] = useRideListFilters();
  const params = {
    status: filters.status,
    zone: filters.zone === "ALL" ? null : filters.zone,
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
  };
  return useQuery({
    queryKey: rideQueryKeys.list(params),
    queryFn: () => fetchRides(params),
    refetchOnMount: "always",
    staleTime: 0,
  });
}

export function useRideDetailQuery(code: string) {
  return useQuery({
    queryKey: rideQueryKeys.detail(code),
    queryFn: () => fetchRideByCode(code),
  });
}

export function useCancelRideMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (reason: string) => cancelRide(code, reason),
    onSuccess: (updated) => {
      queryClient.setQueryData(rideQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: rideQueryKeys.all });
      void queryClient.invalidateQueries({
        queryKey: ledgerQueryKeys.ride(code),
      });
    },
  });
}

export function useReassignRideMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (reason: string) => reassignRide(code, reason),
    onSuccess: (updated) => {
      queryClient.setQueryData(rideQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: rideQueryKeys.all });
    },
  });
}
