"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchAppVersionPolicy, patchAppVersionPolicy } from "@/features/app-version/api";

export const appVersionQueryKey = ["ops", "app-version-policy"] as const;

export function useAppVersionPolicyQuery() {
  return useQuery({ queryKey: appVersionQueryKey, queryFn: fetchAppVersionPolicy });
}

export function usePatchAppVersionPolicyMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: patchAppVersionPolicy,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: appVersionQueryKey }),
  });
}
