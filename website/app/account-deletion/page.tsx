import type { Metadata } from "next";
import { accountDeletionCopy } from "@/features/account-deletion/copy";
import { localeFromLang } from "@/features/content-cms/types";
import { shownContact } from "@/features/content-cms/public-documents";
import { getPublicSiteConfig } from "@/features/site-config/fetch-public";
import { buildPageMetadata } from "@/lib/seo/site";
import { AccountDeletionClient } from "./account-deletion-client";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({
  searchParams,
}: Props): Promise<Metadata> {
  const locale = localeFromLang((await searchParams).lang);
  const copy = accountDeletionCopy(locale);
  return buildPageMetadata({
    title: copy.metaTitle,
    description: copy.metaDescription,
    path: "/account-deletion",
    locale,
  });
}

/**
 * Google Play account-deletion URL. Public, no sign-in, works without the app.
 * Requests become support tickets (Admin → Hỗ trợ) via `/api/public/support`.
 */
export default async function AccountDeletionPage({ searchParams }: Props) {
  const locale = localeFromLang((await searchParams).lang);
  const siteConfig = await getPublicSiteConfig();
  return (
    <AccountDeletionClient
      locale={locale}
      contactEmail={shownContact(siteConfig.contactEmail ?? "") ?? undefined}
      hotline={shownContact(siteConfig.hotline ?? "") ?? undefined}
    />
  );
}
