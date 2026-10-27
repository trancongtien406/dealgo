import { describe, expect, it } from "vitest";
import { assertSameOriginMutation } from "./ops-bff-guards";
import { publicRequestOrigin } from "./public-origin";

const behindProxy = (headers: Record<string, string>) =>
  new Request("https://0.0.0.0:3000/api/ops/session", {
    method: "POST",
    headers,
  });

describe("publicRequestOrigin", () => {
  it("uses the forwarded host and proto behind a reverse proxy", () => {
    const req = behindProxy({
      "x-forwarded-host": "admin.example.com",
      "x-forwarded-proto": "https",
    });
    expect(publicRequestOrigin(req)).toBe("https://admin.example.com");
  });

  it("falls back to request.url without proxy headers", () => {
    expect(publicRequestOrigin(new Request("http://localhost:3000/x"))).toBe(
      "http://localhost:3000",
    );
  });

  it("ignores an unexpected proto", () => {
    const req = behindProxy({
      "x-forwarded-host": "a.example.com",
      "x-forwarded-proto": "javascript",
    });
    expect(publicRequestOrigin(req)).toBe("https://0.0.0.0:3000");
  });
});

describe("assertSameOriginMutation behind a proxy", () => {
  it("accepts the public origin", () => {
    const req = behindProxy({
      "x-forwarded-host": "admin.example.com",
      "x-forwarded-proto": "https",
      origin: "https://admin.example.com",
    });
    expect(assertSameOriginMutation(req)).toBeNull();
  });

  it("rejects a cross-site origin", () => {
    const req = behindProxy({
      "x-forwarded-host": "admin.example.com",
      "x-forwarded-proto": "https",
      origin: "https://evil.example",
    });
    expect(assertSameOriginMutation(req)?.status).toBe(403);
  });
});
