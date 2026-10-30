import { cookies } from "next/headers";
import { nestApiBaseUrl } from "@/lib/api/nest-base-url";
import {
  OPS_ACCESS_COOKIE,
  OPS_REFRESH_COOKIE,
  opsSessionCookieOptions,
} from "@/lib/ops-cookies";

export type OpsUpstreamResult =
  | { ok: true; status: number; data: unknown; requestId?: string }
  | { ok: false; status: number; message: string; errorCode?: string };

type OpsUpstreamInit = {
  method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  body?: unknown;
  searchParams?: Record<string, string | number | undefined>;
  /** Override bearer; defaults to ops access cookie. */
  accessToken?: string;
  timeoutMs?: number;
};

const MAX_REFRESH_COOKIE_AGE = 60 * 60 * 24 * 30; // 30 days
const MAX_TOKEN_CHARS = 4_096;
const MAX_EXPIRES_IN_SECONDS = 60 * 60 * 24 * 30;

type RefreshedSession = {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
};

/**
 * In-process single-flight lock for session refresh.
 *
 * SCOPE & BOUNDARY:
 * - In-process: Coalesces concurrent 401 refresh calls from parallel SSR and client
 *   component fetches arriving at the same Node.js runtime, ensuring only a single
 *   refresh request is sent upstream to NestJS per token rotation cycle.
 * - Multi-instance / Serverless: When deployed across multiple horizontal Node.js
 *   processes or Serverless lambdas without sticky sessions, cross-process synchronization
 *   requires either:
 *     (A) Distributed mutex in shared cache (e.g. Redis SET NX PX) — marked as PROPOSAL
 *         until Redis is approved as a core dependency in ADR/Charter.
 *     (B) Backend rotation grace period (5-10s window in NestJS session rotation)
 *         allowing in-flight concurrent requests to receive the active successor.
 */
const inFlightRefreshes = new Map<string, Promise<RefreshedSession | null>>();

export async function tryRefreshSessionSingleFlight(
  baseUrl: string,
  refreshToken: string,
): Promise<RefreshedSession | null> {
  const existing = inFlightRefreshes.get(refreshToken);
  if (existing) {
    return existing;
  }
  const promise = tryRefreshSession(baseUrl, refreshToken).finally(() => {
    inFlightRefreshes.delete(refreshToken);
  });
  inFlightRefreshes.set(refreshToken, promise);
  return promise;
}

async function tryRefreshSession(
  baseUrl: string,
  refreshToken: string,
): Promise<RefreshedSession | null> {
  if (!isToken(refreshToken)) {
    return null;
  }
  try {
    const res = await fetch(`${baseUrl}/v1/auth/sessions/refresh`, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ refreshToken }),
      cache: "no-store",
      signal: AbortSignal.timeout(8_000),
    });
    if (!res.ok) {
      return null;
    }
    const payload: unknown = await res.json().catch(() => null);
    return readRefreshedSession(payload);
  } catch {
    return null;
  }
}

/**
 * Server-only Nest `/v1/ops/*` call. Forwards Bearer from HttpOnly cookie.
 * Does not expose the Nest JWT to the browser response body.
 *
 * On 401 (or missing access), attempts Nest refresh **only when** the new
 * cookies can be persisted (Route Handler / Server Action). Never retries with
 * a rotated access token that was not written to the cookie jar — Nest rotates
 * refresh on success; an unpersisted rotation causes AUTH_REFRESH_REUSED.
 */
