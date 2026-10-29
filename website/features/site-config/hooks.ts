"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchSiteConfig, patchSiteConfig } from "@/features/site-config/api";

export const siteConfigQueryKey = ["ops", "site-config"] as const;

export function useSiteConfigQuery() {
  return useQuery({ queryKey: siteConfigQueryKey, queryFn: fetchSiteConfig });
}

export function usePatchSiteConfigMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: patchSiteConfig,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: siteConfigQueryKey }),
  });
}
