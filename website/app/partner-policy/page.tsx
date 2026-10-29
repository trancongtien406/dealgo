import type { Metadata } from "next";
import Link from "next/link";
import { PublicPageHeader } from "@/features/content-cms/components/public-page-header";
import { localeFromLang } from "@/features/content-cms/types";
import { PARTNER_POLICY } from "@/features/partner-policy/content";

type Props = { searchParams: Promise<{ lang?: string | string[] }> };

export async function generateMetadata({ searchParams }: Props): Promise<Metadata> {
  const locale = localeFromLang((await searchParams).lang);
  const p = PARTNER_POLICY[locale];
  return {
    title: p.title,
    description: p.summary,
    robots: { index: true, follow: true },
    alternates: {
      canonical: "/partner-policy",
      languages: { vi: "/partner-policy", en: "/partner-policy?lang=en" },
    },
    openGraph: { title: p.title, description: p.summary, url: "/partner-policy", siteName: "DealGo", locale: locale === "en" ? "en_US" : "vi_VN" },
  };
}

export default async function PartnerPolicyPage({ searchParams }: Props) {
  const locale = localeFromLang((await searchParams).lang);
  const p = PARTNER_POLICY[locale];
  const q = locale === "en" ? "?lang=en" : "";
  return (
    <div className="min-h-screen bg-canvas text-ink" lang={locale}>
      <PublicPageHeader path="/partner-policy" locale={locale} />
      <main className="mx-auto max-w-4xl px-4 py-10 sm:px-6 sm:py-16">
        <div className="border-b border-border pb-8">
          <h1 className="text-3xl font-extrabold tracking-tight text-ink sm:text-4xl">{p.title}</h1>
          <p className="mt-3 text-sm text-muted">{p.summary}</p>
          <p role="note" className="mt-4 rounded-xl border border-amber-300 bg-amber-50 p-3 text-sm text-ink">
            {p.legalNotice}
          </p>
          <nav className="mt-4 flex flex-wrap gap-2 text-xs" aria-label={locale === "en" ? "Contents" : "Mục lục"}>
            {p.sections.map((s) => (
              <a key={s.id} href={`#${s.id}`} className="rounded-full border border-border bg-white px-3 py-1 text-muted hover:text-brand">
                {s.title}
              </a>
            ))}
          </nav>
        </div>
        <article className="mt-8 space-y-8 text-sm leading-relaxed text-ink/90">
          {p.sections.map((s) => (
            <section key={s.id} id={s.id} className="scroll-mt-24 space-y-3">
              <h2 className="text-lg font-bold text-ink">{s.title}</h2>
              <ul className="list-disc space-y-2 rounded-xl border border-border/60 bg-white/50 p-4 pl-8 text-ink/80">
                {s.items.map((it) => (
                  <li key={it}>{it}</li>
                ))}
              </ul>
            </section>
          ))}
        </article>
        <div className="mt-12 flex flex-wrap gap-4 border-t border-border pt-6 text-xs">
          <Link href={`/terms${q}`} className="font-medium text-brand hover:underline">{locale === "en" ? "Terms of use" : "Điều khoản sử dụng"} →</Link>
          <Link href={`/privacy${q}`} className="font-medium text-brand hover:underline">{locale === "en" ? "Privacy policy" : "Chính sách bảo mật"} →</Link>
        </div>
      </main>
    </div>
  );
}
