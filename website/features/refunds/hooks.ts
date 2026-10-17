"use client";

import { useQuery } from "@tanstack/react-query";
import { fetchRefunds, type FetchRefundsParams } from "@/features/refunds/api";

export const refundsQueryKeys = {
  all: ["refunds"] as const,
  list: (filters: FetchRefundsParams) => ["refunds", "list", filters] as const,
};

export function useRefundsQuery(params: FetchRefundsParams) {
  return useQuery({
    queryKey: refundsQueryKeys.list(params),
    queryFn: () => fetchRefunds(params),
  });
}
