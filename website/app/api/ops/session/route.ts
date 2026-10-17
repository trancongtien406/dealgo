import { cookies } from "next/headers";
import { NextResponse } from "next/server";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import { assertSameOriginMutation } from "@/lib/api/ops-bff-guards";
import {
  clearOpsProbeCache,
  verifyOpsAccessToken,
} from "@/lib/api/ops-upstream";
import {
  OPS_ACCESS_COOKIE,
  OPS_REFRESH_COOKIE,
  opsSessionCookieOptions,
} from "@/lib/ops-session";

const MAX_BODY_CHARS = 8_192;
const MAX_EMAIL_CHARS = 320;
const MAX_PASSWORD_CHARS = 1_024;
const MAX_TOKEN_CHARS = 4_096;
const MAX_EXPIRES_IN_SECONDS = 60 * 60 * 24 * 30;

type OpsSessionTokens = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
};

/**
 * Verifies the current ops session via Nest probe
 * GET /v1/ops/rides?page=1&limit=1 (Nest has no GET /v1/ops/me).
 * Pure access probe — does not rotate refresh. Stale access with a refresh
 * cookie still present returns 401 without clearing cookies so the client can
 * hit `/api/ops/session/refresh`.
 */
export async function GET() {
  const jar = await cookies();
  const accessToken = jar.get(OPS_ACCESS_COOKIE)?.value;
  const refreshToken = jar.get(OPS_REFRESH_COOKIE)?.value;
  const hasAccess = typeof accessToken === "string" && accessToken.length > 0;
  const hasRefresh =
    typeof refreshToken === "string" && refreshToken.length > 0;

  if (!hasAccess) {
    return NextResponse.json(
      {
        success: false,
        message: hasRefresh
          ? "Phiên đăng nhập hết hạn. Đăng nhập lại."
          : "Chưa đăng nhập.",
      },
      { status: 401 },
    );
  }

  const verified = await verifyOpsAccessToken(accessToken);
  if (!verified.valid) {
    if (verified.status >= 500) {
      return NextResponse.json(
        {
          success: false,
          message:
            verified.message ||
            "Máy chủ tạm thời không khả dụng. Phiên được bảo lưu.",
          error: "service_unavailable",
        },
        { status: 503 },
      );
    }
    const status = verified.status === 403 ? 403 : 401;
    const response = NextResponse.json(
      { success: false, message: verified.message },
      { status },
    );
    // Keep refresh cookie when access alone failed — rotation belongs on the
    // dedicated refresh route, not a silent Nest refresh inside this probe.
    if (!hasRefresh && (status === 401 || status === 403)) {
      const cleared = opsSessionCookieOptions(0);
      response.cookies.set(OPS_ACCESS_COOKIE, "", cleared);
      response.cookies.set(OPS_REFRESH_COOKIE, "", cleared);
      clearOpsProbeCache();
    }
    return response;
  }

  return NextResponse.json({
    success: true,
    data: {
      verified: true,
      /** Probe used until Nest exposes a dedicated ops /me. */
      probe: "GET /v1/ops/rides?page=1&limit=1",
    },
  });
}

export async function POST(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const parsed = await readJsonBody(request);
  if (!parsed.ok) {
    return NextResponse.json(
      { success: false, message: parsed.message },
      { status: parsed.status },
    );
  }

  const credentials = readCredentials(parsed.value);
  if (!credentials.ok) {
    return NextResponse.json(
      { success: false, message: credentials.message },
      { status: credentials.status },
    );
  }

  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return NextResponse.json(
      { success: false, message: "Không thể đăng nhập. Thử lại." },
      { status: 500 },
    );
  }

  let upstream: Response;
  try {
    upstream = await fetch(`${baseUrl}/v1/ops/sessions`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(credentials.value),
      cache: "no-store",
      // A redirect would resend the password to a different host.
      redirect: "error",
      signal: AbortSignal.timeout(10_000),
    });
  } catch {
    return NextResponse.json(
      { success: false, message: "Không thể kết nối máy chủ. Thử lại." },
      { status: 502 },
    );
  }

  const payload: unknown = await upstream.json().catch(() => null);
  if (!upstream.ok) {
    return NextResponse.json(
      {
        success: false,
        message: publicErrorMessage(upstream.status, payload),
        errorCode: publicErrorCode(payload),
      },
      { status: upstream.status },
    );
  }

  const session = readSession(payload);
  if (!session) {
    return NextResponse.json(
      { success: false, message: "Phản hồi đăng nhập không hợp lệ." },
      { status: 502 },
    );
  }

  const response = NextResponse.json({ success: true });
  const accessOptions = opsSessionCookieOptions(session.expiresIn);
  const refreshOptions = opsSessionCookieOptions(MAX_EXPIRES_IN_SECONDS);
  response.cookies.set(OPS_ACCESS_COOKIE, session.accessToken, accessOptions);
  response.cookies.set(
    OPS_REFRESH_COOKIE,
    session.refreshToken,
    refreshOptions,
  );
  return response;
}

