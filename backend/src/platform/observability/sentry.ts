import * as Sentry from '@sentry/node';
import type { Breadcrumb, ErrorEvent, EventHint } from '@sentry/node';

export type SentryInitOptions = {
  dsn?: string;
  environment?: string;
  release?: string;
  tracesSampleRate?: number;
  serverName?: string;
};

let enabled = false;

/** Reads SENTRY_* from the raw environment (called before Nest boots so early crashes are captured). */
export function sentryOptionsFromEnv(
  source: NodeJS.ProcessEnv = process.env,
  serverName?: string,
): SentryInitOptions {
  const rate = Number(source.SENTRY_TRACES_SAMPLE_RATE ?? '0');
  return {
    dsn: source.SENTRY_DSN?.trim() || undefined,
    environment:
      source.SENTRY_ENVIRONMENT?.trim() || source.NODE_ENV || 'development',
    release: source.SENTRY_RELEASE?.trim() || undefined,
    tracesSampleRate:
      Number.isFinite(rate) && rate >= 0 && rate <= 1 ? rate : 0,
    serverName,
  };
}

/** DEC-PROD-054: no DSN → no-op (nothing is loaded or sent). Returns whether Sentry is active. */
export function initSentry(options: SentryInitOptions): boolean {
  if (!options.dsn || enabled) {
    return enabled;
  }
  Sentry.init({
    dsn: options.dsn,
    environment: options.environment,
    release: options.release,
    serverName: options.serverName,
    tracesSampleRate: options.tracesSampleRate ?? 0,
    // Collect nothing personal at the source; scrubSentryEvent is the second line.
    dataCollection: {
      userInfo: false,
      cookies: false,
      httpHeaders: false,
      httpBodies: [],
      urlQueryParams: false,
      databaseQueryData: false,
      queues: false,
      stackFrameVariables: false,
    },
    ignoreTransactions: [/\/health\b/],
    beforeSend: (event, hint) =>
      isExpectedClientError(hint) ? null : scrubSentryEvent(event),
    beforeBreadcrumb: scrubBreadcrumb,
  });
  enabled = true;
  return true;
}

export function isSentryEnabled(): boolean {
  return enabled;
}

/**
 * Reports an unexpected (5xx) error. Safe to call when Sentry is disabled.
 * `userId` becomes the Sentry user (id only); other context entries are tags.
 */
export function captureServerError(
  error: unknown,
  context?: Record<string, string | undefined> & { userId?: string },
): void {
  if (!enabled) {
    return;
  }
  const { userId, ...tags } = context ?? {};
  Sentry.withScope((scope) => {
    if (userId) scope.setUser({ id: userId });
    for (const [key, value] of Object.entries(tags)) {
      if (value) scope.setTag(key, key === 'path' ? stripQuery(value) : value);
    }
    Sentry.captureException(error);
  });
}

export async function flushSentry(timeoutMs = 2_000): Promise<void> {
  if (enabled) {
    await Sentry.flush(timeoutMs);
  }
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
    .replace(URL_QUERY, '$1')
    .replace(JWT, '[jwt]')
    .replace(BEARER, 'bearer [redacted]')
    .replace(SECRET_PAIR, '$1[redacted]')
    .replace(EMAIL, '[email]')
    .replace(PHONE, '[phone]');
}

function stripQuery(path: string): string {
  return path.split(/[?#]/)[0] ?? path;
}

/** HttpException-like errors below 500 are expected (validation, auth, not found) and never reported. */
export function isExpectedClientError(hint?: EventHint): boolean {
  const error = hint?.originalException as
    | { getStatus?: () => unknown; status?: unknown; statusCode?: unknown }
    | null
    | undefined;
  if (!error || typeof error !== 'object') {
    return false;
  }
  const status =
    typeof error.getStatus === 'function'
      ? error.getStatus()
      : (error.status ?? error.statusCode);
  return typeof status === 'number' && status >= 400 && status < 500;
}

/** DEC-PROD-054: user id only; no headers, cookies, bodies, queries, tokens, phones or emails. */
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
  const url =
    typeof crumb.data?.url === 'string'
      ? stripQuery(crumb.data.url)
      : undefined;
  return {
    ...crumb,
    message: crumb.message ? scrubText(crumb.message) : crumb.message,
    data: crumb.data
      ? {
          ...(url ? { url } : {}),
          ...(crumb.data.method ? { method: crumb.data.method } : {}),
          ...(crumb.data.status_code
            ? { status_code: crumb.data.status_code }
            : {}),
        }
      : undefined,
  };
}
