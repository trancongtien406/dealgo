import { serverSentryOptions } from "@/lib/observability/sentry-options";

export async function register(): Promise<void> {
  const options = serverSentryOptions();
  if (!options) {
    return;
  }
  const Sentry = await import("@sentry/nextjs");
  Sentry.init(options);
}

type CaptureArgs = Parameters<typeof import("@sentry/nextjs").captureRequestError>;

export async function onRequestError(...args: CaptureArgs): Promise<void> {
  if (!serverSentryOptions()) {
    return;
  }
  const Sentry = await import("@sentry/nextjs");
  Sentry.captureRequestError(...args);
}