export async function fetchOpsUpstream(
  init: OpsUpstreamInit,
): Promise<OpsUpstreamResult> {
  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return { ok: false, status: 500, message: "Cấu hình API không hợp lệ." };
  }

  const jar = await cookies();
  let token = init.accessToken;
  if (!token) {
    token = jar.get(OPS_ACCESS_COOKIE)?.value;
  }

  if (typeof token !== "string" || token.length === 0) {
    const refreshed = await refreshFromCookie(baseUrl, jar);
    if (refreshed) {
      token = refreshed.accessToken;
    }
  }

  if (typeof token !== "string" || token.length === 0) {
    return { ok: false, status: 401, message: "Chưa đăng nhập." };
  }

  const url = new URL(init.path.replace(/^\//, ""), `${baseUrl}/`);
  if (init.searchParams) {
    for (const [key, value] of Object.entries(init.searchParams)) {
      if (value === undefined || value === "") {
        continue;
      }
      url.searchParams.set(key, String(value));
    }
  }

  const headers: HeadersInit = {
    Accept: "application/json",
    Authorization: `Bearer ${token}`,
  };
  let body: string | undefined;
  if (init.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(init.body);
  }

  let upstream: Response;
  try {
    upstream = await fetch(url, {
      method: init.method ?? "GET",
      headers,
      body,
      cache: "no-store",
      redirect: "error",
      signal: AbortSignal.timeout(init.timeoutMs ?? 10_000),
    });
  } catch {
    return {
      ok: false,
      status: 502,
      message: "Không thể kết nối máy chủ. Thử lại.",
    };
  }

  if (upstream.status === 401) {
    const refreshed = await refreshFromCookie(baseUrl, jar);
    if (refreshed) {
      try {
        const retryRes = await fetch(url, {
          method: init.method ?? "GET",
          headers: {
            ...headers,
            Authorization: `Bearer ${refreshed.accessToken}`,
          },
          body,
          cache: "no-store",
          redirect: "error",
          signal: AbortSignal.timeout(init.timeoutMs ?? 10_000),
        });
        const retryPayload: unknown = await retryRes.json().catch(() => null);
        if (
          retryRes.ok &&
          isRecord(retryPayload) &&
          retryPayload.success === true
        ) {
          return {
            ok: true,
            status: retryRes.status,
            data: retryPayload.data,
            requestId:
              typeof retryPayload.requestId === "string"
                ? retryPayload.requestId
                : undefined,
          };
        }
      } catch {
        // Fall through to original 401 mapping.
      }
    }
  }

  const payload: unknown = await upstream.json().catch(() => null);
  if (!upstream.ok) {
    return {
      ok: false,
      status: upstream.status,
      message: publicUpstreamMessage(upstream.status, payload),
      errorCode: publicErrorCode(payload),
    };
  }

  if (!isRecord(payload) || payload.success !== true) {
    return {
      ok: false,
      status: 502,
      message: "Phản hồi máy chủ không hợp lệ.",
    };
  }

  return {
    ok: true,
    status: upstream.status,
    data: payload.data,
    requestId:
      typeof payload.requestId === "string" ? payload.requestId : undefined,
  };
}

/**
 * Short TTL for successful ops session probes (default 15s, clamp 5–30s).
 * Avoids hitting Nest on every AdminPrivatePage navigation while keeping
 * logout/expiry discovery reasonably fresh. Failed probes are not cached.
 *
 * Override: OPS_SESSION_PROBE_TTL_MS (milliseconds).
 */
export const OPS_SESSION_PROBE_TTL_MS = resolveProbeTtlMs();

type ProbeOk = { valid: true; expiresAt: number };
const successfulProbeCache = new Map<string, ProbeOk>();

/** Clears successful probe cache after access/refresh rotation or logout. */
export function clearOpsProbeCache(): void {
  successfulProbeCache.clear();
}

/**
 * Pure access-token probe — never rotates refresh.
 * Nest has no GET /v1/ops/me; a successful authenticated list call proves the
 * access token is valid. Callers that need rotation must use
 * `/api/ops/session/refresh` (or fetchOpsUpstream in a writable cookie context).
 */
export async function verifyOpsAccessToken(
  accessToken: string,
): Promise<
  { valid: true } | { valid: false; status: number; message: string }
> {
  if (typeof accessToken !== "string" || accessToken.length === 0) {
    return { valid: false, status: 401, message: "Chưa đăng nhập." };
  }

  const cacheKey = probeCacheKey(accessToken);
  const cached = successfulProbeCache.get(cacheKey);
  const now = performance.now();
  if (cached && cached.expiresAt > now) {
    return { valid: true };
  }

  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return { valid: false, status: 500, message: "Cấu hình API không hợp lệ." };
  }

  const url = new URL("v1/ops/rides", `${baseUrl}/`);
  url.searchParams.set("page", "1");
  url.searchParams.set("limit", "1");

  let upstream: Response;
  try {
    upstream = await fetch(url, {
      method: "GET",
      headers: {
        Accept: "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      cache: "no-store",
      redirect: "error",
      signal: AbortSignal.timeout(8_000),
    });
  } catch {
    successfulProbeCache.delete(cacheKey);
    return {
      valid: false,
      status: 502,
      message: "Không thể kết nối máy chủ. Thử lại.",
    };
  }

  const payload: unknown = await upstream.json().catch(() => null);
  if (upstream.ok && isRecord(payload) && payload.success === true) {
    successfulProbeCache.set(cacheKey, {
      valid: true,
      expiresAt: performance.now() + OPS_SESSION_PROBE_TTL_MS,
    });
    return { valid: true };
  }

  successfulProbeCache.delete(cacheKey);
  return {
    valid: false,
    status: upstream.status || 401,
    message: publicUpstreamMessage(upstream.status, payload),
  };
}

/**
 * Rotates Nest session and persists cookies. Returns null when the cookie
 * store is read-only (e.g. RSC), Nest refresh fails, or Set-Cookie fails —
 * never returns tokens that were not persisted, and never calls Nest refresh
 * when cookies cannot be written (avoids AUTH_REFRESH_REUSED).
 */
async function refreshFromCookie(
  baseUrl: string,
  jar: Awaited<ReturnType<typeof cookies>>,
): Promise<RefreshedSession | null> {
  const refreshToken = jar.get(OPS_REFRESH_COOKIE)?.value;
  if (!isToken(refreshToken)) {
    return null;
  }
  if (!cookieStoreAllowsSet(jar)) {
    return null;
  }
  const refreshed = await tryRefreshSessionSingleFlight(baseUrl, refreshToken);
  if (!refreshed) {
    return null;
  }
  if (!persistRefreshedCookies(jar, refreshed)) {
    return null;
  }
  return refreshed;
}

/** True when `cookies().set` is allowed in this request context (Route Handler). */
function cookieStoreAllowsSet(
  jar: Awaited<ReturnType<typeof cookies>>,
): boolean {
  try {
    // maxAge 0 — no durable cookie; fails fast in RSC read-only stores.
    jar.set("__dealgo_cw", "", {
      path: "/",
      maxAge: 0,
      httpOnly: true,
      sameSite: "lax",
    });
    return true;
  } catch {
    return false;
  }
}

function persistRefreshedCookies(
  jar: Awaited<ReturnType<typeof cookies>>,
  refreshed: RefreshedSession,
): boolean {
  try {
    jar.set(
      OPS_ACCESS_COOKIE,
      refreshed.accessToken,
      opsSessionCookieOptions(refreshed.expiresIn),
    );
    jar.set(
      OPS_REFRESH_COOKIE,
      refreshed.refreshToken,
      opsSessionCookieOptions(MAX_REFRESH_COOKIE_AGE),
    );
    clearOpsProbeCache();
    return true;
  } catch {
    // Should be rare after cookieStoreAllowsSet — still refuse unpersisted use.
    return false;
  }
}

/** Matches `/api/ops/session/refresh` token + expiresIn validation. */
function readRefreshedSession(payload: unknown): RefreshedSession | null {
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

function resolveProbeTtlMs(): number {
  const raw = process.env.OPS_SESSION_PROBE_TTL_MS?.trim();
  if (!raw) {
    return 15_000;
  }
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return 15_000;
  }
  return Math.min(30_000, Math.max(5_000, Math.floor(parsed)));
}

function probeCacheKey(token: string): string {
  if (token.length <= 48) {
    return token;
  }
  return `${token.slice(0, 24)}…${token.slice(-16)}:${token.length}`;
}

function publicUpstreamMessage(status: number, payload: unknown): string {
  if (status === 401) {
    return "Phiên đăng nhập hết hạn. Đăng nhập lại.";
  }
  if (status === 403) {
    return "Không có quyền thao tác.";
  }
  if (status >= 500) {
    return "Máy chủ tạm thời không khả dụng. Thử lại.";
  }
  if (isRecord(payload) && typeof payload.message === "string") {
    const message = payload.message.trim();
    if (message !== "") {
      return message.slice(0, 300);
    }
  }
  return `Yêu cầu thất bại (${status}).`;
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

export type OpsBinaryResult =
  | { ok: true; body: ArrayBuffer; contentType: string; disposition: string | null }
  | { ok: false; status: number; message: string };

/** Content types the BFF will relay from upload downloads (anything else is refused). */
const RELAYED_BINARY_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
  // t54u: KYC liveness clip (SELFIE_VIDEO); without these the admin <video> got a 502.
  "video/mp4",
  "video/quicktime",
]);

