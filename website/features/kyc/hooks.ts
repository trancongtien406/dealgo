"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { parseAsStringLiteral, useQueryStates } from "nuqs";
import {
  approveKycApplication,
  fetchKycByCode,
  fetchKycQueue,
  rejectKycApplication,
} from "@/features/kyc/api";
import { listSearchParams } from "@/lib/list-search-params";

const kycStatusFilterValues = [
  "ALL",
  "UNDER_REVIEW",
  "NEEDS_MORE_INFO",
  "APPROVED",
  "REJECTED",
  "PRIORITY",
] as const;

export type KycListFilterStatus = (typeof kycStatusFilterValues)[number];

export const kycQueryKeys = {
  all: ["kyc"] as const,
  list: (filters: {
    status: KycListFilterStatus;
    q: string;
    page: number;
    limit: number;
  }) => [...kycQueryKeys.all, "list", filters] as const,
  detail: (code: string) => [...kycQueryKeys.all, "detail", code] as const,
};

export function useKycListFilters() {
  return useQueryStates({
    ...listSearchParams,
    status: parseAsStringLiteral(kycStatusFilterValues).withDefault("ALL"),
  });
}

export function useKycQueueQuery() {
  const [filters] = useKycListFilters();
  const params = {
    status: filters.status,
    role: "DRIVER" as const,
    q: filters.q,
    page: filters.page,
    limit: filters.limit,
  };
  return useQuery({
    queryKey: kycQueryKeys.list(params),
    queryFn: () => fetchKycQueue(params),
  });
}

export function useKycCaseQuery(code: string) {
  return useQuery({
    queryKey: kycQueryKeys.detail(code),
    queryFn: () => fetchKycByCode(code),
    enabled: Boolean(code),
  });
}

export function useApproveKycMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vehicleClassCode?: string) =>
      approveKycApplication(code, vehicleClassCode),
    onSuccess: (updated) => {
      queryClient.setQueryData(kycQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: kycQueryKeys.all });
    },
  });
}

export function useRejectKycMutation(code: string) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: string | { reason: string; issues: Array<{ section: string; note: string }> }) =>
      typeof input === "string"
        ? rejectKycApplication(code, input)
        : rejectKycApplication(code, input.reason, input.issues),
    onSuccess: (updated) => {
      queryClient.setQueryData(kycQueryKeys.detail(code), updated);
      void queryClient.invalidateQueries({ queryKey: kycQueryKeys.all });
    },
  });
}
