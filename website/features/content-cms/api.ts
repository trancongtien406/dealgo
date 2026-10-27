import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import type {
  OpsPublicPageView,
  PublicPageDraft,
  PublicPageLocale,
  PublicPageRevision,
  PublicPageSlug,
} from "./types";

type Envelope<T> = { success: boolean; data: T };

/** DEC-PROD-055 ops CMS for /terms, /privacy, /support (draft → publish with reason). */
export async function fetchOpsPublicPage(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
): Promise<OpsPublicPageView> {
  const res = await apiFetch<Envelope<OpsPublicPageView>>(apiPaths.opsPublicPage(slug, locale));
  return res.data;
}

export async function savePublicPageDraft(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
  draft: PublicPageDraft,
): Promise<OpsPublicPageView> {
  const res = await apiFetch<Envelope<OpsPublicPageView>>(apiPaths.opsPublicPage(slug, locale), {
    method: "PUT",
    body: draft,
  });
  return res.data;
}

export async function publishPublicPage(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
  reason: string,
): Promise<OpsPublicPageView> {
  const res = await apiFetch<Envelope<OpsPublicPageView>>(
    `${apiPaths.opsPublicPage(slug, locale)}/publish`,
    { method: "POST", body: { reason } },
  );
  return res.data;
}

export async function resetPublicPage(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
): Promise<OpsPublicPageView> {
  const res = await apiFetch<Envelope<OpsPublicPageView>>(
    `${apiPaths.opsPublicPage(slug, locale)}/reset`,
    { method: "POST" },
  );
  return res.data;
}

export async function fetchPublicPageRevisions(
  slug: PublicPageSlug,
  locale: PublicPageLocale,
): Promise<PublicPageRevision[]> {
  const res = await apiFetch<Envelope<PublicPageRevision[]>>(
    `${apiPaths.opsPublicPage(slug, locale)}/revisions`,
  );
  return res.data ?? [];
}
