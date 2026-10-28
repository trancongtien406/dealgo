import { afterEach, describe, expect, it, vi } from "vitest";
import { loadRuntimeMapboxToken, resetRuntimeMapboxTokenForTests } from "@/lib/mapbox-token";

afterEach(() => resetRuntimeMapboxTokenForTests());

describe("loadRuntimeMapboxToken", () => {
  it("returns the Admin pk token and caches it", async () => {
    const fetcher = vi.fn(async () => Response.json({ mapboxPublicToken: "pk.admin" }));
    expect(await loadRuntimeMapboxToken(fetcher as unknown as typeof fetch)).toBe("pk.admin");
    expect(await loadRuntimeMapboxToken(fetcher as unknown as typeof fetch)).toBe("pk.admin");
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it("falls back to empty on missing, invalid or failed config", async () => {
    expect(await loadRuntimeMapboxToken((async () => Response.json({ mapboxPublicToken: null })) as unknown as typeof fetch)).toBe("");
    resetRuntimeMapboxTokenForTests();
    expect(await loadRuntimeMapboxToken((async () => Response.json({ mapboxPublicToken: "sk.x" })) as unknown as typeof fetch)).toBe("");
    resetRuntimeMapboxTokenForTests();
    expect(await loadRuntimeMapboxToken((async () => { throw new Error("x"); }) as unknown as typeof fetch)).toBe("");
  });
});
