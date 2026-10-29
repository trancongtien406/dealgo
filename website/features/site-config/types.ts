/** Mirrors backend PUBLIC_SITE_CONFIG (platform setting, DEC-WEB-SITE-CONFIG). Empty fields are omitted. */
export const SOCIAL_KEYS = ["facebook", "tiktok", "zalo", "youtube", "instagram"] as const;
export type SocialKey = (typeof SOCIAL_KEYS)[number];

export type PublicSiteConfig = {
  appStoreUrl?: string;
  googlePlayUrl?: string;
  socials?: Partial<Record<SocialKey, string>>;
  contactEmail?: string;
  hotline?: string;
  comingSoonCities?: string[];
};

export const SOCIAL_LABELS: Record<SocialKey, string> = {
  facebook: "Facebook",
  tiktok: "TikTok",
  zalo: "Zalo OA",
  youtube: "YouTube",
  instagram: "Instagram",
};

/** Hosts allowed per link (same list the API enforces). */
export const ALLOWED_HOSTS = {
  appStoreUrl: ["apps.apple.com"],
  googlePlayUrl: ["play.google.com"],
  facebook: ["facebook.com", "www.facebook.com", "m.facebook.com", "fb.com"],
  tiktok: ["tiktok.com", "www.tiktok.com"],
  zalo: ["zalo.me", "oa.zalo.me"],
  youtube: ["youtube.com", "www.youtube.com", "youtu.be"],
  instagram: ["instagram.com", "www.instagram.com"],
} as const;
