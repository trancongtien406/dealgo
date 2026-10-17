"use client";

import { useQuery } from "@tanstack/react-query";
import {
  fetchDisputeByCode,
  fetchDisputes,
  type FetchDisputesParams,
} from "@/features/disputes/api";

export const disputesQueryKeys = {
  all: ["disputes"] as const,
  list: (params: FetchDisputesParams) => ["disputes", "list", params] as const,
  detail: (code: string) => ["disputes", "detail", code] as const,
};

export function useDisputesQuery(params: FetchDisputesParams) {
  return useQuery({
    queryKey: disputesQueryKeys.list(params),
    queryFn: () => fetchDisputes(params),
  });
}

export function useDisputeDetailQuery(code: string) {
  return useQuery({
    queryKey: disputesQueryKeys.detail(code),
    queryFn: () => fetchDisputeByCode(code),
    enabled: Boolean(code),
  });
}
