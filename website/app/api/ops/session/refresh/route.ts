import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import { clearOpsProbeCache } from "@/lib/api/ops-upstream";
import {
  OPS_ACCESS_COOKIE,
  OPS_REFRESH_COOKIE,
  opsSessionCookieOptions,
} from "@/lib/ops-cookies";
import { publicRequestOrigin } from "@/lib/api/public-origin";

const MAX_REFRESH_COOKIE_AGE = 60 * 60 * 24 * 30;
const MAX_TOKEN_CHARS = 4_096;
const MAX_EXPIRES_IN_SECONDS = 60 * 60 * 24 * 30;

/**
 * Rotates ops session cookies via Nest POST /v1/auth/sessions/refresh.
 * Supports ?next= relative redirect back into the admin app.
 */
export async function GET(request: Request) {
  return refreshSession(request);
}

export async function POST(request: Request) {
  return refreshSession(request);
}

async function refreshSession(request: Request): Promise<NextResponse> {
  const nextPath = safeRelativeNext(
    new URL(request.url).searchParams.get("next"),
  );
  const loginRedirect = () =>
    NextResponse.redirect(new URL("/login", publicRequestOrigin(request)), 303);
  const successRedirect = () =>
    NextResponse.redirect(new URL(nextPath, publicRequestOrigin(request)), 303);

  // GET is used for same-origin navigation from requireOpsSession / proxy.
  // Reject cross-site navigations that could rotate refresh via CSRF.
  if (!isSameSiteNavigation(request)) {
    return NextResponse.json(
      { success: false, message: "Yêu cầu không hợp lệ." },
      { status: 403 },
    );
  }

  const jar = await cookies();
  const refreshToken = jar.get(OPS_REFRESH_COOKIE)?.value;
  if (typeof refreshToken !== "string" || refreshToken.length === 0) {
    return clearAndRedirect(loginRedirect());
  }

  const isNav = request.method === "GET";
  const unavailableResponse = () => {
    if (isNav) {
      const safeHref = escapeHtml(nextPath);
      return new NextResponse(
        `<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Máy chủ DealGo Ops tạm thời không khả dụng</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; background: #090d16; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; padding: 1.5rem; text-align: center; }
    .card { background: #131b2e; border: 1px solid #1e293b; border-radius: 1rem; padding: 2.5rem; max-width: 28rem; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.5); }
    h1 { font-size: 1.25rem; font-weight: 700; margin-bottom: 0.75rem; color: #f59e0b; }
    p { font-size: 0.875rem; color: #94a3b8; line-height: 1.5; margin-bottom: 1.5rem; }
    a { display: inline-block; background: #2563eb; color: #fff; font-size: 0.875rem; font-weight: 500; padding: 0.625rem 1.25rem; border-radius: 0.5rem; text-decoration: none; }
    a:hover { background: #1d4ed8; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Máy chủ DealGo Ops tạm thời mất kết nối</h1>
    <p>Hệ thống không thể làm mới phiên do máy chủ backend đang bảo trì hoặc khởi động lại (502/503). <strong>Phiên đăng nhập của bạn vẫn được bảo lưu an toàn.</strong></p>
    <a href="${safeHref}">Thử tải lại trang</a>
  </div>
</body>
</html>`,
        {
          status: 503,
          headers: { "Content-Type": "text/html; charset=utf-8" },
        },
      );
    }
    return NextResponse.json(
      {
        success: false,
        message:
          "Máy chủ DealGo tạm thời không khả dụng. Phiên đăng nhập được bảo lưu an toàn.",
        error: "service_unavailable",
      },
      { status: 503 },
    );
  };

  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return unavailableResponse();
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${baseUrl}/v1/auth/sessions/refresh`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refreshToken }),
      cache: "no-store",
      redirect: "error",
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    return unavailableResponse();
  }

  if (upstream.status >= 500) {
    return unavailableResponse();
  }

  const payload: unknown = await upstream.json().catch(() => null);
  const session = readSession(payload);
  if (!upstream.ok || !session) {
    return clearAndRedirect(loginRedirect());
  }

  clearOpsProbeCache();
  const response = successRedirect();
  response.cookies.set(
    OPS_ACCESS_COOKIE,
    session.accessToken,
    opsSessionCookieOptions(session.expiresIn),
  );
  response.cookies.set(
    OPS_REFRESH_COOKIE,
    session.refreshToken,
    opsSessionCookieOptions(MAX_REFRESH_COOKIE_AGE),
  );
  return response;
}

function clearAndRedirect(response: NextResponse): NextResponse {
  const cleared = opsSessionCookieOptions(0);
  response.cookies.set(OPS_ACCESS_COOKIE, "", cleared);
  response.cookies.set(OPS_REFRESH_COOKIE, "", cleared);
  clearOpsProbeCache();
  return response;
}

/**
 * Allows top-level same-site navigations (Sec-Fetch-Site: same-origin | same-site | none).
 * When Sec-Fetch-Site is absent, require Origin/Referer to match this origin if present.
 */
function isSameSiteNavigation(request: Request): boolean {
  const site = request.headers.get("sec-fetch-site");
  if (site !== null && site !== "") {
    return site === "same-origin" || site === "same-site" || site === "none";
  }

  const requestOrigin = publicRequestOrigin(request);
  const origin = request.headers.get("origin");
  if (origin) {
    try {
      return new URL(origin).origin === requestOrigin;
    } catch {
      return false;
    }
  }
  const referer = request.headers.get("referer");
  if (referer) {
    try {
      return new URL(referer).origin === requestOrigin;
    } catch {
      return false;
    }
  }
  return true;
}

export function escapeHtml(str: string): string {
  return str
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

/** Only same-origin relative paths; blocks protocol-relative, absolute URLs, XSS characters, and control codes. */
export function safeRelativeNext(raw: string | null): string {
  if (typeof raw !== "string") {
    return "/";
  }
  const trimmed = raw.trim();
  if (
    trimmed === "" ||
    !trimmed.startsWith("/") ||
    trimmed.startsWith("//") ||
    trimmed.includes("\\") ||
    trimmed.includes("\0")
  ) {
    return "/";
  }
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed)) {
    return "/";
  }
  // Reject HTML/XSS breaking characters: quotes, angle brackets, backticks, newlines
  if (/[<>"'`\r\n]/.test(trimmed)) {
    return "/";
  }
  // Strict URL path character validation
  if (!/^\/[a-zA-Z0-9/_.\-~%!$&()*+,;=:@?#]*$/.test(trimmed)) {
    return "/";
  }
  return trimmed.length > 2_048 ? "/" : trimmed;
}

function readSession(payload: unknown): {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
} | null {
  if (
    !isRecord(payload) ||
    payload.success !== true ||
    !isRecord(payload.data)
  ) {
    return null;
  }
  const { accessToken, refreshToken, expiresIn } = payload.data;
  if (!isToken(accessToken) || !isToken(refreshToken)) {
    return null;
  }
  if (
    typeof expiresIn !== "number" ||
    !Number.isInteger(expiresIn) ||
    expiresIn <= 0 ||
    expiresIn > MAX_EXPIRES_IN_SECONDS
  ) {
    return null;
  }
  return { accessToken, refreshToken, expiresIn };
}

function isToken(value: unknown): value is string {
  return (
    typeof value === "string" &&
    value.length > 0 &&
    value.length <= MAX_TOKEN_CHARS &&
    !/[\r\n]/.test(value)
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
