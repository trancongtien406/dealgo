"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  fetchOpsPublicPage,
  fetchPublicPageRevisions,
  publishPublicPage,
  resetPublicPage,
  savePublicPageDraft,
} from "./api";
import type { OpsPublicPageView, PublicPageDraft, PublicPageLocale, PublicPageSlug } from "./types";

const pageKey = (slug: PublicPageSlug, locale: PublicPageLocale) =>
  ["ops", "public-page", slug, locale] as const;
const revisionsKey = (slug: PublicPageSlug, locale: PublicPageLocale) =>
  ["ops", "public-page-revisions", slug, locale] as const;

export function useOpsPublicPageQuery(slug: PublicPageSlug, locale: PublicPageLocale) {
  return useQuery({ queryKey: pageKey(slug, locale), queryFn: () => fetchOpsPublicPage(slug, locale) });
}

export function usePublicPageRevisionsQuery(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
  enabled: boolean,
) {
  return useQuery({
    queryKey: revisionsKey(slug, locale),
    queryFn: () => fetchPublicPageRevisions(slug, locale),
    enabled,
  });
}

function useStorePage(slug: PublicPageSlug, locale: PublicPageLocale) {
  const queryClient = useQueryClient();
  return (data: OpsPublicPageView) => {
    queryClient.setQueryData(pageKey(slug, locale), data);
    void queryClient.invalidateQueries({ queryKey: revisionsKey(slug, locale) });
  };
}

export function useSavePublicPageDraftMutation(slug: PublicPageSlug, locale: PublicPageLocale) {
  const store = useStorePage(slug, locale);
  return useMutation({
    mutationFn: (draft: PublicPageDraft) => savePublicPageDraft(slug, locale, draft),
    onSuccess: store,
  });
}

export function usePublishPublicPageMutation(slug: PublicPageSlug, locale: PublicPageLocale) {
  const store = useStorePage(slug, locale);
  return useMutation({
    mutationFn: (reason: string) => publishPublicPage(slug, locale, reason),
    onSuccess: store,
  });
}

export function useResetPublicPageMutation(slug: PublicPageSlug, locale: PublicPageLocale) {
  const store = useStorePage(slug, locale);
  return useMutation({
    mutationFn: () => resetPublicPage(slug, locale),
    onSuccess: store,
  });
}
