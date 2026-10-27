"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchMapsProviders,
  setMapsProvider,
} from "@/features/maps-providers/api";
import type { MapsProviderChoice } from "@/features/maps-providers/types";

export const mapsProvidersQueryKeys = {
  all: ["maps-providers"] as const,
};

export function useMapsProvidersQuery() {
  return useQuery({
    queryKey: mapsProvidersQueryKeys.all,
    queryFn: fetchMapsProviders,
  });
}

export function useSetMapsProviderMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: {
      key: string;
      value: MapsProviderChoice;
      reason: string;
    }) => setMapsProvider(input.key, { value: input.value, reason: input.reason }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: mapsProvidersQueryKeys.all }),
  });
}
