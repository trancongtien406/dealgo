import { afterEach, describe, expect, it, vi } from "vitest";
import { fetchRealRoadRoute, straightLineRoute } from "./real-map-view";

afterEach(() => vi.unstubAllGlobals());

describe("Admin map routing via Nest (DEC-PROD-045)", () => {
  it("draws a straight line with great-circle distance when routing is unconfigured", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({ success: true, data: { provider: "none", available: false, routes: [] } }),
    );
    vi.stubGlobal("fetch", fetchMock);
    const res = await fetchRealRoadRoute([
      [16.0544, 108.2022],
      [16.0592, 108.2435],
    ]);
    expect(String((fetchMock.mock.calls[0] as unknown[])[0])).toMatch(/^\/api\/ops\/routing\/route\?fromLat=16\.0544/);
    expect(res.fastest.id).toBe("straight");
    expect(res.fastest.coords).toEqual([
      [16.0544, 108.2022],
      [16.0592, 108.2435],
    ]);
    expect(res.fastest.distanceKm).toBeCloseTo(4.4, 1);
    expect(res.alternatives).toEqual([]);
  });

  it("uses server routes, fastest first, and never calls a public router", async () => {
    const fetchMock = vi.fn(async () =>
      Response.json({
        success: true,
        data: {
          provider: "osrm",
          available: true,
          routes: [
            { coords: [[10.1, 106.1], [10.2, 106.2]], distanceM: 9000, durationSec: 900, summary: "B" },
            { coords: [[10.1, 106.1], [10.15, 106.15], [10.2, 106.2]], distanceM: 8000, durationSec: 600, summary: "A" },
          ],
        },
      }),
    );
    vi.stubGlobal("fetch", fetchMock);
    const res = await fetchRealRoadRoute([
      [10.1, 106.1],
      [10.2, 106.2],
    ]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(res.fastest).toMatchObject({ summary: "A", distanceKm: 8, durationMin: 10 });
    expect(res.alternatives).toHaveLength(1);
  });

  it("falls back to a straight line when the BFF fails", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response("down", { status: 502 })));
    const res = await fetchRealRoadRoute([
      [21.0, 105.8],
      [21.01, 105.81],
    ]);
    expect(res.fastest.id).toBe("straight");
    expect(straightLineRoute([[1, 2]]).fastest.distanceKm).toBe(0);
  });
});
