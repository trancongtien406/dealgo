/**
 * DEC-PROD-054: Sentry is opt-in. Without a DSN nothing is imported or sent, so
 * dev and self-hosted builds stay free of the SDK at runtime.
 */
export type WebsiteSentryOptions = {
  dsn: string;
  environment: string;
  tracesSampleRate: number;
};

export function websiteSentryOptions(
  dsn: string | undefined,
  environment: string | undefined,
  tracesSampleRate?: string,
): WebsiteSentryOptions | null {
  const trimmed = dsn?.trim();
  if (!trimmed) {
    return null;
  }
  const rate = Number(tracesSampleRate ?? "0");
  return {
    dsn: trimmed,
    environment: environment?.trim() || "development",
    tracesSampleRate: Number.isFinite(rate) && rate >= 0 && rate <= 1 ? rate : 0,
  };
}

export function serverSentryOptions(): WebsiteSentryOptions | null {
  return websiteSentryOptions(
    process.env.SENTRY_DSN || process.env.NEXT_PUBLIC_SENTRY_DSN,
    process.env.SENTRY_ENVIRONMENT || process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT || process.env.NODE_ENV,
    process.env.SENTRY_TRACES_SAMPLE_RATE,
  );
}

export function clientSentryOptions(): WebsiteSentryOptions | null {
  return websiteSentryOptions(
    process.env.NEXT_PUBLIC_SENTRY_DSN,
    process.env.NEXT_PUBLIC_SENTRY_ENVIRONMENT || process.env.NODE_ENV,
    process.env.NEXT_PUBLIC_SENTRY_TRACES_SAMPLE_RATE,
  );
}

/** Report a client-side error boundary hit; no-op without NEXT_PUBLIC_SENTRY_DSN. */
export function reportClientError(error: unknown): void {
  if (!clientSentryOptions()) {
    return;
  }
  void import("@sentry/nextjs").then((Sentry) => Sentry.captureException(error));
}
