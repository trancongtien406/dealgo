import type { Metadata } from "next";
import { LegalPageView } from "@/features/content-cms/components/legal-page-view";
import { getLegalPage } from "@/features/content-cms/fetch-public-page";
import { localeFromLang } from "@/features/content-cms/types";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({
  searchParams,
}: Props): Promise<Metadata> {
  const page = await getLegalPage(
    "regulations",
    localeFromLang((await searchParams).lang),
  );
  return {
    title: page.title,
    description: page.summary ?? undefined,
    robots: { index: true, follow: true },
    alternates: {
      canonical: "/regulations",
      languages: { vi: "/regulations", en: "/regulations?lang=en" },
    },
    openGraph: {
      title: page.title,
      url: "/regulations",
      siteName: "DealGo",
      locale: "vi_VN",
    },
  };
}

export default async function RegulationsPage({ searchParams }: Props) {
  const page = await getLegalPage(
    "regulations",
    localeFromLang((await searchParams).lang),
  );
  return <LegalPageView page={page} />;
}
