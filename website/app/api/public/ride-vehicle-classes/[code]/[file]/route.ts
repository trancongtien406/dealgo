import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

type RouteContext = { params: Promise<{ code: string; file: string }> };

const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

export async function GET(_request: Request, context: RouteContext) {
  const { code, file } = await context.params;
  if (
    !/^[A-Za-z0-9_]{1,32}$/.test(code) ||
    !/^[0-9a-f-]{36}\.(jpg|png|webp)$/i.test(file)
  ) {
    return new NextResponse(null, { status: 404 });
  }
  const base = nestApiBaseUrl();
  if (!base) {
    return new NextResponse(null, { status: 500 });
  }
  const upstream = await fetch(
    `${base}/v1/public/ride-vehicle-classes/${encodeURIComponent(code.toUpperCase())}/${encodeURIComponent(file)}`,
    { cache: "no-store", redirect: "error" },
  );
  if (!upstream.ok || !upstream.body) {
    return new NextResponse(null, { status: upstream.ok ? 502 : upstream.status });
  }
  const contentType = (upstream.headers.get("content-type") ?? "")
    .split(";")[0]!
    .trim()
    .toLowerCase();
  if (!IMAGE_TYPES.has(contentType)) {
    return new NextResponse(null, { status: 502 });
  }
  return new NextResponse(upstream.body, {
    headers: {
      "Content-Type": contentType,
      "Cache-Control": "public, max-age=86400, immutable",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
