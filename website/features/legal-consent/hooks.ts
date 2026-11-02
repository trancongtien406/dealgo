"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { fetchLegalVersions, previewLegalEmail, publishLegalVersion, sendLegalEmail } from "@/features/legal-consent/api";

export const legalVersionsQueryKey = ["ops", "legal-versions"] as const;

export function useLegalVersionsQuery() {
  return useQuery({ queryKey: legalVersionsQueryKey, queryFn: fetchLegalVersions });
}

export function usePublishLegalVersionMutation() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: publishLegalVersion, onSuccess: () => qc.invalidateQueries({ queryKey: legalVersionsQueryKey }) });
}

export function usePreviewLegalEmailMutation() {
  return useMutation({ mutationFn: previewLegalEmail });
}

export function useSendLegalEmailMutation() {
  const qc = useQueryClient();
  return useMutation({ mutationFn: sendLegalEmail, onSuccess: () => qc.invalidateQueries({ queryKey: legalVersionsQueryKey }) });
}
