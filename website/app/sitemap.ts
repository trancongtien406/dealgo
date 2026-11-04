import type { MetadataRoute } from "next";
import { BILINGUAL_ROUTES, PUBLIC_ROUTES, siteUrl } from "@/lib/seo/site";

/**
 * Only public marketing/legal pages are listed. Admin, auth and share-token
 * pages are excluded here and blocked in `robots.ts`.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  const origin = siteUrl().origin;
  const lastModified = new Date();
  return PUBLIC_ROUTES.map((path) => {
    const bilingual = BILINGUAL_ROUTES.includes(
      path as (typeof BILINGUAL_ROUTES)[number],
    );
    return {
      url: `${origin}${path}`,
      lastModified,
      changeFrequency: path === "/" ? "weekly" : "monthly",
      priority: path === "/" ? 1 : path === "/support" ? 0.8 : 0.6,
      ...(bilingual
        ? {
            alternates: {
              languages: {
                vi: `${origin}${path}`,
                en: `${origin}${path}?lang=en`,
                "x-default": `${origin}${path}`,
              },
            },
          }
        : {}),
    } satisfies MetadataRoute.Sitemap[number];
  });
}
