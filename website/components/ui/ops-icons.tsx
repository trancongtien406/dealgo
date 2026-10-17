import type { ReactNode } from "react";

export type OpsIconName =
  | "overview"
  | "monitor"
  | "car"
  | "motorcycle"
  | "gavel"
  | "utensils"
  | "package"
  | "users"
  | "driver"
  | "store"
  | "wallet"
  | "gift"
  | "categories"
  | "bell"
  | "chart"
  | "pin"
  | "staff"
  | "settings"
  | "search"
  | "user"
  | "lock"
  | "eye"
  | "eyeOff"
  | "calendar"
  | "chevron"
  | "arrowRight"
  | "trend"
  | "trendDown"
  | "clock"
  | "play"
  | "check"
  | "close"
  | "refresh"
  | "download"
  | "plus"
  | "more"
  | "alert"
  | "sliders"
  | "undo"
  | "shield"
  | "headset"
  | "star"
  | "receipt"
  | "menu"
  | "sun"
  | "moon"
  | "phone"
  | "mail";

const glyphs: Record<OpsIconName, () => ReactNode> = {
  overview: () => (
    <>
      <rect x="3.5" y="3.5" width="7" height="7" rx="1.5" />
      <rect x="13.5" y="3.5" width="7" height="7" rx="1.5" />
      <rect x="3.5" y="13.5" width="7" height="7" rx="1.5" />
      <rect x="13.5" y="13.5" width="7" height="7" rx="1.5" />
    </>
  ),
  monitor: () => (
    <>
      <rect x="3" y="4" width="18" height="12" rx="2" />
      <path d="M8 20h8" />
      <path d="M12 16v4" />
    </>
  ),
  car: () => (
    <>
      <path d="M4 14l1.6-4.2A2 2 0 0 1 7.5 8h9a2 2 0 0 1 1.9 1.8L20 14" />
      <path d="M4 14h16v3.5a1 1 0 0 1-1 1h-1.2" />
      <path d="M6.2 18.5H5a1 1 0 0 1-1-1V14" />
      <circle cx="7.5" cy="17.5" r="1.6" />
      <circle cx="16.5" cy="17.5" r="1.6" />
    </>
  ),
  motorcycle: () => (
    <>
      <circle cx="5" cy="16" r="3" />
      <circle cx="19" cy="16" r="3" />
      <path d="M12 16h2l2.5-5H13l-2.5 5" />
      <path d="M8 16l3-8h3" />
      <circle cx="13" cy="5" r="1" />
    </>
  ),
  gavel: () => (
    <>
      <path d="M14 5l5 5" />
      <path d="m12.5 6.5 5 5" />
      <path d="M9 10l5 5" />
      <path d="M4 20l7.2-7.2" />
      <path d="M3 21h8" />
    </>
  ),
  utensils: () => (
    <>
      <path d="M6 3v7a2 2 0 0 0 4 0V3" />
      <path d="M8 12v9" />
      <path d="M16 3v18" />
      <path d="M16 8h2.5a2 2 0 0 0 0-4H16" />
    </>
  ),
  package: () => (
    <>
      <path d="M12 3.5 20.5 8v8L12 20.5 3.5 16V8L12 3.5Z" />
      <path d="M12 12.5 20.5 8" />
      <path d="M12 12.5 3.5 8" />
      <path d="M12 12.5V20.5" />
    </>
  ),
  users: () => (
    <>
      <circle cx="9" cy="8" r="3" />
      <path d="M3.5 19c.6-2.8 2.8-4.5 5.5-4.5s4.9 1.7 5.5 4.5" />
      <circle cx="17" cy="9" r="2.2" />
      <path d="M16 14.6c1.8.3 3.2 1.5 3.8 3.4" />
    </>
  ),
  driver: () => (
    <>
      <circle cx="12" cy="8" r="3" />
      <path d="M5.5 19c.8-3 3-4.8 6.5-4.8s5.7 1.8 6.5 4.8" />
      <circle cx="12" cy="12" r="9" />
    </>
  ),
  store: () => (
    <>
      <path d="M4 10 5.2 5.5h13.6L20 10" />
      <path d="M4 10h16v8.5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V10Z" />
      <path d="M10 19.5v-5h4v5" />
    </>
  ),
  wallet: () => (
    <>
      <rect x="3" y="6.5" width="18" height="12" rx="2" />
      <path d="M3 10.5h18" />
      <circle cx="16.5" cy="14.5" r="1" />
    </>
  ),
  gift: () => (
    <>
      <rect x="3.5" y="8" width="17" height="11.5" rx="1.5" />
      <path d="M12 8v11.5" />
      <path d="M3.5 12.5h17" />
      <path d="M12 8c-1.2-2.4-4.2-2.8-5.2-.8-.6 1.2.4 2.4 2.2 2.6" />
      <path d="M12 8c1.2-2.4 4.2-2.8 5.2-.8.6 1.2-.4 2.4-2.2 2.6" />
    </>
  ),
  categories: () => (
    <>
      <rect x="4" y="4" width="6.5" height="6.5" rx="1.2" />
      <rect x="13.5" y="4" width="6.5" height="6.5" rx="1.2" />
      <rect x="4" y="13.5" width="6.5" height="6.5" rx="1.2" />
      <path d="M13.5 16.5h6.5M13.5 19.5h4" />
    </>
  ),
  bell: () => (
    <>
      <path d="M6 9.5a6 6 0 1 1 12 0c0 4.5 1.5 5.8 1.5 5.8H4.5S6 14 6 9.5Z" />
      <path d="M10 18.2a2 2 0 0 0 4 0" />
    </>
  ),
  chart: () => (
    <>
      <path d="M4 19V5" />
      <path d="M4 19h16" />
      <path d="m8 15 3.2-4 2.8 2.2L18 8" />
    </>
  ),
  pin: () => (
    <>
      <path d="M12 21s6.5-5.4 6.5-10.2a6.5 6.5 0 1 0-13 0C5.5 15.6 12 21 12 21Z" />
      <circle cx="12" cy="10.5" r="2.1" />
    </>
  ),
  staff: () => (
    <>
      <circle cx="12" cy="8" r="3" />
      <path d="M6 19c.7-2.8 2.8-4.5 6-4.5s5.3 1.7 6 4.5" />
      <path d="M18 5.5h2.5V8" />
    </>
  ),
  settings: () => (
    <>
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3.5v2.2M12 18.3V20.5M3.5 12h2.2M18.3 12h2.2M5.8 5.8l1.6 1.6M16.6 16.6l1.6 1.6M18.2 5.8l-1.6 1.6M7.4 16.6 5.8 18.2" />
    </>
  ),
  search: () => (
    <>
      <circle cx="11" cy="11" r="6" />
      <path d="m16 16 4 4" />
    </>
  ),
  user: () => (
    <>
      <circle cx="12" cy="8" r="3.2" />
      <path d="M5 19c.8-3 3-4.8 7-4.8s6.2 1.8 7 4.8" />
    </>
  ),
  lock: () => (
    <>
      <rect x="5" y="11" width="14" height="9" rx="2" />
      <path d="M8 11V8.2a4 4 0 0 1 8 0V11" />
    </>
  ),
  eye: () => (
    <>
      <path d="M2.5 12S6 6.5 12 6.5 21.5 12 21.5 12 18 17.5 12 17.5 2.5 12 2.5 12Z" />
      <circle cx="12" cy="12" r="2.4" />
    </>
  ),
  eyeOff: () => (
    <>
      <path d="M4 5.5 19 18.5" />
      <path d="M9.2 9.4A6 6 0 0 0 6 12c1.4 2.2 3.5 3.8 6 3.8 1 0 1.9-.2 2.8-.6" />
      <path d="M10.2 6.8A8.8 8.8 0 0 1 12 6.5c6 0 9.5 5.5 9.5 5.5a15 15 0 0 1-3.2 3.4" />
    </>
  ),
  calendar: () => (
    <>
      <rect x="4" y="5" width="16" height="15" rx="2" />
      <path d="M8 3.5v3M16 3.5v3M4 10h16" />
    </>
  ),
  chevron: () => <path d="m6 9 6 6 6-6" />,
  arrowRight: () => (
    <>
      <path d="M5 12h14" />
      <path d="m13 6 6 6-6 6" />
    </>
  ),
  trend: () => (
    <>
      <path d="m4 16 5-5 3 3 8-8" />
      <path d="M14 6h6v6" />
    </>
  ),
  trendDown: () => (
    <>
      <path d="m4 8 5 5 3-3 8 8" />
      <path d="M14 18h6v-6" />
    </>
  ),
  clock: () => (
    <>
      <circle cx="12" cy="12" r="8" />
      <path d="M12 8v4.5l2.5 1.5" />
    </>
  ),
  play: () => (
    <path d="M9 7.2v9.6l8.2-4.8L9 7.2Z" fill="currentColor" stroke="none" />
  ),
  check: () => <path d="m5.5 12.5 4.2 4.2L18.5 8" />,
  close: () => (
    <>
      <circle cx="12" cy="12" r="8" />
      <path d="m9 9 6 6M15 9l-6 6" />
    </>
  ),
  refresh: () => (
    <>
      <path d="M20 12a8 8 0 1 1-2.3-5.6" />
      <path d="M20 4.5V9h-4.5" />
    </>
  ),
  download: () => (
    <>
      <path d="M12 4v10" />
      <path d="m8 10 4 4 4-4" />
      <path d="M5 19h14" />
    </>
  ),
  plus: () => (
    <>
      <path d="M12 5v14" />
      <path d="M5 12h14" />
    </>
  ),
  more: () => (
    <>
      <circle cx="6" cy="12" r="1.15" fill="currentColor" stroke="none" />
      <circle cx="12" cy="12" r="1.15" fill="currentColor" stroke="none" />
      <circle cx="18" cy="12" r="1.15" fill="currentColor" stroke="none" />
    </>
  ),
  alert: () => (
    <>
      <path d="M12 4.2 20.8 19H3.2L12 4.2Z" />
      <path d="M12 10v4" />
      <path d="M12 16.6h.01" />
    </>
  ),
  sliders: () => (
    <>
      <path d="M4 8h16M4 16h16" />
      <path d="M9 6v4M15 14v4" />
    </>
  ),
  undo: () => (
    <>
      <path d="M9 8H4.5V3.5" />
      <path d="M4.8 8.2a8 8 0 1 1 1.8 6.3" />
    </>
  ),
  shield: () => (
    <path d="M12 3.5 19 6v5.5c0 4.4-3 6.8-7 8.5-4-1.7-7-4.1-7-8.5V6l7-2.5Z" />
  ),
  headset: () => (
    <>
      <path d="M4 13a8 8 0 0 1 16 0" />
      <rect x="3" y="13" width="4" height="6" rx="1.2" />
      <rect x="17" y="13" width="4" height="6" rx="1.2" />
      <path d="M19 18.5A3.5 3.5 0 0 1 15.5 21H14" />
    </>
  ),
  star: () => (
    <path
      d="m12 3.4 2.2 4.5 5 .7-3.6 3.5.9 4.9L12 14.7 7.5 17l.9-4.9L4.8 8.6l5-.7L12 3.4Z"
      fill="currentColor"
      stroke="none"
    />
  ),
  receipt: () => (
    <>
      <path d="M7 3.5h10a1 1 0 0 1 1 1V20l-2-1.2L14 20l-2-1.2L10 20l-2-1.2L6 20V4.5a1 1 0 0 1 1-1Z" />
      <path d="M9 8h6M9 12h6" />
    </>
  ),
  menu: () => (
    <>
      <path d="M4 7h16" />
      <path d="M4 12h16" />
      <path d="M4 17h16" />
    </>
  ),
  sun: () => (
    <>
      <circle cx="12" cy="12" r="4" />
      <path d="M12 2v2" />
      <path d="M12 20v2" />
      <path d="m4.93 4.93 1.41 1.41" />
      <path d="m17.66 17.66 1.41 1.41" />
      <path d="M2 12h2" />
      <path d="M20 12h2" />
      <path d="m6.34 17.66-1.41 1.41" />
      <path d="m19.07 4.93-1.41 1.41" />
    </>
  ),
  moon: () => <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />,
  phone: () => (
    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
  ),
  mail: () => (
    <>
      <rect width="20" height="16" x="2" y="4" rx="2" />
      <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
    </>
  ),
};

const HAS_SIZE_RE = /\b(size-|w-|h-)/;

export function OpsIcon({
  name,
  className = "",
}: {
  name: OpsIconName;
  className?: string;
}) {
  const glyph = glyphs[name];
  if (!glyph) return null;

  const hasSize = HAS_SIZE_RE.test(className);
  const classes = ["inline-block shrink-0", !hasSize && "size-4", className]
    .filter(Boolean)
    .join(" ");

  return (
    <svg
      viewBox="0 0 24 24"
      aria-hidden="true"
      className={classes}
      fill="none"
      stroke="currentColor"
      strokeWidth="1.75"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      {glyph()}
    </svg>
  );
}
