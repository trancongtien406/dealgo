import { clientSentryOptions } from "@/lib/observability/sentry-options";

const options = clientSentryOptions();
if (options) {
  void import("@sentry/nextjs").then((Sentry) => Sentry.init(options));
}
