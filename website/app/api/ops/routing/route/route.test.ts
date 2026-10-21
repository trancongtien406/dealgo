import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { GET } = await import("./route");

const get = (query: string) => GET(new Request(`http://localhost:3000/api/ops/routing/route?${query}`));

describe("BFF GET /api/ops/routing/route (DEC-PROD-045)", () => {
  beforeEach(() => fetchOpsUpstream.mockReset());

  it("forwards validated coordinates to Nest", async () => {
    fetchOpsUpstream.mockResolvedValue({
      ok: true,
      status: 200,
      data: { provider: "none", available: false, routes: [] },
    });
    const res = await get("fromLat=16.05&fromLng=108.2&toLat=16.06&toLng=108.24&extra=1");
    expect(res.status).toBe(200);
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      path: "/v1/ops/routing/route?fromLat=16.05&fromLng=108.2&toLat=16.06&toLng=108.24",
    });
  });

  it("rejects missing or out-of-range coordinates without calling Nest", async () => {
    expect((await get("fromLat=16&fromLng=108&toLat=16")).status).toBe(400);
    expect((await get("fromLat=91&fromLng=108&toLat=16&toLng=108")).status).toBe(400);
    expect((await get("fromLat=abc&fromLng=108&toLat=16&toLng=108")).status).toBe(400);
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });
});
