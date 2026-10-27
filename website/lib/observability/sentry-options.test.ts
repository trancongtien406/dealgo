import { describe, expect, it } from "vitest";
import { websiteSentryOptions } from "./sentry-options";

describe("websiteSentryOptions", () => {
  it("is disabled without a DSN", () => {
    expect(websiteSentryOptions(undefined, "production")).toBeNull();
    expect(websiteSentryOptions("  ", "production")).toBeNull();
  });

  it("clamps the trace sample rate", () => {
    expect(websiteSentryOptions("https://k@o1.ingest.sentry.io/1", undefined, "3")).toEqual({
      dsn: "https://k@o1.ingest.sentry.io/1",
      environment: "development",
      tracesSampleRate: 0,
    });
    expect(websiteSentryOptions("https://k@o1.ingest.sentry.io/1", "production", "0.2")?.tracesSampleRate).toBe(0.2);
  });
});