/**
 * Server-only GET of a binary Nest `/v1/ops/*` resource (KYC documents, ticket
 * attachments). Uses the ops access cookie; on a missing/expired access token it
 * refreshes once like fetchOpsUpstream. The body is relayed only for upload types.
 */
export async function fetchOpsUpstreamBinary(path: string): Promise<OpsBinaryResult> {
  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return { ok: false, status: 500, message: "Cấu hình API không hợp lệ." };
  }
  const jar = await cookies();
  let token = jar.get(OPS_ACCESS_COOKIE)?.value;
  const url = new URL(path.replace(/^\//, ""), `${baseUrl}/`);
  const send = (accessToken: string) =>
    fetch(url, {
      method: "GET",
      headers: { Authorization: `Bearer ${accessToken}` },
      cache: "no-store",
      redirect: "error",
      signal: AbortSignal.timeout(20_000),
    });
  try {
    if (!token) {
      token = (await refreshFromCookie(baseUrl, jar))?.accessToken;
    }
    if (!token) {
      return { ok: false, status: 401, message: "Chưa đăng nhập." };
    }
    let upstream = await send(token);
    if (upstream.status === 401) {
      const refreshed = await refreshFromCookie(baseUrl, jar);
      if (refreshed) {
        upstream = await send(refreshed.accessToken);
      }
    }
    if (!upstream.ok) {
      const payload: unknown = await upstream.json().catch(() => null);
      return {
        ok: false,
        status: upstream.status,
        message: publicUpstreamMessage(upstream.status, payload),
      };
    }
    const contentType = (upstream.headers.get("content-type") ?? "").split(";")[0]!.trim();
    if (!RELAYED_BINARY_TYPES.has(contentType)) {
      return { ok: false, status: 502, message: "Phản hồi máy chủ không hợp lệ." };
    }
    return {
      ok: true,
      body: await upstream.arrayBuffer(),
      contentType,
      disposition: upstream.headers.get("content-disposition"),
    };
  } catch {
    return { ok: false, status: 502, message: "Không thể kết nối máy chủ. Thử lại." };
  }
}

export type OpsStreamResult =
  | { ok: true; upstream: Response }
  | { ok: false; status: number; message: string };

/**
 * Server-only long-lived GET (SSE) of a Nest `/v1/ops/*` stream. Same cookie bearer and
 * single refresh as fetchOpsUpstream, but no timeout: the stream lives until `signal`
 * aborts (browser closed the EventSource) or Nest ends it.
 */
export async function openOpsUpstreamStream(
  path: string,
  signal: AbortSignal,
): Promise<OpsStreamResult> {
  const baseUrl = nestApiBaseUrl();
  if (!baseUrl) {
    return { ok: false, status: 500, message: "Cấu hình API không hợp lệ." };
  }
  const jar = await cookies();
  const url = new URL(path.replace(/^\//, ""), `${baseUrl}/`);
  const send = (accessToken: string) =>
    fetch(url, {
      method: "GET",
      headers: {
        Accept: "text/event-stream",
        Authorization: `Bearer ${accessToken}`,
      },
      cache: "no-store",
      redirect: "error",
      signal,
    });
  try {
    let token = jar.get(OPS_ACCESS_COOKIE)?.value;
    if (!token) {
      token = (await refreshFromCookie(baseUrl, jar))?.accessToken;
    }
    if (!token) {
      return { ok: false, status: 401, message: "Chưa đăng nhập." };
    }
    let upstream = await send(token);
    if (upstream.status === 401) {
      await upstream.body?.cancel().catch(() => undefined);
      const refreshed = await refreshFromCookie(baseUrl, jar);
      if (refreshed) {
        upstream = await send(refreshed.accessToken);
      }
    }
    const contentType = upstream.headers.get("content-type") ?? "";
    if (!upstream.ok || !contentType.startsWith("text/event-stream") || !upstream.body) {
      const payload: unknown = await upstream.json().catch(() => null);
      return {
        ok: false,
        status: upstream.ok ? 502 : upstream.status,
        message: upstream.ok
          ? "Phản hồi máy chủ không hợp lệ."
          : publicUpstreamMessage(upstream.status, payload),
      };
    }
    return { ok: true, upstream };
  } catch {
    return { ok: false, status: 502, message: "Không thể kết nối máy chủ. Thử lại." };
  }
}
