"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchAuthMethods, patchAuthMethod } from "@/features/auth-methods/api";
import type { AuthMethod } from "@/features/auth-methods/types";

export const authMethodQueryKeys = {
  all: ["auth-methods"] as const,
  list: () => [...authMethodQueryKeys.all, "list"] as const,
};

export function useAuthMethodsQuery() {
  return useQuery({
    queryKey: authMethodQueryKeys.list(),
    queryFn: fetchAuthMethods,
  });
}

export function usePatchAuthMethodMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      method: AuthMethod;
      enabled: boolean;
      reason: string;
    }) =>
      patchAuthMethod(input.method, {
        enabled: input.enabled,
        reason: input.reason,
      }),
    onSuccess: (updated) => {
      queryClient.setQueryData(
        authMethodQueryKeys.list(),
        (
          previous: Awaited<ReturnType<typeof fetchAuthMethods>> | undefined,
        ) => {
          if (!previous) {
            return [updated];
          }
          return previous.map((row) =>
            row.method === updated.method ? updated : row,
          );
        },
      );
    },
  });
}
