import { describe, expect, it } from "vitest";
import { ApiError } from "@/lib/api/errors";
import {
  isExpectedClientError,
  scrubSentryEvent,
  scrubText,
  websiteSentryOptions,
} from "./sentry-options";

describe("websiteSentryOptions", () => {
  it("is disabled without a DSN", () => {
    expect(websiteSentryOptions(undefined, "production")).toBeNull();
    expect(websiteSentryOptions("  ", "production")).toBeNull();
  });

  it("clamps the trace sample rate and carries the release", () => {
    expect(
      websiteSentryOptions("https://k@o1.ingest.sentry.io/1", undefined, "3"),
    ).toMatchObject({
      dsn: "https://k@o1.ingest.sentry.io/1",
      environment: "development",
      tracesSampleRate: 0,
    });
    expect(
      websiteSentryOptions("https://k@o1.ingest.sentry.io/1", undefined)
        ?.release,
    ).toBeUndefined();
    const prod = websiteSentryOptions(
      "https://k@o1.ingest.sentry.io/1",
      "production",
      "0.1",
      " 2026.10.27-1930 ",
    );
    expect(prod).toMatchObject({
      tracesSampleRate: 0.1,
      release: "2026.10.27-1930",
    });
    expect(prod?.dataCollection).toMatchObject({
      userInfo: false,
      cookies: false,
      httpHeaders: false,
    });
  });
});

describe("Sentry scrubbing", () => {
  it("strips tokens, secrets, emails, phones and queries", () => {
    expect(
      scrubText(
        "GET https://x/a?token=1 ana@mail.vn 0912345678 Bearer abc password=x eyJa.eyJb.sig",
      ),
    ).toBe(
      "GET https://x/a [email] [phone] bearer [redacted] password=[redacted] [jwt]",
    );
  });

  it("keeps only the user id and request method/url", () => {
    const event = scrubSentryEvent({
      type: undefined,
      user: { id: "u1", email: "a@b.vn" },
      request: {
        method: "GET",
        url: "https://x/a?q=1",
        headers: { cookie: "s" },
      },
      exception: { values: [{ value: "otp=123456" }] },
      breadcrumbs: [
        {
          category: "fetch",
          data: { url: "https://x/b?y=1", method: "POST", body: "z" },
        },
      ],
    });
    expect(event.user).toEqual({ id: "u1" });
    expect(event.request).toEqual({ method: "GET", url: "https://x/a" });
    expect(event.exception?.values?.[0]?.value).toBe("otp=[redacted]");
    expect(event.breadcrumbs?.[0]?.data).toEqual({
      url: "https://x/b",
      method: "POST",
    });
  });

  it("drops expected 4xx, keeps 5xx and plain errors", () => {
    const options = websiteSentryOptions(
      "https://k@o1.ingest.sentry.io/1",
      "production",
    )!;
    const notFound = new ApiError("x", { code: "NOT_FOUND", status: 404 });
    expect(isExpectedClientError(notFound)).toBe(true);
    expect(
      options.beforeSend({ type: undefined }, { originalException: notFound }),
    ).toBeNull();
    expect(
      isExpectedClientError(new ApiError("x", { code: "SERVER", status: 502 })),
    ).toBe(false);
    expect(
      options.beforeSend(
        { type: undefined },
        { originalException: new Error("boom") },
      ),
    ).toEqual({ type: undefined });
  });
});
