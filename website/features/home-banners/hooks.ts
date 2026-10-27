"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  createHomeBanner,
  deleteHomeBanner,
  fetchHomeBanners,
  patchHomeBanner,
  reorderHomeBanners,
  uploadHomeBannerImage,
} from "@/features/home-banners/api";
import type { HomeBannerPayload } from "@/features/home-banners/types";

const queryKey = ["ops", "home-banners"] as const;

export function useHomeBannersQuery() {
  return useQuery({ queryKey, queryFn: fetchHomeBanners });
}

function useInvalidate() {
  const queryClient = useQueryClient();
  return () => void queryClient.invalidateQueries({ queryKey });
}

export function useCreateHomeBannerMutation() {
  const onSuccess = useInvalidate();
  return useMutation({ mutationFn: createHomeBanner, onSuccess });
}

export function usePatchHomeBannerMutation() {
  const onSuccess = useInvalidate();
  return useMutation({
    mutationFn: (input: {
      id: string;
      patch: Partial<HomeBannerPayload> & { active?: boolean };
    }) => patchHomeBanner(input.id, input.patch),
    onSuccess,
  });
}

export function useDeleteHomeBannerMutation() {
  const onSuccess = useInvalidate();
  return useMutation({ mutationFn: deleteHomeBanner, onSuccess });
}

export function useUploadHomeBannerImageMutation() {
  const onSuccess = useInvalidate();
  return useMutation({
    mutationFn: (input: { id: string; dataUrl: string }) =>
      uploadHomeBannerImage(input.id, input.dataUrl),
    onSuccess,
  });
}

export function useReorderHomeBannersMutation() {
  const onSuccess = useInvalidate();
  return useMutation({ mutationFn: reorderHomeBanners, onSuccess });
}
