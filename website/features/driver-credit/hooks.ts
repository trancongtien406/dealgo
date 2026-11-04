"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchDriverCreditSummary,
  fetchDriverTopUps,
  reconcileDriverTopUp,
  reconcilePendingDriverTopUps,
  refundDriverTopUp,
} from "@/features/driver-credit/api";
import type { DriverTopUpFilter } from "@/features/driver-credit/types";

export const driverCreditQueryKeys = {
  all: ["ops", "driver-credit"] as const,
  topUps: (filter: DriverTopUpFilter) =>
    [...driverCreditQueryKeys.all, "top-ups", filter] as const,
  summary: () => [...driverCreditQueryKeys.all, "summary"] as const,
};

export function useDriverTopUpsQuery(filter: DriverTopUpFilter) {
  return useQuery({
    queryKey: driverCreditQueryKeys.topUps(filter),
    queryFn: () => fetchDriverTopUps(filter),
  });
}

export function useDriverCreditSummaryQuery() {
  return useQuery({
    queryKey: driverCreditQueryKeys.summary(),
    queryFn: fetchDriverCreditSummary,
  });
}

function useInvalidateDriverCredit() {
  const queryClient = useQueryClient();
  return () => {
    void queryClient.invalidateQueries({ queryKey: driverCreditQueryKeys.all });
    void queryClient.invalidateQueries({ queryKey: ["ops", "users"] });
  };
}

export function useReconcileDriverTopUpMutation() {
  const invalidate = useInvalidateDriverCredit();
  return useMutation({
    mutationFn: (id: string) => reconcileDriverTopUp(id),
    onSuccess: invalidate,
  });
}

export function useReconcilePendingDriverTopUpsMutation() {
  const invalidate = useInvalidateDriverCredit();
  return useMutation({
    mutationFn: reconcilePendingDriverTopUps,
    onSuccess: invalidate,
  });
}

export function useRefundDriverTopUpMutation() {
  const invalidate = useInvalidateDriverCredit();
  return useMutation({
    mutationFn: (input: { id: string; reason: string; bankRef: string }) =>
      refundDriverTopUp(input.id, {
        reason: input.reason,
        bankRef: input.bankRef,
      }),
    onSuccess: invalidate,
  });
}
