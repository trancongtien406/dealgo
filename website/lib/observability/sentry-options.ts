/**
 * DEC-PROD-054: Sentry is opt-in. Without a DSN nothing is imported or sent, so
 * dev and self-hosted builds stay free of the SDK at runtime.
 */
import type { Breadcrumb, ErrorEvent, EventHint } from "@sentry/nextjs";

export type WebsiteSentryOptions = {
  dsn: string;
  environment: string;
  release?: string;
  tracesSampleRate: number;
  dataCollection: {
    userInfo: false;
    cookies: false;
    httpHeaders: false;
    httpBodies: [];
    urlQueryParams: false;
  };
  beforeSend: (event: ErrorEvent, hint?: EventHint) => ErrorEvent | null;
  beforeBreadcrumb: (crumb: Breadcrumb) => Breadcrumb;
};

export function websiteSentryOptions(
  dsn: string | undefined,
  environment: string | undefined,
  tracesSampleRate?: string,
  release?: string,
): WebsiteSentryOptions | null {
  const trimmed = dsn?.trim();
  if (!trimmed) {
    return null;
  }
  const rate = Number(tracesSampleRate ?? "0");
  return {
    dsn: trimmed,
    environment: environment?.trim() || "development",
    ...(release?.trim() ? { release: release.trim() } : {}),
    tracesSampleRate:
      Number.isFinite(rate) && rate >= 0 && rate <= 1 ? rate : 0,
    // Collect nothing personal at the source; the hooks below are the second line.
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
    },
    beforeSend: (event, hint) =>
      isExpectedClientError(hint?.originalException)
        ? null
        : scrubSentryEvent(event),
    beforeBreadcrumb: scrubBreadcrumb,
  };
}

export function serverSentryOptions(): WebsiteSentryOptions | null {
  return websiteSentryOptions(
    process.env.SENTRY_DSN || process.env.NEXT_PUBLIC_SENTRY_DSN,
    process.env.SENTRY_ENVIRONMENT ||
      process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT ||
      process.env.NODE_ENV,
    process.env.SENTRY_TRACES_SAMPLE_RATE ??
      process.env.NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE,
    process.env.NEXT_PUBLIC_SENTRY_RELEASE,
  );
}

export function clientSentryOptions(): WebsiteSentryOptions | null {
  return websiteSentryOptions(
    process.env.NEXT_PUBLIC_SENTRY_DSN,
    process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT || process.env.NODE_ENV,
    process.env.NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE,
    process.env.NEXT_PUBLIC_SENTRY_RELEASE,
  );
}

/** Report a client-side error boundary hit; no-op without NEXT_PUBLIC_SENTRY_DSN. */
export function reportClientError(error: unknown): void {
  if (!clientSentryOptions()) {
    return;
  }
  void import("@sentry/nextjs").then((Sentry) =>
    Sentry.captureException(error),
  );
}

const EMAIL = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const PHONE = /(?<![\w+])(?:\+?84|0)\d{8,10}\b/g;
const JWT = /\beyJ[\w-]+\.[\w-]+\.[\w-]+/g;
const BEARER = /\bbearer\s+[\w\-.~+/]+=*/gi;
const SECRET_PAIR =
  /\b((?:password|passwd|pwd|secret|token|otp|api_?key|authorization)["']?\s*[:=]\s*["']?)[^\s"',;&]+/gi;
const URL_QUERY = /(https?:\/\/[^\s?#]+)[?#][^\s]*/g;

/** Removes tokens, secrets, emails, phone numbers and URL queries from free text. */
export function scrubText(input: string): string {
  return input
    .replace(URL_QUERY, "$1")
    .replace(JWT, "[jwt]")
    .replace(BEARER, "bearer [redacted]")
    .replace(SECRET_PAIR, "$1[redacted]")
    .replace(EMAIL, "[email]")
    .replace(PHONE, "[phone]");
}

function stripQuery(url: string): string {
  return url.split(/[?#]/)[0] ?? url;
}

/** BFF/API errors below 500 (validation, auth, not found) are expected and never reported. */
export function isExpectedClientError(error: unknown): boolean {
  if (!error || typeof error !== "object") {
    return false;
  }
  const status =
    (error as { status?: unknown; statusCode?: unknown }).status ??
    (error as { statusCode?: unknown }).statusCode;
  return typeof status === "number" && status >= 400 && status < 500;
}

/** User id only; no headers, cookies, bodies, queries, tokens, phones or emails. */
export function scrubSentryEvent(event: ErrorEvent): ErrorEvent {
  event.user = event.user?.id ? { id: event.user.id } : undefined;
  if (event.request) {
    event.request = {
      method: event.request.method,
      url: event.request.url ? stripQuery(event.request.url) : undefined,
    };
  }
  if (event.message) event.message = scrubText(event.message);
  for (const exception of event.exception?.values ?? []) {
    if (exception.value) exception.value = scrubText(exception.value);
  }
  event.breadcrumbs = event.breadcrumbs?.map((crumb) => scrubBreadcrumb(crumb));
  return event;
}

export function scrubBreadcrumb(crumb: Breadcrumb): Breadcrumb {
  const data = crumb.data;
  const url = typeof data?.url === "string" ? stripQuery(data.url) : undefined;
  return {
    ...crumb,
    message: crumb.message ? scrubText(crumb.message) : crumb.message,
    data: data
      ? {
          ...(url ? { url } : {}),
          ...(data.method ? { method: data.method } : {}),
          ...(data.status_code ? { status_code: data.status_code } : {}),
        }
      : undefined,
  };
}
