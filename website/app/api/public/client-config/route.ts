import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

type ClientConfig = { mapboxPublicToken: string | null };

const EMPTY: ClientConfig = { mapboxPublicToken: null };

/** Public runtime config (Mapbox public token set in Admin › Bản đồ). Empty on failure so callers use the build-time token. */
export async function GET() {
  const base = nestApiBaseUrl();
  if (!base) {
    return NextResponse.json(EMPTY);
  }
  try {
    const res = await fetch(`${base}/v1/public/client-config`, {
      next: { revalidate: 300 },
      signal: AbortSignal.timeout(4_000),
    });
    if (!res.ok) {
      return NextResponse.json(EMPTY);
    }
    const json = (await res.json()) as { data?: Partial<ClientConfig> };
    const token = json.data?.mapboxPublicToken;
    return NextResponse.json(
      { mapboxPublicToken: typeof token === "string" && token.startsWith("pk.") ? token : null },
      { headers: { "cache-control": "public, max-age=300" } },
    );
  } catch {
    return NextResponse.json(EMPTY);
  }
}
