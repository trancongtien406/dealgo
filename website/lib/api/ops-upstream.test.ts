import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { tryRefreshSessionSingleFlight } from "./ops-upstream";

describe("tryRefreshSessionSingleFlight Mutex", () => {
  const originalFetch = globalThis.fetch;

  beforeEach(() => {
    vi.restoreAllMocks();
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("deduplicates concurrent refresh calls for the same refresh token to a single network call", async () => {
    let callCount = 0;
    globalThis.fetch = vi.fn().mockImplementation(async () => {
      callCount++;
      // Simulate network delay
      await new Promise((r) => setTimeout(r, 50));
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            expiresIn: 900,
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    });

    const token = "valid-refresh-token-123";
    const [res1, res2, res3] = await Promise.all([
      tryRefreshSessionSingleFlight("http://localhost:3001", token),
      tryRefreshSessionSingleFlight("http://localhost:3001", token),
      tryRefreshSessionSingleFlight("http://localhost:3001", token),
    ]);

    expect(callCount).toBe(1);
    expect(res1).toEqual(res2);
    expect(res2).toEqual(res3);
    expect(res1?.accessToken).toBe("new-access-token");
    expect(res1?.refreshToken).toBe("new-refresh-token");
  });

  it("allows subsequent refresh call after the in-flight one completes", async () => {
    let callCount = 0;
    globalThis.fetch = vi.fn().mockImplementation(async () => {
      callCount++;
      return new Response(
        JSON.stringify({
          success: true,
          data: {
            accessToken: `access-${callCount}`,
            refreshToken: `refresh-${callCount}`,
            expiresIn: 900,
          },
        }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    });

    const token = "valid-refresh-token-456";
    const first = await tryRefreshSessionSingleFlight(
      "http://localhost:3001",
      token,
    );
    const second = await tryRefreshSessionSingleFlight(
      "http://localhost:3001",
      token,
    );

    expect(callCount).toBe(2);
    expect(first?.accessToken).toBe("access-1");
    expect(second?.accessToken).toBe("access-2");
  });

  it("returns null safely on invalid token format without calling fetch", async () => {
    const fetchSpy = vi.fn();
    globalThis.fetch = fetchSpy;

    const res = await tryRefreshSessionSingleFlight(
      "http://localhost:3001",
      "",
    );
    expect(res).toBeNull();
    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
