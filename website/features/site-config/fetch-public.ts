import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import type { PublicSiteConfig } from "./types";
import { safeSiteConfig } from "./validate";

/** Server-side read of the public site config (ISR, 60s). Any failure → {} so nothing fake renders. */
export async function getPublicSiteConfig(): Promise<PublicSiteConfig> {
  const base = nestApiBaseUrl();
  if (!base) return {};
  try {
    const res = await fetch(`${base}/v1/public/site-config`, {
      next: { revalidate: 60 },
      signal: AbortSignal.timeout(4_000),
    });
    if (!res.ok) return {};
    const json = (await res.json().catch(() => null)) as { data?: unknown } | null;
    return safeSiteConfig(json?.data);
  } catch {
    return {};
  }
}
