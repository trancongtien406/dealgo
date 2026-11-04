import type { PublicSiteConfig, SocialKey } from "@/features/site-config/types";

type SocialVisual = {
  label: string;
  /** Tailwind classes for the round button background. */
  className: string;
  icon: React.ReactNode;
};

const ICONS: Record<SocialKey, SocialVisual> = {
  facebook: {
    label: "Facebook",
    className: "bg-[#1877F2] hover:bg-[#116FE0]",
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor" className="size-5" aria-hidden="true">
        <path d="M22 12a10 10 0 1 0-11.56 9.88v-6.99H7.9V12h2.54V9.8c0-2.5 1.49-3.89 3.77-3.89 1.09 0 2.24.2 2.24.2v2.46h-1.26c-1.24 0-1.63.77-1.63 1.56V12h2.78l-.44 2.89h-2.34v6.99A10 10 0 0 0 22 12z" />
      </svg>
    ),
  },
  messenger: {
    label: "Messenger",
    className: "bg-[#0084FF] hover:bg-[#0072DB]",
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor" className="size-5" aria-hidden="true">
        <path d="M12 2C6.2 2 2 6.15 2 11.7c0 2.87 1.2 5.4 3.2 7.13V22l2.98-1.64c.9.25 1.86.38 2.82.38 5.8 0 10-4.15 10-9.7S17.8 2 12 2zm1.1 12.6-2.55-2.72-4.98 2.72 5.48-5.82 2.6 2.72 4.93-2.72-5.48 5.82z" />
      </svg>
    ),
  },
  zalo: {
    label: "Zalo",
    className: "bg-[#0068FF] hover:bg-[#0059DA]",
    icon: (
      <span aria-hidden="true" className="text-[15px] font-black leading-none">
        Z
      </span>
    ),
  },
  tiktok: {
    label: "TikTok",
    className: "bg-[#010101] hover:bg-[#1F1F1F]",
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor" className="size-5" aria-hidden="true">
        <path d="M16.5 3c.3 2.1 1.6 3.6 3.5 3.9v2.6c-1.3 0-2.6-.4-3.7-1.2v5.9c0 3.2-2.6 5.8-5.8 5.8S4.7 17.4 4.7 14.2c0-3.1 2.4-5.6 5.5-5.8v2.7c-1.6.2-2.8 1.5-2.8 3.1 0 1.7 1.4 3.1 3.1 3.1s3.1-1.4 3.1-3.1V3h2.9z" />
      </svg>
    ),
  },
  youtube: {
    label: "YouTube",
    className: "bg-[#FF0000] hover:bg-[#E00000]",
    icon: (
      <svg viewBox="0 0 24 24" fill="currentColor" className="size-5" aria-hidden="true">
        <path d="M21.6 7.2a2.5 2.5 0 0 0-1.76-1.77C18.25 5 12 5 12 5s-6.25 0-7.84.43A2.5 2.5 0 0 0 2.4 7.2 26 26 0 0 0 2 12a26 26 0 0 0 .4 4.8 2.5 2.5 0 0 0 1.76 1.77C5.75 19 12 19 12 19s6.25 0 7.84-.43a2.5 2.5 0 0 0 1.76-1.77A26 26 0 0 0 22 12a26 26 0 0 0-.4-4.8zM10 15V9l5.2 3-5.2 3z" />
      </svg>
    ),
  },
  instagram: {
    label: "Instagram",
    className: "bg-gradient-to-br from-[#F58529] via-[#DD2A7B] to-[#8134AF] hover:opacity-90",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="size-5" aria-hidden="true">
        <rect x="3" y="3" width="18" height="18" rx="5" />
        <circle cx="12" cy="12" r="3.6" />
        <circle cx="17.2" cy="6.8" r="1" fill="currentColor" stroke="none" />
      </svg>
    ),
  },
};

const ORDER: SocialKey[] = ["facebook", "messenger", "zalo", "tiktok", "youtube", "instagram"];

/**
 * Floating social links pinned to the lower-right edge. Only renders the
 * networks the admin filled in under Admin → Cài đặt → Website & MXH.
 */
export default function SocialFloat({ siteConfig = {} }: { siteConfig?: PublicSiteConfig }) {
  const links = ORDER.flatMap((key) => {
    const href = siteConfig.socials?.[key];
    return href ? [{ key, href, ...ICONS[key] }] : [];
  });
  if (links.length === 0) return null;
  return (
    <div
      className="fixed right-3 bottom-16 z-40 print:hidden sm:right-5 sm:bottom-20"
    >
      <details className="group relative">
        <summary
          className="social-float-trigger flex size-12 cursor-pointer list-none items-center justify-center rounded-full bg-[#6c35de] text-white shadow-[0_10px_30px_rgba(108,53,222,0.35)] ring-4 ring-white/80 transition-transform duration-200 hover:scale-105 active:scale-95 sm:size-14"
          aria-label="Mở các kênh chính thức của DealGo"
          title="Kênh chính thức của DealGo"
        >
          <span className="social-float-trigger-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} className="size-6 sm:size-7">
              <circle cx="18" cy="5" r="2.5" />
              <circle cx="6" cy="12" r="2.5" />
              <circle cx="18" cy="19" r="2.5" />
              <path d="m8.2 11 7.6-4.5M8.2 13l7.6 4.5" />
            </svg>
          </span>
        </summary>

        <div className="social-float-panel absolute right-0 bottom-full mb-3 flex flex-col items-end gap-2" aria-label="Kênh chính thức của DealGo">
          {links.map((link, index) => (
            <a
              key={link.key}
              href={link.href}
              target="_blank"
              rel="noopener noreferrer me"
              aria-label={link.label}
              title={link.label}
              style={{ "--social-float-index": index } as React.CSSProperties}
              className={`social-float-item flex size-10 items-center justify-center rounded-full text-white shadow-lg ring-2 ring-white/70 transition-transform duration-150 hover:scale-110 active:scale-95 sm:size-11 ${link.className}`}
            >
              {link.icon}
            </a>
          ))}
        </div>
      </details>
    </div>
  );
}
