"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchPlatformSettings,
  patchPlatformSetting,
} from "@/features/platform-settings/api";

import type { PlatformSettingsFilterParams } from "@/features/platform-settings/types";

export const platformSettingsQueryKey = (
  filters?: PlatformSettingsFilterParams,
) =>
  filters
    ? (["ops", "platform-settings", filters] as const)
    : (["ops", "platform-settings"] as const);

export function usePlatformSettingsQuery(
  filters?: PlatformSettingsFilterParams,
) {
  return useQuery({
    queryKey: platformSettingsQueryKey(filters),
    queryFn: () => fetchPlatformSettings(filters),
  });
}

export function usePatchPlatformSettingMutation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (input: { key: string; value: string; reason: string }) =>
      patchPlatformSetting(input.key, {
        value: input.value,
        reason: input.reason,
      }),
    onSuccess: () => {
      void queryClient.invalidateQueries({
        queryKey: platformSettingsQueryKey(),
      });
    },
  });
}
