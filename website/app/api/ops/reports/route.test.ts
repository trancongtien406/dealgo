import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { GET } = await import("./route");

describe("ops reports BFF", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data: { totals: {}, daily: [] } });
  });

  it("forwards the selected from/to range to Nest", async () => {
    await GET(new Request("http://localhost/api/ops/reports?from=2026-10-01&to=2026-10-07"));
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      path: "/v1/ops/reports",
      searchParams: { from: "2026-10-01", to: "2026-10-07" },
    });
  });

  it("drops malformed dates so Nest falls back to today", async () => {
    await GET(new Request("http://localhost/api/ops/reports?from=hom-qua&to=2026-10-07"));
    expect(fetchOpsUpstream).toHaveBeenCalledWith({
      path: "/v1/ops/reports",
      searchParams: { from: undefined, to: "2026-10-07" },
    });
  });
});
