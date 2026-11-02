import type { Metadata } from "next";
import { getSupportPage } from "@/features/content-cms/fetch-public-page";
import { localeFromLang } from "@/features/content-cms/types";
import { getPublicSiteConfig } from "@/features/site-config/fetch-public";
import { SupportClient } from "./support-client";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({
  searchParams,
}: Props): Promise<Metadata> {
  const page = await getSupportPage(localeFromLang((await searchParams).lang));
  return {
    title: page.title,
    description: page.summary ?? undefined,
    robots: { index: true, follow: true },
    alternates: {
      canonical: "/support",
      languages: { vi: "/support", en: "/support?lang=en" },
    },
    openGraph: {
      title: page.title,
      url: "/support",
      siteName: "DealGo",
      locale: "vi_VN",
    },
  };
}

export default async function SupportPage({ searchParams }: Props) {
  const locale = localeFromLang((await searchParams).lang);
  const [page, siteConfig] = await Promise.all([getSupportPage(locale), getPublicSiteConfig()]);
  return <SupportClient page={page} messengerUrl={siteConfig.socials?.messenger} />;
}
