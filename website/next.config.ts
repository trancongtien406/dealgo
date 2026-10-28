import type { NextConfig } from "next";
import { withSentryConfig } from "@sentry/nextjs/config";

const isDev = process.env.NODE_ENV !== "production";

/**
 * The browser only calls same-origin Route Handlers (the BFF talks to Nest
 * server-side), so production needs no API origin here. NEXT_PUBLIC_API_BASE_URL
 * is added only when set, for future direct browser calls (e.g. realtime).
 */
function connectSources(): string {
  const sources = ["'self'", "https:", "wss:"];
  if (isDev) {
    sources.push(
      "http://localhost:3000",
      "http://localhost:3001",
      "http://127.0.0.1:3001",
      "ws:",
    );
  }
  const publicApi = process.env.NEXT_PUBLIC_API_BASE_URL?.trim();
  if (publicApi) {
    try {
      const origin = new URL(publicApi).origin;
      sources.push(origin, origin.replace(/^http/, "ws"));
    } catch {
      // An invalid optional origin must not break every response header.
    }
  }
  return `connect-src ${[...new Set(sources)].join(" ")}`;
}

const securityHeaders = [
  {
    key: "X-Frame-Options",
    value: "DENY",
  },
  {
    key: "X-Content-Type-Options",
    value: "nosniff",
  },
  {
    key: "Referrer-Policy",
    value: "strict-origin-when-cross-origin",
  },
  {
    key: "Permissions-Policy",
    value: "camera=(), microphone=(), geolocation=(self)",
  },
  {
    key: "Strict-Transport-Security",
    value: "max-age=63072000; includeSubDomains; preload",
  },
  {
    key: "Content-Security-Policy",
    value: [
      "default-src 'self'",
      isDev
        ? "script-src 'self' 'unsafe-eval' 'unsafe-inline'"
        : "script-src 'self' 'unsafe-inline'",
      "style-src 'self' 'unsafe-inline'",
      "img-src 'self' data: blob: https:",
      "font-src 'self' data:",
      connectSources(),
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ].join("; "),
  },
];

const nextConfig: NextConfig = {
  // Docker image (website/Dockerfile) sets NEXT_OUTPUT=standalone; local `next start` is unchanged.
  ...(process.env.NEXT_OUTPUT === "standalone"
    ? { output: "standalone" as const }
    : {}),
  // cacheComponents + async admin layout (cookies/Nest probe) left private
  // page client trees stuck on SSR pending without firing React Query.
  // Re-enable once ops session is moved behind a streaming Suspense boundary
  // that still hydrates feature boards.
  cacheComponents: false,
  allowedDevOrigins: ["127.0.0.1", "localhost"],
  turbopack: {
    rules: {
      "*.css": {
        loaders: ["@tailwindcss/turbopack"],
        as: "*.css",
      },
    },
  },
  // Passkey / App Links association files come from backend env (DEC-PROD-056).
  async rewrites() {
    return [
      {
        source:
          "/.well-known/:file(apple-app-site-association|assetlinks.json)",
        destination: "/api/public/app-links/:file",
      },
    ];
  },
  async headers() {
    return [
      {
        source: "/:path*",
        headers: securityHeaders,
      },
    ];
  },
};

/**
 * Source maps go to Sentry (org tiendev, project dealgo-web) only when the build
 * has SENTRY_AUTH_TOKEN (VPS: Docker build secret). Maps are deleted after upload
 * so they are never served; builds without the token are left untouched.
 */
const sentryAuthToken = process.env.SENTRY_AUTH_TOKEN?.trim();
const sentryRelease = process.env.NEXT_PUBLIC_SENTRY_RELEASE?.trim();

export default sentryAuthToken
  ? withSentryConfig(nextConfig, {
      org: "tiendev",
      project: "dealgo-web",
      authToken: sentryAuthToken,
      silent: !process.env.CI,
      telemetry: false,
      ...(sentryRelease ? { release: { name: sentryRelease } } : {}),
      sourcemaps: { deleteSourcemapsAfterUpload: true },
    })
  : nextConfig;
