import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

const FILES = new Set(["apple-app-site-association", "assetlinks.json"]);

/**
 * /.well-known/{apple-app-site-association,assetlinks.json} (rewritten here in next.config)
 * served from backend env so the passkey / app-link domain is configured in one place (DEC-PROD-058).
 */
export async function GET(
  _request: Request,
  { params }: { params: Promise<{ file: string }> },
) {
  const { file } = await params;
  const base = nestApiBaseUrl();
  if (!FILES.has(file) || !base) {
    return new NextResponse(null, { status: 404 });
  }
  try {
    const res = await fetch(`${base}/.well-known/${file}`, {
      next: { revalidate: 300 },
      signal: AbortSignal.timeout(4_000),
    });
    if (!res.ok) {
      return new NextResponse(null, { status: res.status === 404 ? 404 : 502 });
    }
    return new NextResponse(await res.text(), {
      status: 200,
      headers: {
        "content-type": "application/json",
        "cache-control": "public, max-age=300",
      },
    });
  } catch {
    return new NextResponse(null, { status: 502 });
  }
}
