import type { MetadataRoute } from "next";
import { PUBLIC_ROUTES, siteUrl } from "@/lib/seo/site";

/**
 * The app is mostly an internal ops console, so the rule is a whitelist:
 * block everything, then allow only the public marketing/legal pages plus the
 * static assets those pages need (images, icons, OG banner).
 *
 * If a new public page is added, add its path to `PUBLIC_ROUTES` in
 * `lib/seo/site.ts` — the allow list and the sitemap both read from there.
 */
const STATIC_ASSET_PATHS = [
  "/landing/",
  "/og/",
  "/assets/",
  "/icon.svg",
  "/apple-icon.png",
  "/dealgo-logo.svg",
  "/dealgo-icon.svg",
  "/favicon.ico",
];

export default function robots(): MetadataRoute.Robots {
  const origin = siteUrl().origin;
  const allow = PUBLIC_ROUTES.map((path) => (path === "/" ? "/$" : path));
  return {
    rules: [
      {
        userAgent: "*",
        disallow: "/",
        allow: [...allow, ...STATIC_ASSET_PATHS],
      },
    ],
    sitemap: `${origin}/sitemap.xml`,
    host: origin,
  };
}
