import Link from "next/link";
import { OpsIcon } from "@/components/ui/ops-icons";
import { formatOpsDate } from "@/lib/ops-time";
import type { LegalContent, PublicPageView } from "../types";
import { PublicPageHeader } from "./public-page-header";

const COPY = {
  vi: { effective: "Hiệu lực từ", version: "Phiên bản", terms: "Điều khoản sử dụng", privacy: "Chính sách quyền riêng tư" },
  en: { effective: "Effective", version: "Version", terms: "Terms of use", privacy: "Privacy policy" },
} as const;

/** Server-rendered legal document from the CMS (DEC-PROD-055). */
export function LegalPageView({ page }: { page: PublicPageView<LegalContent> }) {
  const t = COPY[page.locale];
  const other = page.slug === "privacy" ? "terms" : "privacy";
  const q = page.locale === "en" ? "?lang=en" : "";
  const meta = [
    page.effectiveAt ? `${t.effective} ${formatOpsDate(page.effectiveAt)}` : null,
    page.version > 0 ? `${t.version} ${page.version}` : null,
  ].filter(Boolean);
  return (
    <div className="min-h-screen bg-canvas text-ink" lang={page.locale}>
      <PublicPageHeader path={`/${page.slug}`} locale={page.locale} />
      <main className="mx-auto max-w-4xl px-4 py-10 sm:px-6 sm:py-16">
        <div className="border-b border-border pb-8">
          {page.content.badge ? (
            <div className="inline-flex items-center gap-2 rounded-full bg-success/10 px-3 py-1 text-xs font-medium text-success">
              <OpsIcon name="shield" className="size-3.5" />
              {page.content.badge}
            </div>
          ) : null}
          <h1 className="mt-4 text-3xl font-extrabold tracking-tight text-ink sm:text-4xl">{page.title}</h1>
          {meta.length > 0 ? <p className="mt-2 text-sm text-muted">{meta.join(" · ")}</p> : null}
          {page.summary ? (
            <p className="mt-3 rounded-xl border border-border bg-white p-3 text-sm text-muted">{page.summary}</p>
          ) : null}
        </div>
        <article className="mt-8 space-y-8 text-sm leading-relaxed text-ink/90">
          {page.content.sections.map((sec) => (
            <section key={sec.id} id={sec.id} className="space-y-3">
              <h2 className="text-lg font-bold text-ink">{sec.title}</h2>
              <div className="whitespace-pre-line rounded-xl border border-border/60 bg-white/50 p-4 text-sm leading-relaxed text-ink/80">
                {sec.content}
              </div>
            </section>
          ))}
        </article>
        <div className="mt-12 flex flex-wrap items-center justify-between gap-4 border-t border-border pt-6 text-xs">
          <Link href={`/${other}${q}`} className="font-medium text-brand hover:underline">
            {t[other]} →
          </Link>
        </div>
      </main>
    </div>
  );
}
