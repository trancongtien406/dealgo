"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  approveStoreApplication,
  fetchStoreApprovals,
  rejectStoreApplication,
  type FetchStoreApprovalsParams,
} from "@/features/store-approvals/api";

export const storeApprovalsQueryKey = ["ops", "store-approvals"] as const;

export function useStoreApprovalsQuery(params: FetchStoreApprovalsParams) {
  return useQuery({
    queryKey: [
      ...storeApprovalsQueryKey,
      params.status ?? "ALL",
      params.page ?? 1,
      params.limit ?? 10,
      params.q ?? "",
    ],
    queryFn: () => fetchStoreApprovals(params),
  });
}

export function useApproveStoreMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => approveStoreApplication(id),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: storeApprovalsQueryKey });
    },
  });
}

export function useRejectStoreMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      rejectStoreApplication(id, reason),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: storeApprovalsQueryKey });
    },
  });
}
