import type { MetadataRoute } from "next";
import { siteUrl } from "@/lib/seo/site";

export default function robots(): MetadataRoute.Robots {
  const origin = siteUrl().origin;
  return {
    rules: {
      userAgent: "*",
      allow: ["/", "/support", "/terms", "/privacy", "/regulations"],
      disallow: [
        "/api/",
        "/login",
        "/chia-se-chuyen/",
        "/overview",
        "/settings",
      ],
    },
    sitemap: `${origin}/sitemap.xml`,
    host: origin,
  };
}