export async function DELETE(request: Request) {
  const csrf = assertSameOriginMutation(request);
  if (csrf) {
    return csrf;
  }

  const jar = await cookies();
  const accessToken = jar.get(OPS_ACCESS_COOKIE)?.value;
  const refreshToken = jar.get(OPS_REFRESH_COOKIE)?.value;

  const baseUrl = nestApiBaseUrl();
  if (baseUrl && (refreshToken || accessToken)) {
    try {
      await fetch(`${baseUrl}/v1/ops/sessions`, {
        method: "DELETE",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        },
        body: JSON.stringify({ refreshToken }),
        cache: "no-store",
        redirect: "error",
        signal: AbortSignal.timeout(5_000),
      });
    } catch {
      // Best-effort server-side revocation on network failure; cookie cleanup must still proceed.
    }
  }

  clearOpsProbeCache();
  const response = NextResponse.json({ success: true });
  const cleared = opsSessionCookieOptions(0);
  response.cookies.set(OPS_ACCESS_COOKIE, "", cleared);
  response.cookies.set(OPS_REFRESH_COOKIE, "", cleared);
  return response;
}

async function readJsonBody(
  request: Request,
): Promise<
  | { ok: true; value: Record<string, unknown> }
  | { ok: false; status: number; message: string }
> {
  const contentType = request.headers.get("content-type") ?? "";
  if (!contentType.toLowerCase().includes("application/json")) {
    return { ok: false, status: 415, message: "Yêu cầu không hợp lệ." };
  }

  let raw: string;
  try {
    raw = await request.text();
  } catch {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  if (raw.length > MAX_BODY_CHARS) {
    return { ok: false, status: 413, message: "Yêu cầu không hợp lệ." };
  }

  let body: unknown;
  try {
    body = JSON.parse(raw) as unknown;
  } catch {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }
  if (!isRecord(body)) {
    return { ok: false, status: 400, message: "Yêu cầu không hợp lệ." };
  }

  return { ok: true, value: body };
}

function readCredentials(
  body: Record<string, unknown>,
):
  | { ok: true; value: { email: string; password: string } }
  | { ok: false; status: number; message: string } {
  const { email, password } = body;
  if (
    typeof email !== "string" ||
    typeof password !== "string" ||
    email.trim() === "" ||
    password === "" ||
    email.length > MAX_EMAIL_CHARS ||
    password.length > MAX_PASSWORD_CHARS
  ) {
    return { ok: false, status: 400, message: "Nhập email và mật khẩu." };
  }

  return { ok: true, value: { email, password } };
}

function readSession(payload: unknown): OpsSessionTokens | null {
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

function publicErrorMessage(status: number, payload: unknown): string {
  if (status >= 500) {
    return "Không thể đăng nhập. Thử lại.";
  }
  if (isRecord(payload) && typeof payload.message === "string") {
    const message = payload.message.trim();
    if (message !== "") {
      return message.slice(0, 300);
    }
  }
  return "Đăng nhập thất bại.";
}

function publicErrorCode(payload: unknown): string | undefined {
  if (!isRecord(payload) || typeof payload.errorCode !== "string") {
    return undefined;
  }
  if (!/^[A-Z0-9_]{1,64}$/.test(payload.errorCode)) {
    return undefined;
  }
  return payload.errorCode;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
