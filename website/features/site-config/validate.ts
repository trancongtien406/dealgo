import { ALLOWED_HOSTS, SOCIAL_KEYS, type PublicSiteConfig } from "./types";

/** Returns an error message for a non-empty link, or null when valid/empty. */
export function linkError(kind: keyof typeof ALLOWED_HOSTS, value: string): string | null {
  const v = value.trim();
  if (!v) return null;
  let url: URL;
  try {
    url = new URL(v);
  } catch {
    return "Link không hợp lệ.";
  }
  if (url.protocol !== "https:") return "Link phải bắt đầu bằng https://";
  const hosts: readonly string[] = ALLOWED_HOSTS[kind];
  if (!hosts.includes(url.hostname.toLowerCase())) return `Chỉ chấp nhận: ${hosts.join(", ")}`;
  return null;
}

/** Sanitises a config read from anywhere before rendering: keeps only valid https links. */
export function safeSiteConfig(input: unknown): PublicSiteConfig {
  if (!input || typeof input !== "object" || Array.isArray(input)) return {};
  const raw = input as Record<string, unknown>;
  const out: PublicSiteConfig = {};
  const str = (v: unknown) => (typeof v === "string" ? v.trim() : "");
  for (const k of ["appStoreUrl", "googlePlayUrl"] as const) {
    const v = str(raw[k]);
    if (v && !linkError(k, v)) out[k] = v;
  }
  const socialsRaw = raw.socials;
  if (socialsRaw && typeof socialsRaw === "object" && !Array.isArray(socialsRaw)) {
    const socials: NonNullable<PublicSiteConfig["socials"]> = {};
    for (const k of SOCIAL_KEYS) {
      const v = str((socialsRaw as Record<string, unknown>)[k]);
      if (v && !linkError(k, v)) socials[k] = v;
    }
    if (Object.keys(socials).length > 0) out.socials = socials;
  }
  const email = str(raw.contactEmail);
  if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) out.contactEmail = email;
  const hotline = str(raw.hotline);
  if (/^\+?[0-9 .-]{6,20}$/.test(hotline)) out.hotline = hotline;
  if (Array.isArray(raw.comingSoonCities)) {
    const cities = raw.comingSoonCities.map(str).filter((c) => c.length > 0 && c.length <= 40);
    if (cities.length > 0) out.comingSoonCities = [...new Set(cities)].slice(0, 10);
  }
  return out;
}
