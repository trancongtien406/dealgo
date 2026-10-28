import { afterEach, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

afterEach(() => {
  vi.unstubAllGlobals();
});

describe("GET /api/public/client-config", () => {
  it("returns the Admin Mapbox public token", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({ success: true, data: { mapboxPublicToken: "pk.abc" } }),
    );
    vi.stubGlobal("fetch", fetchMock);
    const res = await GET();
    expect(await res.json()).toEqual({ mapboxPublicToken: "pk.abc" });
    expect(String((fetchMock.mock.calls[0] as unknown[])[0])).toMatch(/\/v1\/public\/client-config$/);
  });

  it("drops non-public tokens and upstream failures", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => Response.json({ data: { mapboxPublicToken: "sk.secret" } })));
    expect(await (await GET()).json()).toEqual({ mapboxPublicToken: null });
    vi.stubGlobal("fetch", vi.fn(async () => new Response(null, { status: 500 })));
    expect(await (await GET()).json()).toEqual({ mapboxPublicToken: null });
    vi.stubGlobal("fetch", vi.fn(async () => { throw new Error("down"); }));
    expect(await (await GET()).json()).toEqual({ mapboxPublicToken: null });
  });
});
