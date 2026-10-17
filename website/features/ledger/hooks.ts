"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchFoodOrderLedger, fetchRideLedger } from "@/features/ledger/api";

export const ledgerQueryKeys = {
  all: ["ledger"] as const,
  ride: (id: string) => [...ledgerQueryKeys.all, "ride", id] as const,
  foodOrder: (id: string) =>
    [...ledgerQueryKeys.all, "food-order", id] as const,
};

export function useRideLedgerQuery(rideId: string) {
  return useQuery({
    queryKey: ledgerQueryKeys.ride(rideId),
    queryFn: () => fetchRideLedger(rideId),
    enabled: Boolean(rideId),
  });
}

export function useFoodOrderLedgerQuery(orderId: string) {
  return useQuery({
    queryKey: ledgerQueryKeys.foodOrder(orderId),
    queryFn: () => fetchFoodOrderLedger(orderId),
    enabled: Boolean(orderId),
  });
}
