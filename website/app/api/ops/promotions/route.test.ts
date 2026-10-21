import { beforeEach, describe, expect, it, vi } from "vitest";

const fetchOpsUpstream = vi.fn();

vi.mock("@/lib/api/ops-upstream", () => ({
  fetchOpsUpstream: (...args: unknown[]) => fetchOpsUpstream(...args),
}));

const { POST } = await import("./route");
const { PATCH } = await import("./[id]/status/route");

function mutation(url: string, method: string, origin?: string): Request {
  return new Request(url, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(origin ? { Origin: origin } : {}),
    },
    body: JSON.stringify({ status: "PAUSED" }),
  });
}

describe("ops promotions BFF same-origin guard", () => {
  beforeEach(() => {
    fetchOpsUpstream.mockReset();
    fetchOpsUpstream.mockResolvedValue({ ok: true, status: 200, data: {} });
  });

  it("rejects cross-origin and origin-less create requests before calling Nest", async () => {
    for (const origin of ["https://evil.example", undefined]) {
      const res = await POST(
        mutation("http://localhost:3000/api/ops/promotions", "POST", origin),
      );
      expect(res.status).toBe(403);
    }
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });

  it("rejects cross-origin status changes before calling Nest", async () => {
    const res = await PATCH(
      mutation(
        "http://localhost:3000/api/ops/promotions/abc/status",
        "PATCH",
        "https://evil.example",
      ),
      { params: Promise.resolve({ id: "abc" }) },
    );
    expect(res.status).toBe(403);
    expect(fetchOpsUpstream).not.toHaveBeenCalled();
  });

  it("forwards same-origin status changes", async () => {
    await PATCH(
      mutation(
        "http://localhost:3000/api/ops/promotions/abc/status",
        "PATCH",
        "http://localhost:3000",
      ),
      { params: Promise.resolve({ id: "abc" }) },
    );
    expect(fetchOpsUpstream).toHaveBeenCalledWith(
      expect.objectContaining({
        method: "PATCH",
        path: "/v1/ops/promotions/abc/status",
      }),
    );
  });
});
