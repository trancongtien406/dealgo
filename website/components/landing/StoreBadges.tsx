import type { PublicSiteConfig } from "@/features/site-config/types";

const APPLE = "M16.37 12.6c-.02-2.3 1.88-3.4 1.96-3.46-1.07-1.56-2.73-1.78-3.32-1.8-1.41-.14-2.76.83-3.48.83-.72 0-1.82-.81-3-.79-1.54.02-2.97.9-3.76 2.28-1.6 2.78-.41 6.9 1.15 9.16.76 1.1 1.67 2.34 2.86 2.3 1.15-.05 1.58-.74 2.97-.74 1.38 0 1.77.74 2.98.72 1.23-.02 2.01-1.12 2.76-2.23.87-1.28 1.23-2.52 1.25-2.58-.03-.01-2.4-.92-2.42-3.65zM14.1 5.85c.63-.77 1.06-1.83.94-2.89-.91.04-2.01.61-2.66 1.37-.58.67-1.09 1.76-.96 2.8 1.02.08 2.05-.52 2.68-1.28z";
const PLAY = "M3.6 2.3c-.2.2-.3.6-.3 1v17.4c0 .4.1.8.3 1l9.7-9.7L3.6 2.3zm10.6 10.6 2.7 2.7-11 6.3 8.3-9zm3.9-3.9 2.9 1.7c.8.5.8 1.3 0 1.8l-2.9 1.7-3-3 3-2.2zM5.9 1.8l11 6.3-2.7 2.7-8.3-9z";

/** Store badges only for links the admin has set. Returns the fallback text when none are set. */
export default function StoreBadges({ config, tone = "light" }: { config: PublicSiteConfig; tone?: "light" | "dark" }) {
  const items = [
    config.appStoreUrl ? { href: config.appStoreUrl, label: "App Store", sub: "Tải trên", path: APPLE } : null,
    config.googlePlayUrl ? { href: config.googlePlayUrl, label: "Google Play", sub: "Tải trên", path: PLAY } : null,
  ].filter((x): x is NonNullable<typeof x> => x !== null);
  if (items.length === 0) {
    return (
      <p className={tone === "dark" ? "pt-2 text-sm font-semibold text-white/95" : "pt-1 text-xs text-gray-600 font-medium"}>
        Ứng dụng sắp có trên App Store và Google Play
      </p>
    );
  }
  return (
    <div className="flex flex-wrap gap-2.5 pt-1">
      {items.map((it) => (
        <a
          key={it.label}
          href={it.href}
          target="_blank"
          rel="noopener noreferrer"
          aria-label={`${it.sub} ${it.label}`}
          className="inline-flex items-center gap-2 rounded-xl bg-[#0F172A] px-3.5 py-2 text-white shadow-sm hover:bg-black transition-colors"
        >
          <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d={it.path} />
          </svg>
          <span className="leading-tight text-left">
            <span className="block text-[9px] opacity-80">{it.sub}</span>
            <span className="block text-sm font-semibold">{it.label}</span>
          </span>
        </a>
      ))}
    </div>
  );
}
