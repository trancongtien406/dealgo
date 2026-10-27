import { NextResponse } from "next/server";
import { HOME_BANNER_ID_RE } from "@/lib/api/ops-home-banner-body";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";

type RouteContext = { params: Promise<{ id: string; file: string }> };

const IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);

/** Same-origin proxy for banner previews in the admin (Nest serves the bytes). */
export async function GET(_request: Request, context: RouteContext) {
  const { id, file } = await context.params;
  if (
    !HOME_BANNER_ID_RE.test(id) ||
    !/^[0-9a-f-]{36}\.(jpg|png|webp)$/i.test(file)
  ) {
    return new NextResponse(null, { status: 404 });
  }
  const base = nestApiBaseUrl();
  if (!base) {
    return new NextResponse(null, { status: 500 });
  }
  const upstream = await fetch(
    `${base}/v1/public/home-banners/images/${id}/${encodeURIComponent(file)}`,
    { cache: "no-store", redirect: "error" },
  );
  if (!upstream.ok || !upstream.body) {
    return new NextResponse(null, {
      status: upstream.ok ? 502 : upstream.status,
    });
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
