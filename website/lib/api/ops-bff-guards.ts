import { NextResponse } from "next/server";
import { publicRequestOrigin } from "@/lib/api/public-origin";

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}

/** Cookie-auth mutations: require same-origin Origin or Referer. */
export function assertSameOriginMutation(
  request: Request,
): NextResponse | null {
  if (sameOriginMutation(request)) {
    return null;
  }
  return NextResponse.json(
    { success: false, message: "Yêu cầu không hợp lệ." },
    { status: 403 },
  );
}

function sameOriginMutation(request: Request): boolean {
  const requestHost = safeHost(publicRequestOrigin(request));
  if (!requestHost) {
    return false;
  }
  const origin = request.headers.get("origin");
  if (origin) {
    return safeHost(origin) === requestHost;
  }
  const referer = request.headers.get("referer");
  if (!referer) {
    return false;
  }
  return safeHost(referer) === requestHost;
}

function safeHost(value: string): string | null {
  try {
    return new URL(value).host;
  } catch {
    return null;
  }
}
