import type { Metadata } from "next";
import { LegalPageView } from "@/features/content-cms/components/legal-page-view";
import { getLegalPage } from "@/features/content-cms/fetch-public-page";
import { localeFromLang } from "@/features/content-cms/types";
import { buildPageMetadata, SITE_DESCRIPTION } from "@/lib/seo/site";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({
  searchParams,
}: Props): Promise<Metadata> {
  const locale = localeFromLang((await searchParams).lang);
  const page = await getLegalPage("regulations", locale);
  return buildPageMetadata({
    title: page.title,
    description: page.summary ?? SITE_DESCRIPTION,
    path: "/regulations",
    locale,
  });
}

export default async function RegulationsPage({ searchParams }: Props) {
  const page = await getLegalPage(
    "regulations",
    localeFromLang((await searchParams).lang),
  );
  return <LegalPageView page={page} />;
}
