import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import { fallbackLegalPage, fallbackSupportPage } from "./public-documents";
import type {
  LegalContent,
  LegalPageSlug,
  PublicPageLocale,
  PublicPageView,
  SupportContent,
} from "./types";

async function fetchFromApi<C>(
  slug: string,
  locale: PublicPageLocale,
): Promise<PublicPageView<C> | null> {
  const base = nestApiBaseUrl();
  if (!base) return null;
  try {
    const res = await fetch(
      `${base}/v1/public/pages/${slug}?locale=${locale}`,
      { next: { revalidate: 60 }, signal: AbortSignal.timeout(4_000) },
    );
    if (!res.ok) return null;
    const json = (await res.json().catch(() => null)) as {
      data?: PublicPageView<C>;
    } | null;
    return json?.data && typeof json.data === "object" ? json.data : null;
  } catch {
    return null;
  }
}

/** Server-side read of a published legal page (falls back offline). */
export async function getLegalPage(
  slug: LegalPageSlug,
  locale: PublicPageLocale,
): Promise<PublicPageView<LegalContent>> {
  const page = await fetchFromApi<LegalContent>(slug, locale);
  return page && Array.isArray(page.content?.sections)
    ? page
    : fallbackLegalPage(slug, locale);
}

export async function getSupportPage(
  locale: PublicPageLocale,
): Promise<PublicPageView<SupportContent>> {
  const page = await fetchFromApi<SupportContent>("support", locale);
  return page && Array.isArray(page.content?.categories)
    ? page
    : fallbackSupportPage(locale);
}
