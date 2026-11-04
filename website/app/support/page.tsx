import type { Metadata } from "next";
import { getSupportPage } from "@/features/content-cms/fetch-public-page";
import { localeFromLang } from "@/features/content-cms/types";
import { getPublicSiteConfig } from "@/features/site-config/fetch-public";
import { buildPageMetadata } from "@/lib/seo/site";
import { SupportClient } from "./support-client";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({
  searchParams,
}: Props): Promise<Metadata> {
  const locale = localeFromLang((await searchParams).lang);
  const page = await getSupportPage(locale);
  return buildPageMetadata({
    title: page.title,
    description:
      page.summary ??
      "Trung tâm hỗ trợ DealGo: hướng dẫn đặt xe, đặt đồ ăn, thanh toán, huỷ chuyến và liên hệ đội ngũ chăm sóc khách hàng.",
    path: "/support",
    locale,
  });
}

export default async function SupportPage({ searchParams }: Props) {
  const locale = localeFromLang((await searchParams).lang);
  const [page, siteConfig] = await Promise.all([getSupportPage(locale), getPublicSiteConfig()]);
  return <SupportClient page={page} messengerUrl={siteConfig.socials?.messenger} />;
}
