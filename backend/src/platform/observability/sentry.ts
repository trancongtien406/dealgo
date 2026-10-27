import * as Sentry from '@sentry/node';

export type SentryInitOptions = {
  dsn?: string;
  environment?: string;
  release?: string;
  tracesSampleRate?: number;
  serverName?: string;
};

let enabled = false;

/** Reads SENTRY_* from the raw environment (called before Nest boots so early crashes are captured). */
export function sentryOptionsFromEnv(source: NodeJS.ProcessEnv = process.env, serverName?: string): SentryInitOptions {
  const rate = Number(source.SENTRY_TRACES_SAMPLE_RATE ?? '0');
  return {
    dsn: source.SENTRY_DSN?.trim() || undefined,
    environment: source.SENTRY_ENVIRONMENT?.trim() || source.NODE_ENV || 'development',
    release: source.SENTRY_RELEASE?.trim() || undefined,
    tracesSampleRate: Number.isFinite(rate) && rate >= 0 && rate <= 1 ? rate : 0,
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
  });
  enabled = true;
  return true;
}

export function isSentryEnabled(): boolean {
  return enabled;
}

/** Reports an unexpected (5xx) error. Safe to call when Sentry is disabled. */
export function captureServerError(error: unknown, context?: Record<string, string | undefined>): void {
  if (!enabled) {
    return;
  }
  Sentry.withScope((scope) => {
    for (const [key, value] of Object.entries(context ?? {})) {
      if (value) scope.setTag(key, value);
    }
    Sentry.captureException(error);
  });
}

export async function flushSentry(timeoutMs = 2_000): Promise<void> {
  if (enabled) {
    await Sentry.flush(timeoutMs);
  }
}
