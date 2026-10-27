import Link from "next/link";
import { BrandMark } from "@/components/layout/brand-mark";
import { OpsIcon } from "@/components/ui/ops-icons";
import type { PublicPageLocale } from "../types";

/** Shared header for /terms, /privacy, /support: brand, vi/en switch, support link. */
export function PublicPageHeader({
  path,
  locale,
  showSupportLink = true,
}: {
  path: string;
  locale: PublicPageLocale;
  showSupportLink?: boolean;
}) {
  const other: PublicPageLocale = locale === "en" ? "vi" : "en";
  return (
    <header className="sticky top-0 z-30 border-b border-border bg-white/90 backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link href="/" className="flex items-center gap-2">
          <BrandMark />
        </Link>
        <div className="flex items-center gap-3">
          <Link
            href={other === "en" ? `${path}?lang=en` : path}
            hrefLang={other}
            className="inline-flex h-9 items-center rounded-lg border border-border px-3 text-xs font-semibold text-ink hover:bg-canvas"
          >
            {other === "en" ? "EN" : "VI"}
          </Link>
          {showSupportLink ? (
            <Link
              href={locale === "en" ? "/support?lang=en" : "/support"}
              className="inline-flex h-9 items-center gap-1.5 rounded-lg border border-border px-3 text-xs font-medium text-ink hover:bg-canvas"
            >
              <OpsIcon name="headset" className="size-3.5 text-muted" />
              {locale === "en" ? "Support" : "Hỗ trợ"}
            </Link>
          ) : null}
        </div>
      </div>
    </header>
  );
}
