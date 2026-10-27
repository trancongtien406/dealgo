import type { Metadata } from "next";
import { getSupportPage } from "@/features/content-cms/fetch-public-page";
import { localeFromLang } from "@/features/content-cms/types";
import { SupportClient } from "./support-client";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const page = await getSupportPage(localeFromLang((await searchParams).lang));
  return { title: `${page.title} | DealGo`, description: page.summary ?? undefined };
}

export default async function SupportPage({ searchParams }: Props) {
  const page = await getSupportPage(localeFromLang((await searchParams).lang));
  return <SupportClient page={page} />;
}
