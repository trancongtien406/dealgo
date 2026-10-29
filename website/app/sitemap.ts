import type { MetadataRoute } from "next";
import { PUBLIC_ROUTES, siteUrl } from "@/lib/seo/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const origin = siteUrl().origin;
  return PUBLIC_ROUTES.map((path) => ({
    url: `${origin}${path}`,
    changeFrequency: path === "/" ? "weekly" : "monthly",
    priority: path === "/" ? 1 : 0.5,
    ...(path === "/"
      ? {}
      : {
          alternates: {
            languages: {
              vi: `${origin}${path}`,
              en: `${origin}${path}?lang=en`,
            },
          },
        }),
  }));
}
